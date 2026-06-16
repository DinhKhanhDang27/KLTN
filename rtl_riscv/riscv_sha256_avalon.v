// ============================================================================
// RISC-V Avalon-MM master wrapper for Qsys/Platform Designer.
//
// This file is intentionally separate from riscv_top.v.  The original top keeps
// its internal instruction/data memories for simulation, while this wrapper gives
// Qsys a bus-speaking processor block that can replace a Nios II master.
//
// Avalon master characteristics:
//   - 32-bit address
//   - 32-bit read/write data
//   - fixed 4-bit byteenable
//   - uses waitrequest + readdatavalid for SDRAM-safe reads
//
// CPU-visible memory map is owned by the Qsys interconnect.  SHA-256 must be a
// separate Avalon-MM slave, not a local block hidden inside the CPU.
// ============================================================================
module riscv_sha256_avalon (
    input         clk,
    input         reset,

    output reg [31:0] avm_address,
    output reg        avm_read,
    output reg        avm_write,
    output reg [31:0] avm_writedata,
    input      [31:0] avm_readdata,
    input             avm_waitrequest,
    input             avm_readdatavalid,
    output reg [3:0]  avm_byteenable,

    output [63:0] out_pc,
    output [63:0] out_alu_result,
    output [3:0]  debug_state
);

    // ------------------------------------------------------------------------
    // Sequencer state
    // ------------------------------------------------------------------------
    localparam S_FETCH_REQ      = 4'd0;
    localparam S_FETCH_WAIT     = 4'd1;
    localparam S_EXECUTE        = 4'd2;
    localparam S_DATA_RD_LO_REQ = 4'd3;
    localparam S_DATA_RD_LO_WT  = 4'd4;
    localparam S_DATA_RD_HI_REQ = 4'd5;
    localparam S_DATA_RD_HI_WT  = 4'd6;
    localparam S_DATA_WB        = 4'd7;
    localparam S_DATA_WR_LO_REQ = 4'd8;
    localparam S_DATA_WR_HI_REQ = 4'd9;

    reg [3:0]  state;
    reg        store_in_progress;
    reg [31:0] instruction_reg;
    reg [63:0] pc_current;
    reg [63:0] load_data_reg;
    reg [63:0] store_addr_reg;
    reg [63:0] store_data_reg;
    reg [63:0] pc_next_reg;

    assign debug_state = state;

    // ------------------------------------------------------------------------
    // Instruction decode
    // ------------------------------------------------------------------------
    wire [31:0] instruction = instruction_reg;
    wire [6:0]  opcode = instruction[6:0];
    wire [4:0]  rd     = instruction[11:7];
    wire [2:0]  funct3 = instruction[14:12];
    wire [4:0]  rs1    = instruction[19:15];
    wire [4:0]  rs2    = instruction[24:20];
    wire [6:0]  funct7 = instruction[31:25];

    wire        ctrl_branch, ctrl_mem_read, ctrl_mem_to_reg;
    wire [1:0]  ctrl_alu_op;
    wire        ctrl_mem_write, ctrl_alu_src, ctrl_reg_write;
    wire        ctrl_jump, ctrl_jalr;
    wire        ctrl_sha2rst, ctrl_sha2push, ctrl_sha2start;
    wire        ctrl_sha2perform, ctrl_sha2finish, ctrl_sha2read;

    control_unit u_control (
        .opcode      (opcode),
        .funct3      (funct3),
        .funct7      (funct7),
        .branch      (ctrl_branch),
        .mem_read    (ctrl_mem_read),
        .mem_to_reg  (ctrl_mem_to_reg),
        .alu_op      (ctrl_alu_op),
        .mem_write   (ctrl_mem_write),
        .alu_src     (ctrl_alu_src),
        .reg_write   (ctrl_reg_write),
        .jump        (ctrl_jump),
        .jalr        (ctrl_jalr),
        .sha2rst     (ctrl_sha2rst),
        .sha2push    (ctrl_sha2push),
        .sha2start   (ctrl_sha2start),
        .sha2perform (ctrl_sha2perform),
        .sha2finish  (ctrl_sha2finish),
        .sha2read    (ctrl_sha2read)
    );

    // ------------------------------------------------------------------------
    // Datapath
    // ------------------------------------------------------------------------
    wire [63:0] reg_read_data1;
    wire [63:0] reg_read_data2;
    wire [63:0] reg_write_data;
    wire        reg_write_enable;

    register_file u_regfile (
        .clk        (clk),
        .rst        (reset),
        .reg_write  (reg_write_enable),
        .read_reg1  (rs1),
        .read_reg2  (rs2),
        .write_reg  (rd),
        .write_data (reg_write_data),
        .read_data1 (reg_read_data1),
        .read_data2 (reg_read_data2)
    );

    wire [63:0] imm;
    imm_gen u_immgen (
        .instruction (instruction),
        .imm         (imm)
    );

    wire [3:0] alu_ctrl;
    alu_control u_alu_ctrl (
        .alu_op          (ctrl_alu_op),
        .funct3          (funct3),
        .funct7          (funct7),
        .alu_control_out (alu_ctrl)
    );

    wire [63:0] alu_input_b = ctrl_alu_src ? imm : reg_read_data2;
    wire [63:0] alu_result;
    wire        alu_zero;

    alu u_alu (
        .a           (reg_read_data1),
        .b           (alu_input_b),
        .alu_control (alu_ctrl),
        .result      (alu_result),
        .zero        (alu_zero)
    );

    wire branch_taken;
    branch_control u_branch_ctrl (
        .branch       (ctrl_branch),
        .funct3       (funct3),
        .alu_result   (alu_result),
        .zero         (alu_zero),
        .branch_taken (branch_taken)
    );

    wire [63:0] pc_plus4        = pc_current + 64'd4;
    wire [63:0] pc_branch_target = pc_current + imm;
    wire [63:0] jalr_target_raw  = reg_read_data1 + imm;
    wire [63:0] jalr_target      = {jalr_target_raw[63:1], 1'b0};
    wire [63:0] pc_after_branch  = branch_taken ? pc_branch_target : pc_plus4;
    wire [63:0] pc_after_jal     = ctrl_jump ? pc_branch_target : pc_after_branch;
    wire [63:0] pc_next          = ctrl_jalr ? jalr_target : pc_after_jal;

    wire is_lui      = (opcode == 7'b0110111);
    wire is_auipc    = (opcode == 7'b0010111);
    wire is_jal_jalr = ctrl_jump | ctrl_jalr;
    wire is_word_op  = (opcode == 7'b0011011) || (opcode == 7'b0111011);

    reg [31:0] alu_word_result;
    reg [31:0] alu_word_sra_fill;
    always @(*) begin
        if (alu_input_b[4:0] == 5'd0)
            alu_word_sra_fill = reg_read_data1[31:0];
        else if (reg_read_data1[31])
            alu_word_sra_fill = (reg_read_data1[31:0] >> alu_input_b[4:0]) |
                                (32'hffffffff << (6'd32 - {1'b0, alu_input_b[4:0]}));
        else
            alu_word_sra_fill = reg_read_data1[31:0] >> alu_input_b[4:0];

        case (funct3)
            3'b000: alu_word_result = funct7[5] && (opcode == 7'b0111011) ?
                                      (reg_read_data1[31:0] - reg_read_data2[31:0]) :
                                      (reg_read_data1[31:0] + alu_input_b[31:0]);
            3'b001: alu_word_result = reg_read_data1[31:0] << alu_input_b[4:0];
            3'b101: alu_word_result = funct7[5] ?
                                      alu_word_sra_fill :
                                      (reg_read_data1[31:0] >> alu_input_b[4:0]);
            default: alu_word_result = alu_result[31:0];
        endcase
    end

    wire [63:0] execute_result = is_word_op ? {{32{alu_word_result[31]}}, alu_word_result} :
                                             alu_result;

    reg [63:0] load_extended_data;
    always @(*) begin
        case (funct3)
            3'b000: begin // LB
                case (store_addr_reg[1:0])
                    2'd0: load_extended_data = {{56{load_data_reg[7]}},  load_data_reg[7:0]};
                    2'd1: load_extended_data = {{56{load_data_reg[15]}}, load_data_reg[15:8]};
                    2'd2: load_extended_data = {{56{load_data_reg[23]}}, load_data_reg[23:16]};
                    default: load_extended_data = {{56{load_data_reg[31]}}, load_data_reg[31:24]};
                endcase
            end
            3'b001: begin // LH
                if (store_addr_reg[1])
                    load_extended_data = {{48{load_data_reg[31]}}, load_data_reg[31:16]};
                else
                    load_extended_data = {{48{load_data_reg[15]}}, load_data_reg[15:0]};
            end
            3'b010: load_extended_data = {{32{load_data_reg[31]}}, load_data_reg[31:0]}; // LW
            3'b011: load_extended_data = load_data_reg; // LD
            3'b100: begin // LBU
                case (store_addr_reg[1:0])
                    2'd0: load_extended_data = {56'd0, load_data_reg[7:0]};
                    2'd1: load_extended_data = {56'd0, load_data_reg[15:8]};
                    2'd2: load_extended_data = {56'd0, load_data_reg[23:16]};
                    default: load_extended_data = {56'd0, load_data_reg[31:24]};
                endcase
            end
            3'b101: load_extended_data = store_addr_reg[1] ? {48'd0, load_data_reg[31:16]} :
                                                            {48'd0, load_data_reg[15:0]}; // LHU
            3'b110: load_extended_data = {32'd0, load_data_reg[31:0]}; // LWU
            default: load_extended_data = load_data_reg;
        endcase
    end

    reg [31:0] store_writedata_word;
    reg [3:0]  store_byteenable_word;
    always @(*) begin
        store_writedata_word  = reg_read_data2[31:0];
        store_byteenable_word = 4'hf;

        case (funct3)
            3'b000: begin // SB
                store_writedata_word = {4{reg_read_data2[7:0]}};
                case (alu_result[1:0])
                    2'd0: store_byteenable_word = 4'b0001;
                    2'd1: store_byteenable_word = 4'b0010;
                    2'd2: store_byteenable_word = 4'b0100;
                    default: store_byteenable_word = 4'b1000;
                endcase
            end
            3'b001: begin // SH, aligned within one 32-bit Avalon word
                store_writedata_word = {2{reg_read_data2[15:0]}};
                store_byteenable_word = alu_result[1] ? 4'b1100 : 4'b0011;
            end
            3'b010: begin // SW
                store_writedata_word = reg_read_data2[31:0];
                store_byteenable_word = 4'hf;
            end
            default: begin // SD first beat
                store_writedata_word = reg_read_data2[31:0];
                store_byteenable_word = 4'hf;
            end
        endcase
    end

    wire [63:0] normal_wb_data =
        is_lui      ? imm :
        is_auipc    ? (pc_current + imm) :
        is_jal_jalr ? pc_plus4 :
        ctrl_mem_to_reg ? load_extended_data :
        execute_result;

    assign reg_write_data   = normal_wb_data;
    assign reg_write_enable = ((state == S_EXECUTE) && ctrl_reg_write && !ctrl_mem_read) ||
                              ((state == S_DATA_WB) && !store_in_progress);

    assign out_pc         = pc_current;
    assign out_alu_result = execute_result;

    // ------------------------------------------------------------------------
    // Avalon transaction sequencer
    // ------------------------------------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state             <= S_FETCH_REQ;
            store_in_progress <= 1'b0;
            instruction_reg   <= 32'h00000013;
            pc_current        <= 64'd0;
            load_data_reg     <= 64'd0;
            store_addr_reg    <= 64'd0;
            store_data_reg    <= 64'd0;
            pc_next_reg       <= 64'd0;
            avm_address       <= 32'd0;
            avm_read          <= 1'b0;
            avm_write         <= 1'b0;
            avm_writedata     <= 32'd0;
            avm_byteenable    <= 4'hf;
        end else begin
            avm_read       <= 1'b0;
            avm_write      <= 1'b0;
            avm_byteenable <= 4'hf;

            case (state)
                S_FETCH_REQ: begin
                    avm_address <= pc_current[31:0];
                    avm_read    <= 1'b1;
                    if (!avm_waitrequest)
                        state <= S_FETCH_WAIT;
                end

                S_FETCH_WAIT: begin
                    if (avm_readdatavalid) begin
                        instruction_reg <= avm_readdata;
                        state <= S_EXECUTE;
                    end
                end

                S_EXECUTE: begin
                    pc_next_reg <= pc_next;

                    if (ctrl_mem_read) begin
                        store_in_progress <= 1'b0;
                        store_addr_reg <= alu_result;
                        avm_address <= (funct3 == 3'b011) ? {alu_result[31:3], 3'b000} :
                                                             {alu_result[31:2], 2'b00};
                        avm_read <= 1'b1;
                        if (!avm_waitrequest)
                            state <= S_DATA_RD_LO_WT;
                        else
                            state <= S_DATA_RD_LO_REQ;
                    end else if (ctrl_mem_write) begin
                        store_in_progress <= 1'b1;
                        store_addr_reg <= alu_result;
                        store_data_reg <= reg_read_data2;
                        avm_address <= (funct3 == 3'b011) ? {alu_result[31:3], 3'b000} :
                                                             {alu_result[31:2], 2'b00};
                        avm_writedata <= store_writedata_word;
                        avm_byteenable <= store_byteenable_word;
                        avm_write <= 1'b1;
                        if (!avm_waitrequest) begin
                            if (funct3 == 3'b011)
                                state <= S_DATA_WR_HI_REQ;
                            else begin
                                pc_current <= pc_next;
                                state <= S_FETCH_REQ;
                            end
                        end else begin
                            state <= S_DATA_WR_LO_REQ;
                        end
                    end else begin
                        pc_current <= pc_next;
                        state <= S_FETCH_REQ;
                    end
                end

                S_DATA_RD_LO_REQ: begin
                    avm_address <= (funct3 == 3'b011) ? {store_addr_reg[31:3], 3'b000} :
                                                        {store_addr_reg[31:2], 2'b00};
                    avm_read <= 1'b1;
                    if (!avm_waitrequest)
                        state <= S_DATA_RD_LO_WT;
                end

                S_DATA_RD_LO_WT: begin
                    if (avm_readdatavalid) begin
                        load_data_reg[31:0] <= avm_readdata;
                        if (funct3 == 3'b011)
                            state <= S_DATA_RD_HI_REQ;
                        else
                            state <= S_DATA_WB;
                    end
                end

                S_DATA_RD_HI_REQ: begin
                    avm_address <= {store_addr_reg[31:3], 3'b000} + 32'd4;
                    avm_read <= 1'b1;
                    if (!avm_waitrequest)
                        state <= S_DATA_RD_HI_WT;
                end

                S_DATA_RD_HI_WT: begin
                    if (avm_readdatavalid) begin
                        load_data_reg[63:32] <= avm_readdata;
                        state <= S_DATA_WB;
                    end
                end

                S_DATA_WB: begin
                    pc_current <= pc_next_reg;
                    state <= S_FETCH_REQ;
                end

                default: begin
                    state <= S_FETCH_REQ;
                end
            endcase

            if (state == S_DATA_WR_LO_REQ) begin
                avm_address <= (funct3 == 3'b011) ? {store_addr_reg[31:3], 3'b000} :
                                                    {store_addr_reg[31:2], 2'b00};
                avm_writedata <= (funct3 == 3'b011) ? store_data_reg[31:0] :
                                                     store_writedata_word;
                avm_byteenable <= (funct3 == 3'b011) ? 4'hf : store_byteenable_word;
                avm_write <= 1'b1;
                if (!avm_waitrequest) begin
                    if (funct3 == 3'b011)
                        state <= S_DATA_WR_HI_REQ;
                    else begin
                        pc_current <= pc_next_reg;
                        state <= S_FETCH_REQ;
                    end
                end
            end

            if (state == S_DATA_WR_HI_REQ) begin
                avm_address <= {store_addr_reg[31:3], 3'b000} + 32'd4;
                avm_writedata <= store_data_reg[63:32];
                avm_byteenable <= 4'hf;
                avm_write <= 1'b1;
                if (!avm_waitrequest) begin
                    pc_current <= pc_next_reg;
                    state <= S_FETCH_REQ;
                end
            end
        end
    end

endmodule
