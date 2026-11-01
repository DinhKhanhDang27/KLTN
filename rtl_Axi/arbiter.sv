`timescale 1ns / 1ps
// ===========================================================================
// arbiter
// ---------------------------------------------------------------------------
// Round-robin / fixed-priority bus arbiter with optional request blocking.
// Drop-in replacement for the Forencich-style `arbiter` that axi_interconnect
// (axi_4_full.sv) instantiates. Implements the configuration actually used by
// the interconnect: ARB_TYPE_ROUND_ROBIN=1, ARB_BLOCK=1, ARB_BLOCK_ACK=1,
// ARB_LSB_HIGH_PRIORITY=1 (lower port index = higher priority within a round).
//
//   - grant is one-hot, registered.
//   - grant_encoded is the binary index of the granted port.
//   - When ARB_BLOCK/ARB_BLOCK_ACK are set, a grant is held until the matching
//     acknowledge bit is seen, then arbitration advances round-robin.
// ===========================================================================
module arbiter #(
    parameter PORTS = 4,
    parameter ARB_TYPE_ROUND_ROBIN = 0,
    parameter ARB_BLOCK = 0,
    parameter ARB_BLOCK_ACK = 0,
    parameter ARB_LSB_HIGH_PRIORITY = 0,
    parameter CL_PORTS = (PORTS > 1) ? $clog2(PORTS) : 1
) (
    input  wire                 clk,
    input  wire                 rst,
    input  wire [PORTS-1:0]     request,
    input  wire [PORTS-1:0]     acknowledge,
    output reg  [PORTS-1:0]     grant,
    output reg                  grant_valid,
    output reg  [CL_PORTS-1:0]  grant_encoded
);

    // Starting (highest-priority) index for the next arbitration round.
    reg [CL_PORTS-1:0] rr_base;

    // -------- combinational selection --------
    reg [PORTS-1:0]    sel_grant;
    reg                sel_valid;
    reg [CL_PORTS-1:0] sel_enc;
    integer            j;
    integer            ix;

    always @* begin
        sel_grant = {PORTS{1'b0}};
        sel_valid = 1'b0;
        sel_enc   = {CL_PORTS{1'b0}};
        // Iterate from lowest priority (offset PORTS-1) down to highest (0)
        // so the highest-priority requester wins (last assignment sticks).
        for (j = PORTS-1; j >= 0; j = j - 1) begin
            ix = ARB_TYPE_ROUND_ROBIN ? (rr_base + j) : j;
            if (ix >= PORTS)
                ix = ix - PORTS;
            if (request[ix]) begin
                sel_valid     = 1'b1;
                sel_enc       = ix[CL_PORTS-1:0];   // low bits = port index
                sel_grant     = {PORTS{1'b0}};
                sel_grant[ix] = 1'b1;
            end
        end
    end

    wire ack_current = |(grant & acknowledge);
    wire hold = grant_valid && ARB_BLOCK &&
                (ARB_BLOCK_ACK ? !ack_current : |(grant & request));

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            grant         <= {PORTS{1'b0}};
            grant_valid   <= 1'b0;
            grant_encoded <= {CL_PORTS{1'b0}};
            rr_base       <= {CL_PORTS{1'b0}};
        end else begin
            if (hold) begin
                // keep the current grant asserted until it is acknowledged
            end else begin
                grant         <= sel_grant;
                grant_valid   <= sel_valid;
                grant_encoded <= sel_enc;
                if (sel_valid)
                    rr_base <= ARB_TYPE_ROUND_ROBIN ? (sel_enc + 1'b1)
                                                    : {CL_PORTS{1'b0}};
            end
        end
    end

endmodule
