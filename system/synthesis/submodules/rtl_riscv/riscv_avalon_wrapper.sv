module riscv_avalon_wrapper (
    input  wire        clk,
    input  wire        reset_n,

    output wire [31:0] avm_address,
    output wire        avm_read,
    input  wire [31:0] avm_readdata,
    input  wire        avm_readdatavalid,
    output wire        avm_write,
    output wire [31:0] avm_writedata,
    output wire [3:0]  avm_byteenable,
    input  wire        avm_waitrequest,

    output wire [63:0] out_pc,
    output wire [63:0] out_alu_result
);

    localparam STATE_RUN       = 1'b0;
    localparam STATE_WAIT_READ = 1'b1;

    reg        state;
    reg [63:0] pc_current;
    reg [4:0]  pending_rd;
    reg [63:0] pending_pc_next;

    reg [63:0] registers [0:31];

    wire [31:0] instruction;
    wire [6:0]  opcode = instruction[6:0];
    wire [4:0]  rd     = instruction[11:7];
    wire [2:0]  funct3 = instruction[14:12];
    wire [4:0]  rs1    = instruction[19:15];
    wire [4:0]  rs2    = instruction[24:20];
    wire [6:0]  funct7 = instruction[31:25];

    wire        ctrl_branch;
    wire        ctrl_mem_read;
    wire        ctrl_mem_to_reg;
    wire [1:0]  ctrl_alu_op;
    wire        ctrl_mem_write;
    wire        ctrl_alu_src;
    wire        ctrl_reg_write;
    wire        ctrl_jump;
    wire        ctrl_jalr;
    wire        ctrl_sha2rst;
    wire        ctrl_sha2push;
    wire        ctrl_sha2start;
    wire        ctrl_sha2perform;
    wire        ctrl_sha2finish;
    wire        ctrl_sha2read;

    wire [63:0] reg_read_data1 = (rs1 == 5'd0) ? 64'd0 : registers[rs1];
    wire [63:0] reg_read_data2 = (rs2 == 5'd0) ? 64'd0 : registers[rs2];
    wire [63:0] imm;
    wire [3:0]  alu_ctrl;
    wire [63:0] alu_input_b;
    wire [63:0] alu_result;
    wire        alu_zero;

    wire [63:0] pc_plus4        = pc_current + 64'd4;
    wire [63:0] pc_branch_target = pc_current + imm;
    wire [63:0] jalr_target_raw = reg_read_data1 + imm;
    wire [63:0] jalr_target     = {jalr_target_raw[63:1], 1'b0};

    wire        branch_taken;
    wire [63:0] pc_branch_or_seq = branch_taken ? pc_branch_target : pc_plus4;
    wire [63:0] pc_after_jal     = ctrl_jump ? pc_branch_target : pc_branch_or_seq;
    wire [63:0] pc_next          = ctrl_jalr ? jalr_target : pc_after_jal;

    wire        running_mem_read  = (state == STATE_RUN) && ctrl_mem_read;
    wire        running_mem_write = (state == STATE_RUN) && ctrl_mem_write;
    wire        running_mem_op    = running_mem_read || running_mem_write;
    wire        bus_accepted      = running_mem_op && !avm_waitrequest;

    wire [63:0] lui_result        = imm;
    wire [63:0] auipc_result      = pc_current + imm;
    wire        is_lui            = (opcode == 7'b0110111);
    wire        is_auipc          = (opcode == 7'b0010111);
    wire        is_jal_jalr       = ctrl_jump | ctrl_jalr;
    wire [63:0] core_write_data   = is_lui      ? lui_result :
                                    is_auipc    ? auipc_result :
                                    is_jal_jalr ? pc_plus4 : alu_result;

    instruction_memory u_imem (
        .addr        (pc_current),
        .instruction (instruction)
    );

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

    imm_gen u_immgen (
        .instruction (instruction),
        .imm         (imm)
    );

    alu_control u_alu_ctrl (
        .alu_op          (ctrl_alu_op),
        .funct3          (funct3),
        .funct7          (funct7),
        .alu_control_out (alu_ctrl)
    );

    assign alu_input_b = ctrl_alu_src ? imm : reg_read_data2;

    alu u_alu (
        .a           (reg_read_data1),
        .b           (alu_input_b),
        .alu_control (alu_ctrl),
        .result      (alu_result),
        .zero        (alu_zero)
    );

    branch_control u_branch_ctrl (
        .branch       (ctrl_branch),
        .funct3       (funct3),
        .alu_result   (alu_result),
        .zero         (alu_zero),
        .branch_taken (branch_taken)
    );

    assign avm_address    = alu_result[31:0];
    assign avm_read       = running_mem_read;
    assign avm_write      = running_mem_write;
    assign avm_writedata  = reg_read_data2[31:0];
    assign avm_byteenable = 4'hf;

    assign out_pc         = pc_current;
    assign out_alu_result = alu_result;

    integer i;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= STATE_RUN;
            pc_current <= 64'd0;
            pending_rd <= 5'd0;
            pending_pc_next <= 64'd0;
            for (i = 0; i < 32; i = i + 1)
                registers[i] <= 64'd0;
        end else begin
            if (state == STATE_WAIT_READ) begin
                if (avm_readdatavalid) begin
                    if (pending_rd != 5'd0)
                        registers[pending_rd] <= {32'd0, avm_readdata};
                    pc_current <= pending_pc_next;
                    state <= STATE_RUN;
                end
            end else begin
                if (running_mem_read) begin
                    if (bus_accepted) begin
                        if (avm_readdatavalid) begin
                            if (rd != 5'd0)
                                registers[rd] <= {32'd0, avm_readdata};
                            pc_current <= pc_next;
                        end else begin
                            pending_rd <= rd;
                            pending_pc_next <= pc_next;
                            state <= STATE_WAIT_READ;
                        end
                    end
                end else if (running_mem_write) begin
                    if (bus_accepted)
                        pc_current <= pc_next;
                end else begin
                    if (ctrl_reg_write && !ctrl_mem_to_reg && rd != 5'd0)
                        registers[rd] <= core_write_data;
                    pc_current <= pc_next;
                end
            end

            registers[0] <= 64'd0;
        end
    end

endmodule
