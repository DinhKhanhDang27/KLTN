`timescale 1ns / 1ps
// ===========================================================================
// axi_ram
// ---------------------------------------------------------------------------
// Simple AXI4 (full) slave RAM, 32-bit data, byte-strobed writes, INCR bursts.
// Replaces the Altera on-chip memory / SDRAM Avalon slaves for a pure-RTL AXI
// system. Depth is parameterizable; optionally preloaded from a hex file.
//
// Single shared read/write FSM (the Forencich axi_interconnect keeps one
// outstanding transaction, so this is sufficient and race-free).
// ===========================================================================
module axi_ram #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter STRB_WIDTH = (DATA_WIDTH/8),
    parameter ID_WIDTH   = 8,
    parameter DEPTH      = 16384,            // number of 32-bit words (64 KB)
    parameter INIT_FILE  = ""                // optional $readmemh hex file
) (
    input  wire                   clk,
    input  wire                   reset_n,

    input  wire [ID_WIDTH-1:0]    s_axi_awid,
    input  wire [ADDR_WIDTH-1:0]  s_axi_awaddr,
    input  wire [7:0]             s_axi_awlen,
    input  wire [2:0]             s_axi_awsize,
    input  wire [1:0]             s_axi_awburst,
    input  wire                   s_axi_awvalid,
    output wire                   s_axi_awready,

    input  wire [DATA_WIDTH-1:0]  s_axi_wdata,
    input  wire [STRB_WIDTH-1:0]  s_axi_wstrb,
    input  wire                   s_axi_wlast,
    input  wire                   s_axi_wvalid,
    output wire                   s_axi_wready,

    output wire [ID_WIDTH-1:0]    s_axi_bid,
    output wire [1:0]             s_axi_bresp,
    output wire                   s_axi_bvalid,
    input  wire                   s_axi_bready,

    input  wire [ID_WIDTH-1:0]    s_axi_arid,
    input  wire [ADDR_WIDTH-1:0]  s_axi_araddr,
    input  wire [7:0]             s_axi_arlen,
    input  wire [2:0]             s_axi_arsize,
    input  wire [1:0]             s_axi_arburst,
    input  wire                   s_axi_arvalid,
    output wire                   s_axi_arready,

    output wire [ID_WIDTH-1:0]    s_axi_rid,
    output wire [DATA_WIDTH-1:0]  s_axi_rdata,
    output wire [1:0]             s_axi_rresp,
    output wire                   s_axi_rlast,
    output wire                   s_axi_rvalid,
    input  wire                   s_axi_rready
);

    localparam [1:0] RESP_OKAY = 2'b00;
    localparam AW = $clog2(DEPTH);

    reg [31:0] mem [0:DEPTH-1];

    initial begin
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, mem);
    end

    localparam [1:0] ST_IDLE  = 2'd0,
                     ST_WRITE = 2'd1,
                     ST_BRESP = 2'd2,
                     ST_READ  = 2'd3;

    reg [1:0]            state;
    reg [ID_WIDTH-1:0]   id_reg;
    reg [ADDR_WIDTH-1:0] addr_reg;
    reg [7:0]            len_reg;
    reg [DATA_WIDTH-1:0] rdata_reg;

    wire [AW-1:0] word_idx    = addr_reg[AW+1:2];
    wire [AW-1:0] ar_word_idx = s_axi_araddr[AW+1:2];

    assign s_axi_awready = (state == ST_IDLE);
    assign s_axi_arready = (state == ST_IDLE) && !s_axi_awvalid; // write priority
    assign s_axi_wready  = (state == ST_WRITE);

    assign s_axi_bid     = id_reg;
    assign s_axi_bresp   = RESP_OKAY;
    assign s_axi_bvalid  = (state == ST_BRESP);

    assign s_axi_rid     = id_reg;
    assign s_axi_rdata   = rdata_reg;
    assign s_axi_rresp   = RESP_OKAY;
    assign s_axi_rlast   = (state == ST_READ) && (len_reg == 8'd0);
    assign s_axi_rvalid  = (state == ST_READ);

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state     <= ST_IDLE;
            id_reg    <= {ID_WIDTH{1'b0}};
            addr_reg  <= {ADDR_WIDTH{1'b0}};
            len_reg   <= 8'd0;
            rdata_reg <= 32'd0;
        end else begin
            case (state)
                ST_IDLE: begin
                    if (s_axi_awvalid) begin
                        id_reg   <= s_axi_awid;
                        addr_reg <= s_axi_awaddr;
                        len_reg  <= s_axi_awlen;
                        state    <= ST_WRITE;
                    end else if (s_axi_arvalid) begin
                        id_reg    <= s_axi_arid;
                        addr_reg  <= s_axi_araddr;
                        len_reg   <= s_axi_arlen;
                        rdata_reg <= mem[ar_word_idx];
                        state     <= ST_READ;
                    end
                end

                ST_WRITE: begin
                    if (s_axi_wvalid) begin
                        if (s_axi_wstrb[0]) mem[word_idx][7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) mem[word_idx][15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) mem[word_idx][23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) mem[word_idx][31:24] <= s_axi_wdata[31:24];
                        addr_reg <= addr_reg + 32'd4;
                        if (s_axi_wlast)
                            state <= ST_BRESP;
                    end
                end

                ST_BRESP: begin
                    if (s_axi_bready)
                        state <= ST_IDLE;
                end

                ST_READ: begin
                    if (s_axi_rready) begin
                        if (len_reg == 8'd0) begin
                            state <= ST_IDLE;
                        end else begin
                            len_reg   <= len_reg - 8'd1;
                            addr_reg  <= addr_reg + 32'd4;
                            rdata_reg <= mem[addr_reg[AW+1:2] + 1'b1];
                        end
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
