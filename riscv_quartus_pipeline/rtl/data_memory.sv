// ============================================================================
// RISC-V 32-bit Data Memory
// 512 words (2048 bytes)
// Supports: LW (load word), SW (store word)
// ============================================================================
module data_memory (
    input         clk,
    input         mem_read,
    input         mem_write,
    input  [31:0] addr,
    input  [31:0] write_data,
    output [31:0] read_data
);

    reg [7:0] mem [0:2047]; // Byte-addressable memory
    wire [31:0] aligned_addr;
    assign aligned_addr = {addr[31:2], 2'b00}; // 4-byte aligned

    // Read (combinational) - Load word (little-endian)
    assign read_data = mem_read ? {
        mem[aligned_addr[10:0] + 11'd3],
        mem[aligned_addr[10:0] + 11'd2],
        mem[aligned_addr[10:0] + 11'd1],
        mem[aligned_addr[10:0]]
    } : 32'd0;

    // Write (synchronous) - Store word (little-endian)
    always @(posedge clk) begin
        if (mem_write) begin
            mem[aligned_addr[10:0]]         <= write_data[7:0];
            mem[aligned_addr[10:0] + 11'd1] <= write_data[15:8];
            mem[aligned_addr[10:0] + 11'd2] <= write_data[23:16];
            mem[aligned_addr[10:0] + 11'd3] <= write_data[31:24];
        end
    end

    // Initialize memory to 0
    integer i;
    initial begin
        for (i = 0; i < 2048; i = i + 1)
            mem[i] = 8'd0;
    end

endmodule
