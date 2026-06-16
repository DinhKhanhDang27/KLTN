// ============================================================================
// 2-to-1 MUX (64-bit)
// ============================================================================
module mux2to1 (
    input  [63:0] in0,
    input  [63:0] in1,
    input         sel,
    output [63:0] out
);

    assign out = sel ? in1 : in0;

endmodule

// ============================================================================
// 4-to-1 MUX (64-bit)
// ============================================================================
module mux4to1 (
    input  [63:0] in0,
    input  [63:0] in1,
    input  [63:0] in2,
    input  [63:0] in3,
    input  [1:0]  sel,
    output reg [63:0] out
);

    always @(*) begin
        case (sel)
            2'b00: out = in0;
            2'b01: out = in1;
            2'b10: out = in2;
            2'b11: out = in3;
            default: out = in0;
        endcase
    end

endmodule
