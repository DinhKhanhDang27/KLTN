`timescale 1ns / 1ps
// ===========================================================================
// axi_4_wrapper_riscv
// ---------------------------------------------------------------------------
// RISC-V RV32I core wrapped as an AXI4 (full) master. Replaces the Avalon-MM
// master (riscv_avalon_wrapper). Instruction fetch stays internal (see
// instruction_memory); only data loads/stores go out on the AXI bus.
//
// Compared with the first draft, this version drives EVERY signal the
// Forencich axi_interconnect slave port expects (id / lock / cache / prot /
// qos) and captures bresp/rresp for debug. Single-beat transfers (awlen=0)
// are issued, which is what the interconnect + register/RAM slaves need.
// ===========================================================================
module axi_4_wrapper_riscv #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter STRB_WIDTH = (DATA_WIDTH/8),
    parameter ID_WIDTH   = 8
) (
    input  wire                   clk,
    input  wire                   reset_n,      // active-low

    // ---- AXI4 master: write address channel (AW) ----
    output wire [ID_WIDTH-1:0]    m_axi_awid,
    output wire [ADDR_WIDTH-1:0]  m_axi_awaddr,
    output wire [7:0]             m_axi_awlen,
    output wire [2:0]             m_axi_awsize,
    output wire [1:0]             m_axi_awburst,
    output wire                   m_axi_awlock,
    output wire [3:0]             m_axi_awcache,
    output wire [2:0]             m_axi_awprot,
    output wire [3:0]             m_axi_awqos,
    output wire                   m_axi_awvalid,
    input  wire                   m_axi_awready,

    // ---- AXI4 master: write data channel (W) ----
    output wire [DATA_WIDTH-1:0]  m_axi_wdata,
    output wire [STRB_WIDTH-1:0]  m_axi_wstrb,
    output wire                   m_axi_wlast,
    output wire                   m_axi_wvalid,
    input  wire                   m_axi_wready,

    // ---- AXI4 master: write response channel (B) ----
    input  wire [ID_WIDTH-1:0]    m_axi_bid,
    input  wire [1:0]             m_axi_bresp,
    input  wire                   m_axi_bvalid,
    output wire                   m_axi_bready,

    // ---- AXI4 master: read address channel (AR) ----
    output wire [ID_WIDTH-1:0]    m_axi_arid,
    output wire [ADDR_WIDTH-1:0]  m_axi_araddr,
    output wire [7:0]             m_axi_arlen,
    output wire [2:0]             m_axi_arsize,
    output wire [1:0]             m_axi_arburst,
    output wire                   m_axi_arlock,
    output wire [3:0]             m_axi_arcache,
    output wire [2:0]             m_axi_arprot,
    output wire [3:0]             m_axi_arqos,
    output wire                   m_axi_arvalid,
    input  wire                   m_axi_arready,

    // ---- AXI4 master: read data channel (R) ----
    input  wire [ID_WIDTH-1:0]    m_axi_rid,
    input  wire [DATA_WIDTH-1:0]  m_axi_rdata,
    input  wire [1:0]             m_axi_rresp,
    input  wire                   m_axi_rlast,
    input  wire                   m_axi_rvalid,
    output wire                   m_axi_rready,

    // ---- debug ----
    output wire [31:0]            out_pc,
    output wire [31:0]            out_alu_result
);

    // FSM states for AXI transactions
    localparam STATE_RUN  = 3'd0;
    localparam STATE_AR   = 3'd1;
    localparam STATE_R    = 3'd2;
    localparam STATE_AW_W = 3'd3;
    localparam STATE_B    = 3'd4;

    reg [2:0]  state;
    reg [31:0] pc_current;
    reg [4:0]  pending_rd;
    reg [31:0] pending_pc_next;
    reg        aw_done;
    reg        w_done;

    reg [31:0] registers [0:31];

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

    wire [31:0] reg_read_data1 = (rs1 == 5'd0) ? 32'd0 : registers[rs1];
    wire [31:0] reg_read_data2 = (rs2 == 5'd0) ? 32'd0 : registers[rs2];
    wire [31:0] imm;
    wire [3:0]  alu_ctrl;
    wire [31:0] alu_input_b;
    wire [31:0] alu_result;
    wire        alu_zero;

    wire [31:0] pc_plus4         = pc_current + 32'd4;
    wire [31:0] pc_branch_target = pc_current + imm;
    wire [31:0] jalr_target_raw  = reg_read_data1 + imm;
    wire [31:0] jalr_target      = {jalr_target_raw[31:1], 1'b0};

    wire        branch_taken;
    wire [31:0] pc_branch_or_seq = branch_taken ? pc_branch_target : pc_plus4;
    wire [31:0] pc_after_jal     = ctrl_jump ? pc_branch_target : pc_branch_or_seq;
    wire [31:0] pc_next          = ctrl_jalr ? jalr_target : pc_after_jal;

    wire [31:0] lui_result       = imm;
    wire [31:0] auipc_result     = pc_current + imm;
    wire        is_lui           = (opcode == 7'b0110111);
    wire        is_auipc         = (opcode == 7'b0010111);
    wire        is_jal_jalr      = ctrl_jump | ctrl_jalr;
    wire [31:0] core_write_data  = is_lui      ? lui_result :
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
        .jalr        (ctrl_jalr)
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

    // ------------------------------------------------------------------------
    // AXI4 master interface assignments
    // ------------------------------------------------------------------------
    // Constant attributes: single INCR beat, 4 bytes, normal non-cacheable,
    // unprivileged data access, no QoS, id 0.
    assign m_axi_awid    = {ID_WIDTH{1'b0}};
    assign m_axi_awlen   = 8'd0;      // 1 transfer
    assign m_axi_awsize  = 3'b010;    // 4 bytes
    assign m_axi_awburst = 2'b01;     // INCR
    assign m_axi_awlock  = 1'b0;
    assign m_axi_awcache = 4'b0011;   // modifiable, bufferable
    assign m_axi_awprot  = 3'b000;
    assign m_axi_awqos   = 4'b0000;

    assign m_axi_arid    = {ID_WIDTH{1'b0}};
    assign m_axi_arlen   = 8'd0;
    assign m_axi_arsize  = 3'b010;
    assign m_axi_arburst = 2'b01;
    assign m_axi_arlock  = 1'b0;
    assign m_axi_arcache = 4'b0011;
    assign m_axi_arprot  = 3'b000;
    assign m_axi_arqos   = 4'b0000;

    assign m_axi_awaddr = alu_result;
    assign m_axi_araddr = alu_result;

    assign m_axi_wdata  = reg_read_data2;
    assign m_axi_wstrb  = (funct3 == 3'b000) ? 4'b0001 : // SB
                          (funct3 == 3'b001) ? 4'b0011 : // SH
                          4'b1111;                        // SW
    assign m_axi_wlast  = 1'b1;

    assign m_axi_arvalid = (state == STATE_AR);
    assign m_axi_rready  = (state == STATE_R);

    assign m_axi_awvalid = (state == STATE_AW_W) && !aw_done;
    assign m_axi_wvalid  = (state == STATE_AW_W) && !w_done;
    assign m_axi_bready  = (state == STATE_B);

    assign out_pc         = pc_current;
    assign out_alu_result = alu_result;

    // ------------------------------------------------------------------------
    // FSM and datapath
    // ------------------------------------------------------------------------
    integer i;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= STATE_RUN;
            pc_current <= 32'd0;
            pending_rd <= 5'd0;
            pending_pc_next <= 32'd0;
            aw_done <= 1'b0;
            w_done <= 1'b0;
            for (i = 0; i < 32; i = i + 1)
                registers[i] <= 32'd0;
        end else begin
            case (state)
                STATE_RUN: begin
                    if (ctrl_mem_read) begin
                        pending_rd <= rd;
                        pending_pc_next <= pc_next;
                        state <= STATE_AR;
                    end else if (ctrl_mem_write) begin
                        pending_pc_next <= pc_next;
                        aw_done <= 1'b0;
                        w_done <= 1'b0;
                        state <= STATE_AW_W;
                    end else begin
                        if (ctrl_reg_write && !ctrl_mem_to_reg && rd != 5'd0)
                            registers[rd] <= core_write_data;
                        pc_current <= pc_next;
                    end
                end

                STATE_AR: begin
                    if (m_axi_arready)
                        state <= STATE_R;
                end

                STATE_R: begin
                    if (m_axi_rvalid) begin
                        if (pending_rd != 5'd0)
                            registers[pending_rd] <= m_axi_rdata; // word load
                        pc_current <= pending_pc_next;
                        state <= STATE_RUN;
                    end
                end

                STATE_AW_W: begin
                    if (m_axi_awready && m_axi_awvalid) aw_done <= 1'b1;
                    if (m_axi_wready  && m_axi_wvalid)  w_done  <= 1'b1;

                    if ((aw_done || m_axi_awready) && (w_done || m_axi_wready))
                        state <= STATE_B;
                end

                STATE_B: begin
                    if (m_axi_bvalid) begin
                        pc_current <= pending_pc_next;
                        state <= STATE_RUN;
                    end
                end

                default: state <= STATE_RUN;
            endcase

            registers[0] <= 32'd0; // x0 is always 0
        end
    end

endmodule
