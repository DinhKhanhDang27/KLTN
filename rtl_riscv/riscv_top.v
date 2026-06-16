// ============================================================================
// RISC-V 64-bit Single-Cycle Datapath (Top-level)
// Supports: R-type, I-type ALU, Load(LD), Store(SD), Branch, JAL, JALR,
//           LUI, AUIPC
// Compatible with Quartus II / Cyclone II and ModelSim
// ============================================================================
module riscv_top (
    input  clk,
    input  rst,
    output [63:0] out_pc,
    output [63:0] out_alu_result
);

    // ========================================================================
    // Internal wires
    // ========================================================================
    
    // PC signals
    wire [63:0] pc_current, pc_plus4, pc_next;
    wire [63:0] pc_branch_target, pc_jump_target;
    
    // Instruction
    wire [31:0] instruction;
    wire [6:0]  opcode;
    wire [4:0]  rd, rs1, rs2;
    wire [2:0]  funct3;
    wire [6:0]  funct7;
    
    // Control signals
    wire        ctrl_branch, ctrl_mem_read, ctrl_mem_to_reg;
    wire [1:0]  ctrl_alu_op;
    wire        ctrl_mem_write, ctrl_alu_src, ctrl_reg_write;
    wire        ctrl_jump, ctrl_jalr;
    wire        ctrl_sha2rst, ctrl_sha2push, ctrl_sha2start;
    wire        ctrl_sha2perform, ctrl_sha2finish, ctrl_sha2read;
    
    // ALU signals
    wire [3:0]  alu_ctrl;
    wire [63:0] alu_input_a, alu_input_b, alu_result;
    wire        alu_zero;
    
    // Register file signals
    wire [63:0] reg_read_data1, reg_read_data2;
    wire [63:0] reg_write_data;
    
    // Immediate
    wire [63:0] imm;
    
    // Memory signals
    wire [63:0] mem_read_data;
    wire [63:0] dmem_read_data;

    // SHA-256 accelerator signals
    wire [63:0] sha_read_data;
    wire [63:0] sha_mem_read_data;
    wire        sha_select;
    
    // Branch
    wire        branch_taken;
    
    // ========================================================================
    // Instruction field extraction
    // ========================================================================
    assign opcode = instruction[6:0];
    assign rd     = instruction[11:7];
    assign funct3 = instruction[14:12];
    assign rs1    = instruction[19:15];
    assign rs2    = instruction[24:20];
    assign funct7 = instruction[31:25];
    
    // ========================================================================
    // Program Counter
    // ========================================================================
    pc_register u_pc (
        .clk    (clk),
        .rst    (rst),
        .pc_in  (pc_next),
        .pc_out (pc_current)
    );
    
    // PC + 4
    adder u_pc_adder (
        .a      (pc_current),
        .b      (64'd4),
        .result (pc_plus4)
    );
    
    // Branch target = PC + imm
    adder u_branch_adder (
        .a      (pc_current),
        .b      (imm),
        .result (pc_branch_target)
    );
    
    // JALR target = rs1 + imm (with LSB cleared)
    wire [63:0] jalr_target_raw;
    adder u_jalr_adder (
        .a      (reg_read_data1),
        .b      (imm),
        .result (jalr_target_raw)
    );
    wire [63:0] jalr_target;
    assign jalr_target = {jalr_target_raw[63:1], 1'b0};
    
    // JAL target = PC + imm (same as branch target)
    assign pc_jump_target = pc_branch_target;
    
    // PC Next selection:
    wire [63:0] pc_branch_or_seq;
    assign pc_branch_or_seq = branch_taken ? pc_branch_target : pc_plus4;
    
    wire [63:0] pc_after_jal;
    assign pc_after_jal = ctrl_jump ? pc_jump_target : pc_branch_or_seq;
    
    assign pc_next = ctrl_jalr ? jalr_target : pc_after_jal;
    
    // ========================================================================
    // Instruction Memory
    // ========================================================================
    instruction_memory u_imem (
        .addr        (pc_current),
        .instruction (instruction)
    );
    
    // ========================================================================
    // Control Unit
    // ========================================================================
    control_unit u_control (
        .opcode     (opcode),
        .funct3     (funct3),
        .funct7     (funct7),
        .branch     (ctrl_branch),
        .mem_read   (ctrl_mem_read),
        .mem_to_reg (ctrl_mem_to_reg),
        .alu_op     (ctrl_alu_op),
        .mem_write  (ctrl_mem_write),
        .alu_src    (ctrl_alu_src),
        .reg_write  (ctrl_reg_write),
        .jump       (ctrl_jump),
        .jalr       (ctrl_jalr),
        .sha2rst    (ctrl_sha2rst),
        .sha2push   (ctrl_sha2push),
        .sha2start  (ctrl_sha2start),
        .sha2perform(ctrl_sha2perform),
        .sha2finish (ctrl_sha2finish),
        .sha2read   (ctrl_sha2read)
    );
    
    // ========================================================================
    // Register File
    // ========================================================================
    register_file u_regfile (
        .clk        (clk),
        .rst        (rst),
        .reg_write  (ctrl_reg_write),
        .read_reg1  (rs1),
        .read_reg2  (rs2),
        .write_reg  (rd),
        .write_data (reg_write_data),
        .read_data1 (reg_read_data1),
        .read_data2 (reg_read_data2)
    );
    
    // ========================================================================
    // Immediate Generator
    // ========================================================================
    imm_gen u_immgen (
        .instruction (instruction),
        .imm         (imm)
    );
    
    // ========================================================================
    // ALU Control
    // ========================================================================
    alu_control u_alu_ctrl (
        .alu_op          (ctrl_alu_op),
        .funct3          (funct3),
        .funct7          (funct7),
        .alu_control_out (alu_ctrl)
    );
    
    // ========================================================================
    // ALU
    // ========================================================================
    
    // ALU input A is always rs1
    assign alu_input_a = reg_read_data1;
    
    // ALU input B: rs2 or immediate
    mux2to1 u_alu_mux_b (
        .in0 (reg_read_data2),
        .in1 (imm),
        .sel (ctrl_alu_src),
        .out (alu_input_b)
    );
    
    alu u_alu (
        .a           (alu_input_a),
        .b           (alu_input_b),
        .alu_control (alu_ctrl),
        .result      (alu_result),
        .zero        (alu_zero)
    );
    
    // ========================================================================
    // Branch Control
    // ========================================================================
    branch_control u_branch_ctrl (
        .branch       (ctrl_branch),
        .funct3       (funct3),
        .alu_result   (alu_result),
        .zero         (alu_zero),
        .branch_taken (branch_taken)
    );
    
    // ========================================================================
    // Data Memory (addresses outside SHA range)
    // ========================================================================
    data_memory u_dmem (
        .clk        (clk),
        .mem_read   (ctrl_mem_read & ~sha_select),
        .mem_write  (ctrl_mem_write & ~sha_select),
        .addr       (alu_result),
        .write_data (reg_read_data2),
        .read_data  (dmem_read_data)
    );

    // ========================================================================
    // SHA-256 Accelerator
    // ========================================================================
    sha256 u_sha256 (
        .clk             (clk),
        .rst             (rst),
        .mem_read        (ctrl_mem_read),
        .mem_write       (ctrl_mem_write),
        .addr            (alu_result),
        .write_data      (reg_read_data2),
        .read_data       (sha_mem_read_data),
        .sha_select      (sha_select),
        .sha_rst         (ctrl_sha2rst),
        .sha_push        (ctrl_sha2push),
        .sha_start       (ctrl_sha2start),
        .sha_perform     (ctrl_sha2perform),
        .sha_finish      (ctrl_sha2finish),
        .sha_write_data  (reg_read_data1),
        .sha_read_offset (reg_read_data1),
        .sha_read_data   (sha_read_data)
    );

    // Memory read data mux: select between data memory and SHA-256.
    assign mem_read_data = sha_select ? sha_mem_read_data : dmem_read_data;
    
    // ========================================================================
    // Write-back MUX
    // Selects data to write back to register file:
    //   - LUI:  immediate value
    //   - AUIPC: PC + immediate
    //   - JAL/JALR: PC + 4 (return address)
    //   - Load: memory data
    //   - ALU ops: ALU result
    // ========================================================================
    wire [63:0] alu_or_mem;
    mux2to1 u_wb_alu_mem (
        .in0 (alu_result),
        .in1 (mem_read_data),
        .sel (ctrl_mem_to_reg),
        .out (alu_or_mem)
    );
    
    // LUI result
    wire [63:0] lui_result;
    assign lui_result = imm;
    
    // AUIPC result
    wire [63:0] auipc_result;
    adder u_auipc_adder (
        .a      (pc_current),
        .b      (imm),
        .result (auipc_result)
    );
    
    // Final write-back selection
    wire is_lui, is_auipc, is_jal_jalr;
    assign is_lui      = (opcode == 7'b0110111);
    assign is_auipc    = (opcode == 7'b0010111);
    assign is_jal_jalr = ctrl_jump | ctrl_jalr;
    
    wire [1:0] wb_sel;
    assign wb_sel = is_lui      ? 2'b01 :
                    is_auipc    ? 2'b10 :
                    is_jal_jalr ? 2'b11 : 2'b00;
    
    wire [63:0] core_write_data;
    mux4to1 u_wb_mux (
        .in0 (alu_or_mem),      // Normal ALU result or memory load
        .in1 (lui_result),       // LUI
        .in2 (auipc_result),     // AUIPC
        .in3 (pc_plus4),         // JAL/JALR return address
        .sel (wb_sel),
        .out (core_write_data)
    );

    assign reg_write_data = ctrl_sha2read ? sha_read_data : core_write_data;

    // Debug outputs — expose key signals to pins so Quartus retains all logic
    assign out_pc         = pc_current;
    assign out_alu_result = alu_result;

endmodule
