module adder (
    input  [63:0] a,
    input  [63:0] b,
    output [63:0] result
);

    assign result = a + b;

endmodule
