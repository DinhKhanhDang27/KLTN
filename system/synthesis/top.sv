module top (
    input  wire        CLOCK_50,
    input  wire [1:0]  KEY,
    output wire [7:0]  LED,

    output wire [12:0] DRAM_ADDR,
    output wire [1:0]  DRAM_BA,
    output wire        DRAM_CAS_N,
    output wire        DRAM_CKE,
    output wire        DRAM_CLK,
    output wire        DRAM_CS_N,
    inout  wire [15:0] DRAM_DQ,
    output wire [1:0]  DRAM_DQM,
    output wire        DRAM_RAS_N,
    output wire        DRAM_WE_N
);

    wire [63:0] riscv_pc;
    wire [63:0] riscv_alu_result;
    wire        sha256_irq;
    reg  [15:0] reset_cnt = 16'd0;
    wire        por_done = &reset_cnt;
    wire        system_reset_n = por_done;

    assign LED[0] = sha256_irq;
    assign LED[7:1] = riscv_pc[8:2];
    assign DRAM_CLK = CLOCK_50;

    always @(posedge CLOCK_50) begin
        if (!por_done)
            reset_cnt <= reset_cnt + 16'd1;
    end

    system u_system (
        .clk_clk                                     (CLOCK_50),
        .reset_reset_n                               (system_reset_n),

        .new_sdram_controller_0_wire_addr            (DRAM_ADDR),
        .new_sdram_controller_0_wire_ba              (DRAM_BA),
        .new_sdram_controller_0_wire_cas_n           (DRAM_CAS_N),
        .new_sdram_controller_0_wire_cke             (DRAM_CKE),
        .new_sdram_controller_0_wire_cs_n            (DRAM_CS_N),
        .new_sdram_controller_0_wire_dq              (DRAM_DQ),
        .new_sdram_controller_0_wire_dqm             (DRAM_DQM),
        .new_sdram_controller_0_wire_ras_n           (DRAM_RAS_N),
        .new_sdram_controller_0_wire_we_n            (DRAM_WE_N),

        .riscv_avalon_wrapper_0_debug_out_pc         (riscv_pc),
        .riscv_avalon_wrapper_0_debug_out_alu_result (riscv_alu_result),
        .sha256_avalon_wrapper_0_irq_conduit_irq     (sha256_irq)
    );

endmodule
