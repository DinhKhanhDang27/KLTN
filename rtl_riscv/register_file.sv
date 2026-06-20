// ============================================================================
// RISC-V 64-bit Register File
// 32 registers x 64-bit, x0 hardwired to 0
// 2 read ports, 1 write port
// ============================================================================
module register_file (
    input         clk,
    input         rst,
    input         reg_write,
    input  [4:0]  read_reg1,
    input  [4:0]  read_reg2,
    input  [4:0]  write_reg,
    input  [63:0] write_data,
    output [63:0] read_data1,
    output [63:0] read_data2
);

    reg [63:0] registers [0:31];
    integer i;

    // Read (combinational) - x0 always returns 0
    assign read_data1 = (read_reg1 == 5'd0) ? 64'd0 : registers[read_reg1];
    assign read_data2 = (read_reg2 == 5'd0) ? 64'd0 : registers[read_reg2];

    // Write (on falling edge to avoid hazards in single-cycle)
    always @(negedge clk or posedge rst) begin
        i = 0; // default assignment prevents latch inference on loop variable
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                registers[i] <= 64'd0;
        end else begin
            if (reg_write && write_reg != 5'd0)
                registers[write_reg] <= write_data;
        end
    end

endmodule
