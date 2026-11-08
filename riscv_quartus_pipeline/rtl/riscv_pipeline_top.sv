// ============================================================================
// RISC-V 32-bit 5-STAGE PIPELINE Datapath (Top-level)
// Stages: IF -> ID -> EX -> MEM -> WB
// Pipeline registers: IF/ID, ID/EX, EX/MEM, MEM/WB
// Hazard handling:
//   - Forwarding Unit  : EX/MEM and MEM/WB  ->  EX  (data hazards)
//   - Hazard Detection : 1-cycle stall for load-use hazard
//   - Branch/Jump      : resolved in EX, flush IF/ID + ID/EX on redirect
// Supports: R-type, I-type ALU, LW, SW, Branch, JAL, JALR, LUI, AUIPC
// Drop-in replacement for riscv_top (same ports). Reuses existing submodules.
// Assumes single-cycle instruction & data memory (same as riscv_top).
// ============================================================================
module riscv_pipeline_top (
    input  clk,
    input  rst,
    output [31:0] out_pc,
    output [31:0] out_alu_result
);

    // ------------------------------------------------------------------------
    // Global pipeline control (driven from later stages)
    // ------------------------------------------------------------------------
    wire        stall;              // load-use stall (freeze IF, IF/ID; bubble ID/EX)
    wire        redirect;           // branch/jump taken in EX
    wire [31:0] redirect_target;

    // ========================================================================
    // STAGE 1 : IF  (Instruction Fetch)
    // ========================================================================
    reg  [31:0] pc_if;
    wire [31:0] instr_if;
    wire [31:0] pc_plus4_if = pc_if + 32'd4;

    instruction_memory u_imem (
        .addr        (pc_if),
        .instruction (instr_if)
    );

    wire [31:0] pc_next_if = redirect ? redirect_target :
                             stall    ? pc_if           :
                                        pc_plus4_if;

    always @(posedge clk or posedge rst) begin
        if (rst) pc_if <= 32'd0;
        else     pc_if <= pc_next_if;
    end

    // ========================================================================
    // IF/ID pipeline register
    // ========================================================================
    reg        ifid_valid;
    reg [31:0] ifid_pc, ifid_pc4, ifid_instr;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ifid_valid <= 1'b0;
            ifid_pc    <= 32'd0;
            ifid_pc4   <= 32'd0;
            ifid_instr <= 32'd0;
        end else if (redirect) begin
            // Flush: the instruction just fetched (branch+2) is wrong
            ifid_valid <= 1'b0;
        end else if (stall) begin
            // Hold: keep current IF/ID so the stalled instruction re-decodes
            ifid_valid <= ifid_valid;
            ifid_pc    <= ifid_pc;
            ifid_pc4   <= ifid_pc4;
            ifid_instr <= ifid_instr;
        end else begin
            ifid_valid <= 1'b1;
            ifid_pc    <= pc_if;
            ifid_pc4   <= pc_plus4_if;
            ifid_instr <= instr_if;
        end
    end

    // ========================================================================
    // STAGE 2 : ID  (Decode, register read, immediate, control)
    // ========================================================================
    wire [6:0] opcode_id = ifid_instr[6:0];
    wire [4:0] rd_id     = ifid_instr[11:7];
    wire [2:0] funct3_id = ifid_instr[14:12];
    wire [4:0] rs1_id    = ifid_instr[19:15];
    wire [4:0] rs2_id    = ifid_instr[24:20];
    wire [6:0] funct7_id = ifid_instr[31:25];

    // --- Raw control signals (from the shared control unit) ---
    wire       raw_branch, raw_mem_read, raw_mem_to_reg;
    wire [1:0] raw_alu_op;
    wire       raw_mem_write, raw_alu_src, raw_reg_write;
    wire       raw_jump, raw_jalr;

    control_unit u_control (
        .opcode     (opcode_id),
        .funct3     (funct3_id),
        .funct7     (funct7_id),
        .branch     (raw_branch),
        .mem_read   (raw_mem_read),
        .mem_to_reg (raw_mem_to_reg),
        .alu_op     (raw_alu_op),
        .mem_write  (raw_mem_write),
        .alu_src    (raw_alu_src),
        .reg_write  (raw_reg_write),
        .jump       (raw_jump),
        .jalr       (raw_jalr)
    );

    // Gate side-effecting controls by validity (bubble/flush => NOP)
    wire ctrl_ok        = ifid_valid;
    wire reg_write_id   = ctrl_ok & raw_reg_write;
    wire mem_read_id    = ctrl_ok & raw_mem_read;
    wire mem_write_id   = ctrl_ok & raw_mem_write;
    wire branch_id      = ctrl_ok & raw_branch;
    wire jump_id        = ctrl_ok & raw_jump;
    wire jalr_id        = ctrl_ok & raw_jalr;
    wire mem_to_reg_id  = raw_mem_to_reg;   // non side-effecting, select only
    wire alu_src_id     = raw_alu_src;

    // Register file (write happens in WB; negedge write => write-first for ID)
    wire [31:0] wb_value;          // from WB
    wire        wb_reg_write;      // from WB
    wire [4:0]  wb_rd;             // from WB
    wire [31:0] rdata1_id, rdata2_id;

    register_file u_regfile (
        .clk        (clk),
        .rst        (rst),
        .reg_write  (wb_reg_write),
        .read_reg1  (rs1_id),
        .read_reg2  (rs2_id),
        .write_reg  (wb_rd),
        .write_data (wb_value),
        .read_data1 (rdata1_id),
        .read_data2 (rdata2_id)
    );

    wire [31:0] imm_id;
    imm_gen u_immgen (
        .instruction (ifid_instr),
        .imm         (imm_id)
    );

    wire [3:0] alu_ctrl_id;
    alu_control u_alu_ctrl (
        .alu_op          (raw_alu_op),
        .funct3          (funct3_id),
        .funct7          (funct7_id),
        .alu_control_out (alu_ctrl_id)
    );

    // Write-back source select (same encoding as single-cycle riscv_top)
    //   00 = ALU / memory , 01 = LUI , 10 = AUIPC , 11 = JAL/JALR return
    wire is_lui_id      = (opcode_id == 7'b0110111);
    wire is_auipc_id    = (opcode_id == 7'b0010111);
    wire is_jaljalr_id  = raw_jump | raw_jalr;
    wire [1:0] wb_sel_id = is_lui_id     ? 2'b01 :
                           is_auipc_id   ? 2'b10 :
                           is_jaljalr_id ? 2'b11 : 2'b00;

    // ========================================================================
    // Hazard Detection Unit  (load-use)  -> produces `stall`
    // Stall when the instruction in EX is a load whose rd feeds a source
    // register of the instruction currently in ID.
    // ========================================================================
    wire        idex_valid;
    wire        idex_mem_read;
    wire [4:0]  idex_rd;

    assign stall = idex_valid & idex_mem_read & (idex_rd != 5'd0) &
                   ((idex_rd == rs1_id) | (idex_rd == rs2_id));

    // ========================================================================
    // ID/EX pipeline register
    // bubble when: reset, redirect (squash branch+1), or stall (load-use)
    // ========================================================================
    reg        idex_valid_r;
    reg [31:0] idex_pc, idex_pc4;
    reg [31:0] idex_rdata1, idex_rdata2, idex_imm;
    reg [4:0]  idex_rs1, idex_rs2, idex_rd_r;
    reg [2:0]  idex_funct3;
    reg [3:0]  idex_alu_ctrl;
    reg        idex_alu_src;
    reg        idex_reg_write, idex_mem_read_r, idex_mem_write, idex_mem_to_reg;
    reg        idex_branch, idex_jump, idex_jalr;
    reg [1:0]  idex_wb_sel;

    // NOTE: async reset must test `rst` directly (Quartus error 10200 if the
    // reset condition is a combined expression). redirect/stall produce the
    // same bubble synchronously.
    wire insert_bubble_idex = redirect | stall;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            idex_valid_r    <= 1'b0;
            idex_reg_write  <= 1'b0;
            idex_mem_read_r <= 1'b0;
            idex_mem_write  <= 1'b0;
            idex_branch     <= 1'b0;
            idex_jump       <= 1'b0;
            idex_jalr       <= 1'b0;
            idex_mem_to_reg <= 1'b0;
            idex_alu_src    <= 1'b0;
            idex_wb_sel     <= 2'b00;
            idex_pc         <= 32'd0;
            idex_pc4        <= 32'd0;
            idex_rdata1     <= 32'd0;
            idex_rdata2     <= 32'd0;
            idex_imm        <= 32'd0;
            idex_rs1        <= 5'd0;
            idex_rs2        <= 5'd0;
            idex_rd_r       <= 5'd0;
            idex_funct3     <= 3'd0;
            idex_alu_ctrl   <= 4'd0;
        end else if (insert_bubble_idex) begin
            // synchronous bubble (flush on redirect / hold on load-use stall)
            idex_valid_r    <= 1'b0;
            idex_reg_write  <= 1'b0;
            idex_mem_read_r <= 1'b0;
            idex_mem_write  <= 1'b0;
            idex_branch     <= 1'b0;
            idex_jump       <= 1'b0;
            idex_jalr       <= 1'b0;
            idex_mem_to_reg <= 1'b0;
            idex_alu_src    <= 1'b0;
            idex_wb_sel     <= 2'b00;
            idex_pc         <= 32'd0;
            idex_pc4        <= 32'd0;
            idex_rdata1     <= 32'd0;
            idex_rdata2     <= 32'd0;
            idex_imm        <= 32'd0;
            idex_rs1        <= 5'd0;
            idex_rs2        <= 5'd0;
            idex_rd_r       <= 5'd0;
            idex_funct3     <= 3'd0;
            idex_alu_ctrl   <= 4'd0;
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
            idex_alu_src    <= alu_src_id;
            idex_reg_write  <= reg_write_id;
            idex_mem_read_r <= mem_read_id;
            idex_mem_write  <= mem_write_id;
            idex_mem_to_reg <= mem_to_reg_id;
            idex_branch     <= branch_id;
            idex_jump       <= jump_id;
            idex_jalr       <= jalr_id;
            idex_wb_sel     <= wb_sel_id;
        end
    end

    assign idex_valid    = idex_valid_r;
    assign idex_mem_read = idex_mem_read_r;
    assign idex_rd       = idex_rd_r;

    // ========================================================================
    // STAGE 3 : EX  (ALU, forwarding, branch/jump resolution)
    // ========================================================================
    // --- EX/MEM and MEM/WB signals used by the forwarding unit ---
    wire        exmem_reg_write;
    wire        exmem_mem_to_reg;
    wire [4:0]  exmem_rd;
    wire [31:0] exmem_ex_nonmem;   // forwardable value from EX/MEM (ALU/lui/auipc/pc4)
    wire        memwb_reg_write;
    wire [4:0]  memwb_rd;
    wire [31:0] memwb_wb_value;    // forwardable value from MEM/WB (incl. loaded data)

    // Forwarding selects: 2'b10 = EX/MEM, 2'b01 = MEM/WB, 2'b00 = register file
    wire fwdA_exmem = exmem_reg_write & (exmem_rd != 5'd0) &
                      ~exmem_mem_to_reg & (exmem_rd == idex_rs1);
    wire fwdA_memwb = memwb_reg_write & (memwb_rd != 5'd0) & (memwb_rd == idex_rs1);
    wire fwdB_exmem = exmem_reg_write & (exmem_rd != 5'd0) &
                      ~exmem_mem_to_reg & (exmem_rd == idex_rs2);
    wire fwdB_memwb = memwb_reg_write & (memwb_rd != 5'd0) & (memwb_rd == idex_rs2);

    wire [31:0] fwd_a = fwdA_exmem ? exmem_ex_nonmem :
                        fwdA_memwb ? memwb_wb_value  : idex_rdata1;
    wire [31:0] fwd_b = fwdB_exmem ? exmem_ex_nonmem :
                        fwdB_memwb ? memwb_wb_value  : idex_rdata2;

    // ALU operands
    wire [31:0] alu_a_ex = fwd_a;
    wire [31:0] alu_b_ex = idex_alu_src ? idex_imm : fwd_b;

    wire [31:0] alu_result_ex;
    wire        alu_zero_ex;
    alu u_alu (
        .a           (alu_a_ex),
        .b           (alu_b_ex),
        .alu_control (idex_alu_ctrl),
        .result      (alu_result_ex),
        .zero        (alu_zero_ex)
    );

    // Branch decision (uses forwarded operands via ALU result/zero)
    wire branch_taken_ex;
    branch_control u_branch_ctrl (
        .branch       (idex_branch),
        .funct3       (idex_funct3),
        .alu_result   (alu_result_ex),
        .zero         (alu_zero_ex),
        .branch_taken (branch_taken_ex)
    );

    // Targets
    wire [31:0] branch_target_ex = idex_pc + idex_imm;               // branch & JAL
    wire [31:0] jalr_raw_ex      = fwd_a + idex_imm;                 // JALR uses rs1
    wire [31:0] jalr_target_ex   = {jalr_raw_ex[31:1], 1'b0};

    assign redirect        = idex_valid & (branch_taken_ex | idex_jump | idex_jalr);
    assign redirect_target = idex_jalr ? jalr_target_ex : branch_target_ex;

    // Value written back for non-memory results (collapsed here; loads override in MEM)
    wire [31:0] lui_ex   = idex_imm;
    wire [31:0] auipc_ex = idex_pc + idex_imm;
    wire [31:0] ex_nonmem_result_ex =
        (idex_wb_sel == 2'b01) ? lui_ex   :
        (idex_wb_sel == 2'b10) ? auipc_ex :
        (idex_wb_sel == 2'b11) ? idex_pc4 :
                                 alu_result_ex;

    wire [31:0] store_data_ex = fwd_b;   // forwarded rs2 for stores

    // ========================================================================
    // EX/MEM pipeline register
    // ========================================================================
    reg        exmem_reg_write_r, exmem_mem_read, exmem_mem_write, exmem_mem_to_reg_r;
    reg [4:0]  exmem_rd_r;
    reg [31:0] exmem_alu_result, exmem_store_data, exmem_ex_nonmem_r;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            exmem_reg_write_r  <= 1'b0;
            exmem_mem_read     <= 1'b0;
            exmem_mem_write    <= 1'b0;
            exmem_mem_to_reg_r <= 1'b0;
            exmem_rd_r         <= 5'd0;
            exmem_alu_result   <= 32'd0;
            exmem_store_data   <= 32'd0;
            exmem_ex_nonmem_r  <= 32'd0;
        end else begin
            exmem_reg_write_r  <= idex_reg_write & idex_valid;
            exmem_mem_read     <= idex_mem_read_r & idex_valid;
            exmem_mem_write    <= idex_mem_write & idex_valid;
            exmem_mem_to_reg_r <= idex_mem_to_reg;
            exmem_rd_r         <= idex_rd_r;
            exmem_alu_result   <= alu_result_ex;
            exmem_store_data   <= store_data_ex;
            exmem_ex_nonmem_r  <= ex_nonmem_result_ex;
        end
    end

    assign exmem_reg_write  = exmem_reg_write_r;
    assign exmem_mem_to_reg = exmem_mem_to_reg_r;
    assign exmem_rd         = exmem_rd_r;
    assign exmem_ex_nonmem  = exmem_ex_nonmem_r;

    // ========================================================================
    // STAGE 4 : MEM  (Data memory)
    // ========================================================================
    wire [31:0] dmem_rdata;

    data_memory u_dmem (
        .clk        (clk),
        .mem_read   (exmem_mem_read),
        .mem_write  (exmem_mem_write),
        .addr       (exmem_alu_result),
        .write_data (exmem_store_data),
        .read_data  (dmem_rdata)
    );

    wire [31:0] mem_read_data = dmem_rdata;

    // ------------------------------------------------------------------------
    // To add the memory-mapped SHA-256 accelerator back (exactly like
    // single-cycle riscv_top), instantiate a `sha256` module here, gate
    // data_memory with `& ~sha_select`, and select:
    //     mem_read_data = sha_select ? sha_rdata : dmem_rdata;
    // NOTE: that `sha256` module is not present in this tree; the real SoC
    // uses sha256_avalon_wrapper over Avalon instead.
    // ------------------------------------------------------------------------

    // Final write-back value resolved here (memory loads override EX result)
    wire [31:0] wb_value_mem = exmem_mem_to_reg_r ? mem_read_data : exmem_ex_nonmem_r;

    // ========================================================================
    // MEM/WB pipeline register
    // ========================================================================
    reg        memwb_reg_write_r;
    reg [4:0]  memwb_rd_r;
    reg [31:0] memwb_wb_value_r;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            memwb_reg_write_r <= 1'b0;
            memwb_rd_r        <= 5'd0;
            memwb_wb_value_r  <= 32'd0;
        end else begin
            memwb_reg_write_r <= exmem_reg_write_r;
            memwb_rd_r        <= exmem_rd_r;
            memwb_wb_value_r  <= wb_value_mem;
        end
    end

    assign memwb_reg_write = memwb_reg_write_r;
    assign memwb_rd        = memwb_rd_r;
    assign memwb_wb_value  = memwb_wb_value_r;

    // ========================================================================
    // STAGE 5 : WB  (write back to register file)
    // ========================================================================
    assign wb_reg_write = memwb_reg_write_r;
    assign wb_rd        = memwb_rd_r;
    assign wb_value     = memwb_wb_value_r;

    // ------------------------------------------------------------------------
    // Debug outputs
    // ------------------------------------------------------------------------
    assign out_pc         = pc_if;
    assign out_alu_result = alu_result_ex;

endmodule
