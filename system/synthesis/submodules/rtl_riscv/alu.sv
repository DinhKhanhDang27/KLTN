module alu (
    input  [63:0] a,
    input  [63:0] b,
    input  [3:0]  alu_control,
    output reg [63:0] result,
    output        zero
);

    assign zero = (result == 64'd0);

    always @(*) begin
        case (alu_control)
            4'b0000: result = a & b;            // AND
            4'b0001: result = a | b;            // OR
            4'b0010: result = a + b;            // ADD
            4'b0110: result = a - b;            // SUB
            4'b0011: result = a ^ b;            // XOR
            4'b0100: result = a << b[5:0];      // SLL (Shift Left Logical)
            4'b0101: result = a >> b[5:0];      // SRL (Shift Right Logical)
            4'b0111: result = $signed(a) >>> b[5:0]; // SRA (Shift Right Arithmetic)
            4'b1000: result = ($signed(a) < $signed(b)) ? 64'd1 : 64'd0; // SLT
            4'b1001: result = (a < b) ? 64'd1 : 64'd0; // SLTU
            default: result = 64'd0;
        endcase
    end

endmodule
