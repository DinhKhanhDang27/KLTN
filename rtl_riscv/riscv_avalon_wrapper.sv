// ============================================================================
// riscv_avalon_wrapper  -  THIN Avalon-MM bridge for the pipelined RISC-V core
//
// This file contains NO CPU logic. It only:
//   1) instantiates the pipeline CPU core (riscv_pipeline_core), and
//   2) adapts the core's simple data-memory handshake to Avalon-MM.
//
// Protocol adaptation (the only logic here):
//   Avalon uses a 2-phase handshake: an address phase gated by `waitrequest`,
//   then (for reads) a later `readdatavalid`. The core uses one `ready` strobe.
//   A single `read_pending` flag bridges the two:
//     - assert avm_read until the address is accepted (!waitrequest)
//     - then wait for avm_readdatavalid and pulse `ready`
//     - writes complete as soon as the address is accepted.
// ============================================================================
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

    output wire [31:0] out_pc,
    output wire [31:0] out_alu_result
);

    wire rst = ~reset_n;

    // ---- Core's simple data-memory interface ----
    wire        dmem_read, dmem_write;
    wire [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    wire        dmem_ready;

    riscv_pipeline_core u_core (
        .clk            (clk),
        .rst            (rst),
        .dmem_read      (dmem_read),
        .dmem_write     (dmem_write),
        .dmem_addr      (dmem_addr),
        .dmem_wdata     (dmem_wdata),
        .dmem_rdata     (dmem_rdata),
        .dmem_ready     (dmem_ready),
        .out_pc         (out_pc),
        .out_alu_result (out_alu_result)
    );

    // ---- Avalon  <->  simple handshake bridge ----
    reg read_pending;   // read address accepted, awaiting readdatavalid

    wire addr_accepted = ~read_pending & ~avm_waitrequest;   // address phase accepted

    always @(posedge clk or posedge rst) begin
        if (rst)                                           read_pending <= 1'b0;
        else if (avm_readdatavalid)                        read_pending <= 1'b0;
        else if (dmem_read & addr_accepted)                read_pending <= 1'b1;
    end

    assign avm_address    = dmem_addr;
    assign avm_writedata  = dmem_wdata;
    assign avm_byteenable = 4'hf;
    assign avm_read       = dmem_read  & ~read_pending;  // drive only during address phase
    assign avm_write      = dmem_write & ~read_pending;

    assign dmem_rdata = avm_readdata;
    // ready to the core: reads complete on readdatavalid; writes on acceptance
    assign dmem_ready = (dmem_read  & avm_readdatavalid) |
                        (dmem_write & addr_accepted);

endmodule
