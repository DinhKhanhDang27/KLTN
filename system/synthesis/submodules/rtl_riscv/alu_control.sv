// ============================================================================
// RISC-V ALU Control Unit
// Generates ALU operation code from ALUOp + funct7 + funct3
// ============================================================================
module alu_control (
    input  [1:0] alu_op,
    input  [2:0] funct3,
    input  [6:0] funct7,
    output reg [3:0] alu_control_out
);

    always @(*) begin
        case (alu_op)
            // Load/Store: ADD for address calculation
            2'b00: alu_control_out = 4'b0010; // ADD

            // Branch: SUB for comparison
            2'b01: begin
                case (funct3)
                    3'b000: alu_control_out = 4'b0110; // BEQ  -> SUB
                    3'b001: alu_control_out = 4'b0110; // BNE  -> SUB
                    3'b100: alu_control_out = 4'b1000; // BLT  -> SLT
                    3'b101: alu_control_out = 4'b1000; // BGE  -> SLT
                    3'b110: alu_control_out = 4'b1001; // BLTU -> SLTU
                    3'b111: alu_control_out = 4'b1001; // BGEU -> SLTU
                    default: alu_control_out = 4'b0110; // SUB
                endcase
            end

            // R-type
            2'b10: begin
                case (funct3)
                    3'b000: alu_control_out = (funct7[5]) ? 4'b0110 : 4'b0010; // SUB/ADD
                    3'b001: alu_control_out = 4'b0100; // SLL
                    3'b010: alu_control_out = 4'b1000; // SLT
                    3'b011: alu_control_out = 4'b1001; // SLTU
                    3'b100: alu_control_out = 4'b0011; // XOR
                    3'b101: alu_control_out = (funct7[5]) ? 4'b0111 : 4'b0101; // SRA/SRL
                    3'b110: alu_control_out = 4'b0001; // OR
                    3'b111: alu_control_out = 4'b0000; // AND
                    default: alu_control_out = 4'b0010;
                endcase
            end

            // I-type ALU
            2'b11: begin
                case (funct3)
                    3'b000: alu_control_out = 4'b0010; // ADDI
                    3'b001: alu_control_out = 4'b0100; // SLLI
                    3'b010: alu_control_out = 4'b1000; // SLTI
                    3'b011: alu_control_out = 4'b1001; // SLTIU
                    3'b100: alu_control_out = 4'b0011; // XORI
                    3'b101: alu_control_out = (funct7[5]) ? 4'b0111 : 4'b0101; // SRAI/SRLI
                    3'b110: alu_control_out = 4'b0001; // ORI
                    3'b111: alu_control_out = 4'b0000; // ANDI
                    default: alu_control_out = 4'b0010;
                endcase
            end

            default: alu_control_out = 4'b0010;
        endcase
    end

endmodule
