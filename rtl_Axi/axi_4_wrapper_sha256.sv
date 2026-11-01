`timescale 1ns / 1ps
// ===========================================================================
// axi_4_wrapper_sha256
// ---------------------------------------------------------------------------
// AXI4 (full) slave wrapper for the SHA-256 core.
//
// This replaces the Avalon-MM slave (sha256_avalon_wrapper). The register map
// is kept byte-compatible with the Avalon version so existing firmware keeps
// working -- only the base address decoding changes (now done by the AXI
// interconnect instead of Platform Designer):
//
//   byte offset   word idx   meaning
//   0x00..0x3C    0..15      block words 0..15  (512-bit message block)
//   0x40          16         control {irq_en[2], init[1], start[0]}
//   0x44          17         status  {irq_pending[2], done[1], ready[0]}
//   0x48..0x64    18..25     digest words 0..7  (read-only)
//   write 1 to status bit[2] (word 17) to clear irq_pending.
//
// The slave handles single-beat and INCR-burst AXI4 transactions. Because the
// Forencich axi_interconnect keeps a single outstanding transaction, a single
// shared read/write FSM is sufficient and avoids AW/AR race conditions.
// ===========================================================================
module axi_4_wrapper_sha256 #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter STRB_WIDTH = (DATA_WIDTH/8),
    parameter ID_WIDTH   = 8
) (
    input  wire                   clk,
    input  wire                   reset_n,      // active-low

    // ---- AXI4 slave: write address channel (AW) ----
    input  wire [ID_WIDTH-1:0]    s_axi_awid,
    input  wire [ADDR_WIDTH-1:0]  s_axi_awaddr,
    input  wire [7:0]             s_axi_awlen,
    input  wire [2:0]             s_axi_awsize,
    input  wire [1:0]             s_axi_awburst,
    input  wire                   s_axi_awvalid,
    output wire                   s_axi_awready,

    // ---- AXI4 slave: write data channel (W) ----
    input  wire [DATA_WIDTH-1:0]  s_axi_wdata,
    input  wire [STRB_WIDTH-1:0]  s_axi_wstrb,
    input  wire                   s_axi_wlast,
    input  wire                   s_axi_wvalid,
    output wire                   s_axi_wready,

    // ---- AXI4 slave: write response channel (B) ----
    output wire [ID_WIDTH-1:0]    s_axi_bid,
    output wire [1:0]             s_axi_bresp,
    output wire                   s_axi_bvalid,
    input  wire                   s_axi_bready,

    // ---- AXI4 slave: read address channel (AR) ----
    input  wire [ID_WIDTH-1:0]    s_axi_arid,
    input  wire [ADDR_WIDTH-1:0]  s_axi_araddr,
    input  wire [7:0]             s_axi_arlen,
    input  wire [2:0]             s_axi_arsize,
    input  wire [1:0]             s_axi_arburst,
    input  wire                   s_axi_arvalid,
    output wire                   s_axi_arready,

    // ---- AXI4 slave: read data channel (R) ----
    output wire [ID_WIDTH-1:0]    s_axi_rid,
    output wire [DATA_WIDTH-1:0]  s_axi_rdata,
    output wire [1:0]             s_axi_rresp,
    output wire                   s_axi_rlast,
    output wire                   s_axi_rvalid,
    input  wire                   s_axi_rready,

    // ---- interrupt ----
    output wire                   irq
);

    localparam [1:0] RESP_OKAY = 2'b00;

    // -------------------- SHA-256 register file --------------------
    reg [31:0] data_in_regs [0:15];
    reg        start_reg;
    reg        init_reg;
    reg        irq_enable;
    reg        irq_pending;

    wire [511:0] block_in;
    wire [255:0] hash_out;
    wire         ready;
    wire         hash_valid;
    reg          hash_valid_d;

    genvar gi;
    generate
        for (gi = 0; gi < 16; gi = gi + 1) begin : gen_block_in
            assign block_in[(15 - gi) * 32 +: 32] = data_in_regs[gi];
        end
    endgenerate

    sha256_core u_sha256_core (
        .clk        (clk),
        .rst_n      (reset_n),
        .start      (start_reg),
        .init       (init_reg),
        .block_in   (block_in),
        .ready      (ready),
        .hash_valid (hash_valid),
        .hash_out   (hash_out)
    );

    // -------------------- AXI slave FSM --------------------
    localparam [1:0] ST_IDLE  = 2'd0,
                     ST_WRITE = 2'd1,
                     ST_BRESP = 2'd2,
                     ST_READ  = 2'd3;

    reg [1:0]            state;
    reg [ID_WIDTH-1:0]   id_reg;
    reg [ADDR_WIDTH-1:0] addr_reg;   // byte address of current beat
    reg [7:0]            len_reg;    // remaining beats - 1
    reg [DATA_WIDTH-1:0] rdata_reg;

    wire [4:0] word_idx = addr_reg[6:2];   // 32 word registers

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

    // Combinational register read (word_idx -> rdata_reg source)
    function [31:0] reg_read;
        input [4:0] idx;
        begin
            reg_read = 32'd0;
            if (idx <= 5'd15) begin
                reg_read = data_in_regs[idx];
            end else if (idx == 5'd16) begin
                reg_read = {29'd0, irq_enable, init_reg, 1'b0};
            end else if (idx == 5'd17) begin
                reg_read = {29'd0, irq_pending, (hash_valid | irq_pending), ready};
            end else begin
                case (idx)
                    5'd18: reg_read = hash_out[255:224];
                    5'd19: reg_read = hash_out[223:192];
                    5'd20: reg_read = hash_out[191:160];
                    5'd21: reg_read = hash_out[159:128];
                    5'd22: reg_read = hash_out[127:96];
                    5'd23: reg_read = hash_out[95:64];
                    5'd24: reg_read = hash_out[63:32];
                    5'd25: reg_read = hash_out[31:0];
                    default: reg_read = 32'd0;
                endcase
            end
        end
    endfunction

    integer k;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state        <= ST_IDLE;
            id_reg       <= {ID_WIDTH{1'b0}};
            addr_reg     <= {ADDR_WIDTH{1'b0}};
            len_reg      <= 8'd0;
            rdata_reg    <= 32'd0;
            for (k = 0; k < 16; k = k + 1)
                data_in_regs[k] <= 32'd0;
            start_reg    <= 1'b0;
            init_reg     <= 1'b1;
            irq_enable   <= 1'b0;
            irq_pending  <= 1'b0;
            hash_valid_d <= 1'b0;
        end else begin
            // start is a one-cycle pulse; default low each cycle
            start_reg    <= 1'b0;
            hash_valid_d <= hash_valid;

            // rising edge of hash_valid latches an interrupt request
            if (hash_valid & ~hash_valid_d)
                irq_pending <= 1'b1;

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
                        rdata_reg <= reg_read(s_axi_araddr[6:2]);
                        state     <= ST_READ;
                    end
                end

                ST_WRITE: begin
                    if (s_axi_wvalid) begin
                        // ----- register write with byte strobes -----
                        if (word_idx <= 5'd15) begin
                            if (s_axi_wstrb[0]) data_in_regs[word_idx][7:0]   <= s_axi_wdata[7:0];
                            if (s_axi_wstrb[1]) data_in_regs[word_idx][15:8]  <= s_axi_wdata[15:8];
                            if (s_axi_wstrb[2]) data_in_regs[word_idx][23:16] <= s_axi_wdata[23:16];
                            if (s_axi_wstrb[3]) data_in_regs[word_idx][31:24] <= s_axi_wdata[31:24];
                        end else if (word_idx == 5'd16) begin
                            if (s_axi_wstrb[0]) begin
                                start_reg  <= s_axi_wdata[0] & ready;
                                init_reg   <= s_axi_wdata[1];
                                irq_enable <= s_axi_wdata[2];
                            end
                        end else if (word_idx == 5'd17) begin
                            if (s_axi_wstrb[0] && s_axi_wdata[2])
                                irq_pending <= 1'b0;
                        end
                        // INCR burst: advance to next word for the next beat
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
                            rdata_reg <= reg_read(addr_reg[6:2] + 5'd1);
                        end
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

    assign irq = irq_enable & irq_pending;

endmodule
