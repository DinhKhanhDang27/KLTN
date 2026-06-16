module pc_register (
    input         clk,
    input         rst,
    input  [63:0] pc_in,
    output reg [63:0] pc_out
);

    always @(posedge clk or posedge rst) begin
        if (rst)
            pc_out <= 64'd0;
        else
            pc_out <= pc_in;
    end

endmodule
