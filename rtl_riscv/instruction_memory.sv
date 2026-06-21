// ============================================================================
// RISC-V Instruction Memory (ROM)
// Program: Simple Counter i++ (1 to 10)
// ============================================================================
module instruction_memory (
    input  [63:0] addr,
    output [31:0] instruction
);

    reg [31:0] mem [0:1023];
    integer i;

    assign instruction = mem[addr[11:2]];

    initial begin
// Dùng dấu gạch chéo xuôi (/) kể cả trên Windows
$readmemh("firmware.hex", mem);    end

endmodule
