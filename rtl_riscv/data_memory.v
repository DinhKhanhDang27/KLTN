// ============================================================================
// RISC-V 64-bit Data Memory
// 256 doublewords (2048 bytes)
// Supports: LD (load doubleword), SD (store doubleword)
// ============================================================================
module data_memory (
    input         clk,
    input         mem_read,
    input         mem_write,
    input  [63:0] addr,
    input  [63:0] write_data,
    output [63:0] read_data
);

    reg [7:0] mem [0:2047]; // Byte-addressable memory
    wire [63:0] aligned_addr;
    assign aligned_addr = {addr[63:3], 3'b000}; // 8-byte aligned

    // Read (combinational) - Load doubleword (little-endian)
    assign read_data = mem_read ? {
        mem[aligned_addr[10:0] + 11'd7],
        mem[aligned_addr[10:0] + 11'd6],
        mem[aligned_addr[10:0] + 11'd5],
        mem[aligned_addr[10:0] + 11'd4],
        mem[aligned_addr[10:0] + 11'd3],
        mem[aligned_addr[10:0] + 11'd2],
        mem[aligned_addr[10:0] + 11'd1],
        mem[aligned_addr[10:0]]
    } : 64'd0;

    // Write (synchronous) - Store doubleword (little-endian)
    always @(posedge clk) begin
        if (mem_write) begin
            mem[aligned_addr[10:0]]         <= write_data[7:0];
            mem[aligned_addr[10:0] + 11'd1] <= write_data[15:8];
            mem[aligned_addr[10:0] + 11'd2] <= write_data[23:16];
            mem[aligned_addr[10:0] + 11'd3] <= write_data[31:24];
            mem[aligned_addr[10:0] + 11'd4] <= write_data[39:32];
            mem[aligned_addr[10:0] + 11'd5] <= write_data[47:40];
            mem[aligned_addr[10:0] + 11'd6] <= write_data[55:48];
            mem[aligned_addr[10:0] + 11'd7] <= write_data[63:56];
        end
    end

    // Initialize memory to 0
    integer i;
    initial begin
        for (i = 0; i < 2048; i = i + 1)
            mem[i] = 8'd0;
    end

endmodule
