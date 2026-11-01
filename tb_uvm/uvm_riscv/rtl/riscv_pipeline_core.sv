// ============================================================================
// RISC-V 5-STAGE PIPELINE CPU CORE  (bus-agnostic)
//   IF -> ID -> EX -> MEM -> WB
//
// Instruction fetch uses an internal ROM (instruction_memory), single-cycle.
// DATA access is exposed through a SIMPLE synchronous memory port so the core
// does not depend on any particular bus:
//
//     dmem_read / dmem_write : request strobes (held high until dmem_ready)
//     dmem_addr  / dmem_wdata: address / store data
//     dmem_rdata             : load data (valid on the dmem_ready cycle)
//     dmem_ready             : 1 = the current data request has completed
//
// The core stalls its WHOLE pipeline while a data request is outstanding
// (dmem_read|dmem_write asserted and dmem_ready == 0). A bus bridge (e.g. the
// Avalon wrapper) adapts this simple handshake to the real bus.
//
// Hazards: forwarding (EX/MEM, MEM/WB -> EX), load-use 1-cycle stall,
//          branch/jump resolved in EX with IF/ID + ID/EX flush.
// ============================================================================
module riscv_pipeline_core (
    input  wire        clk,
    input  wire        rst,            // active-high, synchronous-release async-assert

    // Simple data-memory interface (driven to a bus bridge)
    output wire        dmem_read,
    output wire        dmem_write,
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    input  wire [31:0] dmem_rdata,
    input  wire        dmem_ready,

    // Debug
    output wire [31:0] out_pc,
    output wire [31:0] out_alu_result
);

    wire        mem_stall;
    wire        load_use_stall;
    wire        redirect;
    wire [31:0] redirect_target;

    // ===================================================================== IF
    reg  [31:0] pc_if;
    wire [31:0] instr_if;
    wire [31:0] pc_plus4_if = pc_if + 32'd4;

    instruction_memory u_imem (.addr (pc_if), .instruction (instr_if));

    always @(posedge clk or posedge rst) begin
        if (rst)                 pc_if <= 32'd0;
        else if (mem_stall)      pc_if <= pc_if;
        else if (redirect)       pc_if <= redirect_target;
        else if (load_use_stall) pc_if <= pc_if;
        else                     pc_if <= pc_plus4_if;
    end

    // ================================================================= IF/ID
    reg        ifid_valid;
    reg [31:0] ifid_pc, ifid_pc4, ifid_instr;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ifid_valid <= 1'b0; ifid_pc <= 0; ifid_pc4 <= 0; ifid_instr <= 0;
        end else if (mem_stall) begin
            // hold
        end else if (redirect) begin
            ifid_valid <= 1'b0;
        end else if (load_use_stall) begin
            // hold
        end else begin
            ifid_valid <= 1'b1;
            ifid_pc    <= pc_if;
            ifid_pc4   <= pc_plus4_if;
            ifid_instr <= instr_if;
        end
    end

    // ===================================================================== ID
    wire [6:0] opcode_id = ifid_instr[6:0];
    wire [4:0] rd_id     = ifid_instr[11:7];
    wire [2:0] funct3_id = ifid_instr[14:12];
    wire [4:0] rs1_id    = ifid_instr[19:15];
    wire [4:0] rs2_id    = ifid_instr[24:20];
    wire [6:0] funct7_id = ifid_instr[31:25];

    wire       raw_branch, raw_mem_read, raw_mem_to_reg;
    wire [1:0] raw_alu_op;
    wire       raw_mem_write, raw_alu_src, raw_reg_write, raw_jump, raw_jalr;

    control_unit u_control (
        .opcode (opcode_id), .funct3 (funct3_id), .funct7 (funct7_id),
        .branch (raw_branch), .mem_read (raw_mem_read), .mem_to_reg (raw_mem_to_reg),
        .alu_op (raw_alu_op), .mem_write (raw_mem_write), .alu_src (raw_alu_src),
        .reg_write (raw_reg_write), .jump (raw_jump), .jalr (raw_jalr)
    );

    wire ctrl_ok      = ifid_valid;
    wire reg_write_id = ctrl_ok & raw_reg_write;
    wire mem_read_id  = ctrl_ok & raw_mem_read;
    wire mem_write_id = ctrl_ok & raw_mem_write;
    wire branch_id    = ctrl_ok & raw_branch;
    wire jump_id      = ctrl_ok & raw_jump;
    wire jalr_id      = ctrl_ok & raw_jalr;

    wire [31:0] wb_value;
    wire        wb_reg_write;
    wire [4:0]  wb_rd;
    wire [31:0] rdata1_id, rdata2_id;

    register_file u_regfile (
        .clk (clk), .rst (rst), .reg_write (wb_reg_write),
        .read_reg1 (rs1_id), .read_reg2 (rs2_id), .write_reg (wb_rd),
        .write_data (wb_value), .read_data1 (rdata1_id), .read_data2 (rdata2_id)
    );

    wire [31:0] imm_id;
    imm_gen u_immgen (.instruction (ifid_instr), .imm (imm_id));

    wire [3:0] alu_ctrl_id;
    alu_control u_alu_ctrl (
        .alu_op (raw_alu_op), .funct3 (funct3_id), .funct7 (funct7_id),
        .alu_control_out (alu_ctrl_id)
    );

    wire is_lui_id     = (opcode_id == 7'b0110111);
    wire is_auipc_id   = (opcode_id == 7'b0010111);
    wire is_jaljalr_id = raw_jump | raw_jalr;
    wire [1:0] wb_sel_id = is_lui_id     ? 2'b01 :
                           is_auipc_id   ? 2'b10 :
                           is_jaljalr_id ? 2'b11 : 2'b00;

    wire        idex_valid, idex_mem_read;
    wire [4:0]  idex_rd;
    assign load_use_stall = idex_valid & idex_mem_read & (idex_rd != 5'd0) &
                            ((idex_rd == rs1_id) | (idex_rd == rs2_id)) & ~mem_stall;

    // ================================================================= ID/EX
    reg        idex_valid_r;
    reg [31:0] idex_pc, idex_pc4, idex_rdata1, idex_rdata2, idex_imm;
    reg [4:0]  idex_rs1, idex_rs2, idex_rd_r;
    reg [2:0]  idex_funct3;
    reg [3:0]  idex_alu_ctrl;
    reg        idex_alu_src, idex_reg_write, idex_mem_read_r, idex_mem_write;
    reg        idex_branch, idex_jump, idex_jalr;
    reg [1:0]  idex_wb_sel;

    wire flush_idex = redirect | load_use_stall;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            idex_valid_r<=0; idex_reg_write<=0; idex_mem_read_r<=0; idex_mem_write<=0;
            idex_branch<=0; idex_jump<=0; idex_jalr<=0; idex_alu_src<=0; idex_wb_sel<=0;
            idex_pc<=0; idex_pc4<=0; idex_rdata1<=0; idex_rdata2<=0; idex_imm<=0;
            idex_rs1<=0; idex_rs2<=0; idex_rd_r<=0; idex_funct3<=0; idex_alu_ctrl<=0;
        end else if (mem_stall) begin
            // hold EX instruction while memory busy
        end else if (flush_idex) begin
            idex_valid_r<=0; idex_reg_write<=0; idex_mem_read_r<=0; idex_mem_write<=0;
            idex_branch<=0; idex_jump<=0; idex_jalr<=0; idex_alu_src<=0; idex_wb_sel<=0;
            idex_pc<=0; idex_pc4<=0; idex_rdata1<=0; idex_rdata2<=0; idex_imm<=0;
            idex_rs1<=0; idex_rs2<=0; idex_rd_r<=0; idex_funct3<=0; idex_alu_ctrl<=0;
        end else begin
            idex_valid_r    <= ifid_valid;
            idex_pc         <= ifid_pc;
            idex_pc4        <= ifid_pc4;
            idex_rdata1     <= rdata1_id;
            idex_rdata2     <= rdata2_id;
            idex_imm        <= imm_id;
            idex_rs1        <= rs1_id;
            idex_rs2        <= rs2_id;
            idex_rd_r       <= rd_id;
            idex_funct3     <= funct3_id;
            idex_alu_ctrl   <= alu_ctrl_id;
            idex_alu_src    <= raw_alu_src;
            idex_reg_write  <= reg_write_id;
            idex_mem_read_r <= mem_read_id;
            idex_mem_write  <= mem_write_id;
            idex_branch     <= branch_id;
            idex_jump       <= jump_id;
            idex_jalr       <= jalr_id;
            idex_wb_sel     <= wb_sel_id;
        end
    end

    assign idex_valid    = idex_valid_r;
    assign idex_mem_read = idex_mem_read_r;
    assign idex_rd       = idex_rd_r;

    // ===================================================================== EX
    wire        exmem_reg_write, exmem_mem_read, exmem_mem_write;
    wire [4:0]  exmem_rd;
    wire [31:0] exmem_ex_nonmem;
    wire        memwb_reg_write;
    wire [4:0]  memwb_rd;
    wire [31:0] memwb_wb_value;

    wire fwdA_exmem = exmem_reg_write & (exmem_rd!=0) & ~exmem_mem_read & (exmem_rd==idex_rs1);
    wire fwdA_memwb = memwb_reg_write & (memwb_rd!=0) & (memwb_rd==idex_rs1);
    wire fwdB_exmem = exmem_reg_write & (exmem_rd!=0) & ~exmem_mem_read & (exmem_rd==idex_rs2);
    wire fwdB_memwb = memwb_reg_write & (memwb_rd!=0) & (memwb_rd==idex_rs2);

    wire [31:0] fwd_a = fwdA_exmem ? exmem_ex_nonmem :
                        fwdA_memwb ? memwb_wb_value  : idex_rdata1;
    wire [31:0] fwd_b = fwdB_exmem ? exmem_ex_nonmem :
                        fwdB_memwb ? memwb_wb_value  : idex_rdata2;

    wire [31:0] alu_a_ex = fwd_a;
    wire [31:0] alu_b_ex = idex_alu_src ? idex_imm : fwd_b;

    wire [31:0] alu_result_ex;
    wire        alu_zero_ex;
    alu u_alu (.a (alu_a_ex), .b (alu_b_ex), .alu_control (idex_alu_ctrl),
               .result (alu_result_ex), .zero (alu_zero_ex));

    wire branch_taken_ex;
    branch_control u_branch_ctrl (
        .branch (idex_branch), .funct3 (idex_funct3),
        .alu_result (alu_result_ex), .zero (alu_zero_ex),
        .branch_taken (branch_taken_ex)
    );

    wire [31:0] branch_target_ex = idex_pc + idex_imm;
    wire [31:0] jalr_raw_ex      = fwd_a + idex_imm;
    wire [31:0] jalr_target_ex   = {jalr_raw_ex[31:1], 1'b0};

    assign redirect        = idex_valid & (branch_taken_ex | idex_jump | idex_jalr) & ~mem_stall;
    assign redirect_target = idex_jalr ? jalr_target_ex : branch_target_ex;

    wire [31:0] lui_ex   = idex_imm;
    wire [31:0] auipc_ex = idex_pc + idex_imm;
    wire [31:0] ex_nonmem_result_ex =
        (idex_wb_sel==2'b01) ? lui_ex   :
        (idex_wb_sel==2'b10) ? auipc_ex :
        (idex_wb_sel==2'b11) ? idex_pc4 : alu_result_ex;

    wire [31:0] store_data_ex = fwd_b;

    // ================================================================= EX/MEM
    reg        exmem_valid, exmem_reg_write_r, exmem_mem_read_r, exmem_mem_write_r;
    reg [4:0]  exmem_rd_r;
    reg [31:0] exmem_alu_result, exmem_store_data, exmem_ex_nonmem_r;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            exmem_valid<=0; exmem_reg_write_r<=0; exmem_mem_read_r<=0; exmem_mem_write_r<=0;
            exmem_rd_r<=0; exmem_alu_result<=0; exmem_store_data<=0; exmem_ex_nonmem_r<=0;
        end else if (mem_stall) begin
            // hold memory instruction being serviced
        end else begin
            exmem_valid       <= idex_valid;
            exmem_reg_write_r <= idex_reg_write & idex_valid;
            exmem_mem_read_r  <= idex_mem_read_r & idex_valid;
            exmem_mem_write_r <= idex_mem_write  & idex_valid;
            exmem_rd_r        <= idex_rd_r;
            exmem_alu_result  <= alu_result_ex;
            exmem_store_data  <= store_data_ex;
            exmem_ex_nonmem_r <= ex_nonmem_result_ex;
        end
    end

    assign exmem_reg_write = exmem_reg_write_r;
    assign exmem_mem_read  = exmem_mem_read_r;
    assign exmem_mem_write = exmem_mem_write_r;
    assign exmem_rd        = exmem_rd_r;
    assign exmem_ex_nonmem = exmem_ex_nonmem_r;

    // ==================================================================== MEM
    // Simple memory handshake: request held until dmem_ready.
    wire mem_req = exmem_mem_read_r | exmem_mem_write_r;
    assign mem_stall  = mem_req & ~dmem_ready;

    assign dmem_read  = exmem_mem_read_r;
    assign dmem_write = exmem_mem_write_r;
    assign dmem_addr  = exmem_alu_result;
    assign dmem_wdata = exmem_store_data;

    wire [31:0] wb_value_mem = exmem_mem_read_r ? dmem_rdata : exmem_ex_nonmem_r;

    // ================================================================= MEM/WB
    reg        memwb_reg_write_r;
    reg [4:0]  memwb_rd_r;
    reg [31:0] memwb_wb_value_r;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            memwb_reg_write_r <= 0; memwb_rd_r <= 0; memwb_wb_value_r <= 0;
        end else if (mem_stall) begin
            memwb_reg_write_r <= 1'b0; memwb_rd_r <= 5'd0; memwb_wb_value_r <= 32'd0;
        end else begin
            memwb_reg_write_r <= exmem_reg_write_r & exmem_valid;
            memwb_rd_r        <= exmem_rd_r;
            memwb_wb_value_r  <= wb_value_mem;
        end
    end

    assign memwb_reg_write = memwb_reg_write_r;
    assign memwb_rd        = memwb_rd_r;
    assign memwb_wb_value  = memwb_wb_value_r;

    // ===================================================================== WB
    assign wb_reg_write = memwb_reg_write_r;
    assign wb_rd        = memwb_rd_r;
    assign wb_value     = memwb_wb_value_r;

    assign out_pc         = pc_if;
    assign out_alu_result = alu_result_ex;

endmodule
