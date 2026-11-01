// ============================================================================
// RISC-V Immediate Generator
// Generates sign-extended 32-bit immediates from instruction encoding
// Supports: I, S, B, U, J type immediates
// ============================================================================
module imm_gen (
    input  [31:0] instruction,
    output reg [31:0] imm
);

    wire [6:0] opcode;
    assign opcode = instruction[6:0];

    always @(*) begin
        case (opcode)
            // I-type: LOAD, ADDI, JALR, etc.
            7'b0000011, // LW
            7'b0010011, // ADDI, ANDI, ORI, XORI, SLTI, SLTIU, SLLI, SRLI, SRAI
            7'b1100111: // JALR
                imm = {{20{instruction[31]}}, instruction[31:20]};

            // S-type: STORE
            7'b0100011:
                imm = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};

            // B-type: BRANCH
            7'b1100011:
                imm = {{19{instruction[31]}}, instruction[31], instruction[7], 
                        instruction[30:25], instruction[11:8], 1'b0};

            // U-type: LUI, AUIPC
            7'b0110111, // LUI
            7'b0010111: // AUIPC
                imm = {instruction[31:12], 12'b0};

            // J-type: JAL
            7'b1101111:
                imm = {{11{instruction[31]}}, instruction[31], instruction[19:12],
                        instruction[20], instruction[30:21], 1'b0};

            default:
                imm = 32'd0;
        endcase
    end

endmodule
