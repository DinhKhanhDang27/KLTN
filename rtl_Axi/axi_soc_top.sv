`timescale 1ns / 1ps
// ===========================================================================
// axi_soc_top
// ---------------------------------------------------------------------------
// Pure-RTL AXI4 SoC: RISC-V master -> axi_interconnect -> { RAM, SHA-256 }.
// This mirrors the current Avalon SoC but on the AXI4 Full backbone.
//
// Address map (configurable via M_BASE_ADDR / M_ADDR_WIDTH):
//   M0  RAM   base 0x0000_0000  size 64 KB  (data memory, replaces onchip/SDRAM)
//   M1  SHA   base 0x0200_8000  size  4 KB  (register map, replaces Avalon SHA)
//
// UART / timer are NOT included here; for those keep Platform Designer (it
// auto-bridges AXI<->Avalon) or add AXI versions / AXI-to-Avalon bridges.
// See the integration guide.
// ===========================================================================
module axi_soc_top (
    input  wire        clk,
    input  wire        reset_n,

    output wire        sha_irq,
    output wire [31:0] out_pc,
    output wire [31:0] out_alu_result
);

    localparam ID_WIDTH   = 8;
    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 32;
    localparam STRB_WIDTH = DATA_WIDTH/8;
    localparam S_COUNT    = 1;   // one master (CPU)
    localparam M_COUNT    = 2;   // two slaves (RAM, SHA)

    wire rst = ~reset_n;         // interconnect uses active-high reset

    // =====================================================================
    // Master side (CPU -> interconnect S0)
    // =====================================================================
    wire [ID_WIDTH-1:0]   cpu_awid;
    wire [ADDR_WIDTH-1:0] cpu_awaddr;
    wire [7:0]            cpu_awlen;
    wire [2:0]            cpu_awsize;
    wire [1:0]            cpu_awburst;
    wire                  cpu_awlock;
    wire [3:0]            cpu_awcache;
    wire [2:0]            cpu_awprot;
    wire [3:0]            cpu_awqos;
    wire                  cpu_awvalid, cpu_awready;
    wire [DATA_WIDTH-1:0] cpu_wdata;
    wire [STRB_WIDTH-1:0] cpu_wstrb;
    wire                  cpu_wlast, cpu_wvalid, cpu_wready;
    wire [ID_WIDTH-1:0]   cpu_bid;
    wire [1:0]            cpu_bresp;
    wire                  cpu_bvalid, cpu_bready;
    wire [ID_WIDTH-1:0]   cpu_arid;
    wire [ADDR_WIDTH-1:0] cpu_araddr;
    wire [7:0]            cpu_arlen;
    wire [2:0]            cpu_arsize;
    wire [1:0]            cpu_arburst;
    wire                  cpu_arlock;
    wire [3:0]            cpu_arcache;
    wire [2:0]            cpu_arprot;
    wire [3:0]            cpu_arqos;
    wire                  cpu_arvalid, cpu_arready;
    wire [ID_WIDTH-1:0]   cpu_rid;
    wire [DATA_WIDTH-1:0] cpu_rdata;
    wire [1:0]            cpu_rresp;
    wire                  cpu_rlast, cpu_rvalid, cpu_rready;

    axi_4_wrapper_riscv #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .ID_WIDTH(ID_WIDTH)
    ) u_cpu (
        .clk(clk), .reset_n(reset_n),
        .m_axi_awid(cpu_awid), .m_axi_awaddr(cpu_awaddr), .m_axi_awlen(cpu_awlen),
        .m_axi_awsize(cpu_awsize), .m_axi_awburst(cpu_awburst), .m_axi_awlock(cpu_awlock),
        .m_axi_awcache(cpu_awcache), .m_axi_awprot(cpu_awprot), .m_axi_awqos(cpu_awqos),
        .m_axi_awvalid(cpu_awvalid), .m_axi_awready(cpu_awready),
        .m_axi_wdata(cpu_wdata), .m_axi_wstrb(cpu_wstrb), .m_axi_wlast(cpu_wlast),
        .m_axi_wvalid(cpu_wvalid), .m_axi_wready(cpu_wready),
        .m_axi_bid(cpu_bid), .m_axi_bresp(cpu_bresp), .m_axi_bvalid(cpu_bvalid),
        .m_axi_bready(cpu_bready),
        .m_axi_arid(cpu_arid), .m_axi_araddr(cpu_araddr), .m_axi_arlen(cpu_arlen),
        .m_axi_arsize(cpu_arsize), .m_axi_arburst(cpu_arburst), .m_axi_arlock(cpu_arlock),
        .m_axi_arcache(cpu_arcache), .m_axi_arprot(cpu_arprot), .m_axi_arqos(cpu_arqos),
        .m_axi_arvalid(cpu_arvalid), .m_axi_arready(cpu_arready),
        .m_axi_rid(cpu_rid), .m_axi_rdata(cpu_rdata), .m_axi_rresp(cpu_rresp),
        .m_axi_rlast(cpu_rlast), .m_axi_rvalid(cpu_rvalid), .m_axi_rready(cpu_rready),
        .out_pc(out_pc), .out_alu_result(out_alu_result)
    );

    // =====================================================================
    // Slave-side packed buses (interconnect M -> slaves)
    // =====================================================================
    wire [M_COUNT*ID_WIDTH-1:0]   m_awid;
    wire [M_COUNT*ADDR_WIDTH-1:0] m_awaddr;
    wire [M_COUNT*8-1:0]          m_awlen;
    wire [M_COUNT*3-1:0]          m_awsize;
    wire [M_COUNT*2-1:0]          m_awburst;
    wire [M_COUNT-1:0]            m_awlock;
    wire [M_COUNT*4-1:0]          m_awcache;
    wire [M_COUNT*3-1:0]          m_awprot;
    wire [M_COUNT*4-1:0]          m_awqos;
    wire [M_COUNT*4-1:0]          m_awregion;
    wire [M_COUNT-1:0]            m_awvalid, m_awready;
    wire [M_COUNT*DATA_WIDTH-1:0] m_wdata;
    wire [M_COUNT*STRB_WIDTH-1:0] m_wstrb;
    wire [M_COUNT-1:0]            m_wlast, m_wvalid, m_wready;
    wire [M_COUNT*ID_WIDTH-1:0]   m_bid;
    wire [M_COUNT*2-1:0]          m_bresp;
    wire [M_COUNT-1:0]            m_bvalid, m_bready;
    wire [M_COUNT*ID_WIDTH-1:0]   m_arid;
    wire [M_COUNT*ADDR_WIDTH-1:0] m_araddr;
    wire [M_COUNT*8-1:0]          m_arlen;
    wire [M_COUNT*3-1:0]          m_arsize;
    wire [M_COUNT*2-1:0]          m_arburst;
    wire [M_COUNT-1:0]            m_arlock;
    wire [M_COUNT*4-1:0]          m_arcache;
    wire [M_COUNT*3-1:0]          m_arprot;
    wire [M_COUNT*4-1:0]          m_arqos;
    wire [M_COUNT*4-1:0]          m_arregion;
    wire [M_COUNT-1:0]            m_arvalid, m_arready;
    wire [M_COUNT*ID_WIDTH-1:0]   m_rid;
    wire [M_COUNT*DATA_WIDTH-1:0] m_rdata;
    wire [M_COUNT*2-1:0]          m_rresp;
    wire [M_COUNT-1:0]            m_rlast, m_rvalid, m_rready;

    // =====================================================================
    // Interconnect
    //   M0 = RAM @ 0x0000_0000 (width 16 -> 64 KB)
    //   M1 = SHA @ 0x0200_8000 (width 12 ->  4 KB)
    // =====================================================================
    axi_interconnect #(
        .S_COUNT(S_COUNT), .M_COUNT(M_COUNT),
        .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .ID_WIDTH(ID_WIDTH),
        .M_BASE_ADDR({32'h0200_8000, 32'h0000_0000}),
        .M_ADDR_WIDTH({32'd12,       32'd16})
    ) u_interconnect (
        .clk(clk), .rst(rst),
        // ---- slave interfaces (from CPU) ----
        .s_axi_awid(cpu_awid), .s_axi_awaddr(cpu_awaddr), .s_axi_awlen(cpu_awlen),
        .s_axi_awsize(cpu_awsize), .s_axi_awburst(cpu_awburst), .s_axi_awlock(cpu_awlock),
        .s_axi_awcache(cpu_awcache), .s_axi_awprot(cpu_awprot), .s_axi_awqos(cpu_awqos),
        .s_axi_awuser(1'b0), .s_axi_awvalid(cpu_awvalid), .s_axi_awready(cpu_awready),
        .s_axi_wdata(cpu_wdata), .s_axi_wstrb(cpu_wstrb), .s_axi_wlast(cpu_wlast),
        .s_axi_wuser(1'b0), .s_axi_wvalid(cpu_wvalid), .s_axi_wready(cpu_wready),
        .s_axi_bid(cpu_bid), .s_axi_bresp(cpu_bresp), .s_axi_buser(), .s_axi_bvalid(cpu_bvalid),
        .s_axi_bready(cpu_bready),
        .s_axi_arid(cpu_arid), .s_axi_araddr(cpu_araddr), .s_axi_arlen(cpu_arlen),
        .s_axi_arsize(cpu_arsize), .s_axi_arburst(cpu_arburst), .s_axi_arlock(cpu_arlock),
        .s_axi_arcache(cpu_arcache), .s_axi_arprot(cpu_arprot), .s_axi_arqos(cpu_arqos),
        .s_axi_aruser(1'b0), .s_axi_arvalid(cpu_arvalid), .s_axi_arready(cpu_arready),
        .s_axi_rid(cpu_rid), .s_axi_rdata(cpu_rdata), .s_axi_rresp(cpu_rresp),
        .s_axi_rlast(cpu_rlast), .s_axi_ruser(), .s_axi_rvalid(cpu_rvalid), .s_axi_rready(cpu_rready),
        // ---- master interfaces (to slaves) ----
        .m_axi_awid(m_awid), .m_axi_awaddr(m_awaddr), .m_axi_awlen(m_awlen),
        .m_axi_awsize(m_awsize), .m_axi_awburst(m_awburst), .m_axi_awlock(m_awlock),
        .m_axi_awcache(m_awcache), .m_axi_awprot(m_awprot), .m_axi_awqos(m_awqos),
        .m_axi_awregion(m_awregion), .m_axi_awuser(), .m_axi_awvalid(m_awvalid), .m_axi_awready(m_awready),
        .m_axi_wdata(m_wdata), .m_axi_wstrb(m_wstrb), .m_axi_wlast(m_wlast),
        .m_axi_wuser(), .m_axi_wvalid(m_wvalid), .m_axi_wready(m_wready),
        .m_axi_bid(m_bid), .m_axi_bresp(m_bresp), .m_axi_buser({M_COUNT{1'b0}}),
        .m_axi_bvalid(m_bvalid), .m_axi_bready(m_bready),
        .m_axi_arid(m_arid), .m_axi_araddr(m_araddr), .m_axi_arlen(m_arlen),
        .m_axi_arsize(m_arsize), .m_axi_arburst(m_arburst), .m_axi_arlock(m_arlock),
        .m_axi_arcache(m_arcache), .m_axi_arprot(m_arprot), .m_axi_arqos(m_arqos),
        .m_axi_arregion(m_arregion), .m_axi_aruser(), .m_axi_arvalid(m_arvalid), .m_axi_arready(m_arready),
        .m_axi_rid(m_rid), .m_axi_rdata(m_rdata), .m_axi_rresp(m_rresp),
        .m_axi_rlast(m_rlast), .m_axi_ruser({M_COUNT{1'b0}}), .m_axi_rvalid(m_rvalid), .m_axi_rready(m_rready)
    );

    // =====================================================================
    // M0: RAM (data memory)
    // =====================================================================
    axi_ram #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .ID_WIDTH(ID_WIDTH),
        .DEPTH(16384), .INIT_FILE("")
    ) u_ram (
        .clk(clk), .reset_n(reset_n),
        .s_axi_awid(m_awid[0*ID_WIDTH +: ID_WIDTH]), .s_axi_awaddr(m_awaddr[0*ADDR_WIDTH +: ADDR_WIDTH]),
        .s_axi_awlen(m_awlen[0*8 +: 8]), .s_axi_awsize(m_awsize[0*3 +: 3]), .s_axi_awburst(m_awburst[0*2 +: 2]),
        .s_axi_awvalid(m_awvalid[0]), .s_axi_awready(m_awready[0]),
        .s_axi_wdata(m_wdata[0*DATA_WIDTH +: DATA_WIDTH]), .s_axi_wstrb(m_wstrb[0*STRB_WIDTH +: STRB_WIDTH]),
        .s_axi_wlast(m_wlast[0]), .s_axi_wvalid(m_wvalid[0]), .s_axi_wready(m_wready[0]),
        .s_axi_bid(m_bid[0*ID_WIDTH +: ID_WIDTH]), .s_axi_bresp(m_bresp[0*2 +: 2]),
        .s_axi_bvalid(m_bvalid[0]), .s_axi_bready(m_bready[0]),
        .s_axi_arid(m_arid[0*ID_WIDTH +: ID_WIDTH]), .s_axi_araddr(m_araddr[0*ADDR_WIDTH +: ADDR_WIDTH]),
        .s_axi_arlen(m_arlen[0*8 +: 8]), .s_axi_arsize(m_arsize[0*3 +: 3]), .s_axi_arburst(m_arburst[0*2 +: 2]),
        .s_axi_arvalid(m_arvalid[0]), .s_axi_arready(m_arready[0]),
        .s_axi_rid(m_rid[0*ID_WIDTH +: ID_WIDTH]), .s_axi_rdata(m_rdata[0*DATA_WIDTH +: DATA_WIDTH]),
        .s_axi_rresp(m_rresp[0*2 +: 2]), .s_axi_rlast(m_rlast[0]),
        .s_axi_rvalid(m_rvalid[0]), .s_axi_rready(m_rready[0])
    );

    // =====================================================================
    // M1: SHA-256
    // =====================================================================
    axi_4_wrapper_sha256 #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .ID_WIDTH(ID_WIDTH)
    ) u_sha (
        .clk(clk), .reset_n(reset_n),
        .s_axi_awid(m_awid[1*ID_WIDTH +: ID_WIDTH]), .s_axi_awaddr(m_awaddr[1*ADDR_WIDTH +: ADDR_WIDTH]),
        .s_axi_awlen(m_awlen[1*8 +: 8]), .s_axi_awsize(m_awsize[1*3 +: 3]), .s_axi_awburst(m_awburst[1*2 +: 2]),
        .s_axi_awvalid(m_awvalid[1]), .s_axi_awready(m_awready[1]),
        .s_axi_wdata(m_wdata[1*DATA_WIDTH +: DATA_WIDTH]), .s_axi_wstrb(m_wstrb[1*STRB_WIDTH +: STRB_WIDTH]),
        .s_axi_wlast(m_wlast[1]), .s_axi_wvalid(m_wvalid[1]), .s_axi_wready(m_wready[1]),
        .s_axi_bid(m_bid[1*ID_WIDTH +: ID_WIDTH]), .s_axi_bresp(m_bresp[1*2 +: 2]),
        .s_axi_bvalid(m_bvalid[1]), .s_axi_bready(m_bready[1]),
        .s_axi_arid(m_arid[1*ID_WIDTH +: ID_WIDTH]), .s_axi_araddr(m_araddr[1*ADDR_WIDTH +: ADDR_WIDTH]),
        .s_axi_arlen(m_arlen[1*8 +: 8]), .s_axi_arsize(m_arsize[1*3 +: 3]), .s_axi_arburst(m_arburst[1*2 +: 2]),
        .s_axi_arvalid(m_arvalid[1]), .s_axi_arready(m_arready[1]),
        .s_axi_rid(m_rid[1*ID_WIDTH +: ID_WIDTH]), .s_axi_rdata(m_rdata[1*DATA_WIDTH +: DATA_WIDTH]),
        .s_axi_rresp(m_rresp[1*2 +: 2]), .s_axi_rlast(m_rlast[1]),
        .s_axi_rvalid(m_rvalid[1]), .s_axi_rready(m_rready[1]),
        .irq(sha_irq)
    );

endmodule
