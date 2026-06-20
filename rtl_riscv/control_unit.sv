module control_unit (
    input  [6:0] opcode,
    input  [2:0] funct3,
    input  [6:0] funct7,
    output reg       branch,
    output reg       mem_read,
    output reg       mem_to_reg,
    output reg [1:0] alu_op,
    output reg       mem_write,
    output reg       alu_src,
    output reg       reg_write,
    output reg       jump,       // JAL
    output reg       jalr,       // JALR
    output reg       sha2rst,
    output reg       sha2push,
    output reg       sha2start,
    output reg       sha2perform,
    output reg       sha2finish,
    output reg       sha2read
);

    always @(*) begin
        // Default values
        branch    = 1'b0;
        mem_read  = 1'b0;
        mem_to_reg = 1'b0;
        alu_op    = 2'b00;
        mem_write = 1'b0;
        alu_src   = 1'b0;
        reg_write = 1'b0;
        jump      = 1'b0;
        jalr      = 1'b0;
        sha2rst   = 1'b0;
        sha2push  = 1'b0;
        sha2start = 1'b0;
        sha2perform = 1'b0;
        sha2finish  = 1'b0;
        sha2read    = 1'b0;

        case (opcode)
            // R-type (ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU)
            7'b0110011,
            7'b0111011: begin
                reg_write = 1'b1;
                alu_op    = 2'b10;
            end

            // I-type ALU (ADDI, ANDI, ORI, XORI, SLTI, SLTIU, SLLI, SRLI, SRAI)
            7'b0010011,
            7'b0011011: begin
                alu_src   = 1'b1;
                reg_write = 1'b1;
                alu_op    = 2'b11;
            end

            // Load (LD)
            7'b0000011: begin
                alu_src    = 1'b1;
                mem_to_reg = 1'b1;
                reg_write  = 1'b1;
                mem_read   = 1'b1;
            end

            // Store (SD)
            7'b0100011: begin
                alu_src   = 1'b1;
                mem_write = 1'b1;
            end

            // Branch (BEQ, BNE, BLT, BGE, BLTU, BGEU)
            7'b1100011: begin
                branch = 1'b1;
                alu_op = 2'b01;
            end

            // JAL
            7'b1101111: begin
                jump      = 1'b1;
                reg_write = 1'b1;
            end

            // JALR
            7'b1100111: begin
                jalr      = 1'b1;
                reg_write = 1'b1;
                alu_src   = 1'b1;
            end

            // LUI
            7'b0110111: begin
                reg_write = 1'b1;
            end

            // AUIPC
            7'b0010111: begin
                reg_write = 1'b1;
            end

            // SHA-256 custom R-type extension
            // opcode = 0x0F, funct3 = 0, funct7 selects operation.
            7'b0001111: begin
                if (funct3 == 3'b000) begin
                    case (funct7)
                        7'd1:  sha2rst     = 1'b1;
                        7'd2:  sha2push    = 1'b1;
                        7'd4:  sha2start   = 1'b1;
                        7'd8:  sha2perform = 1'b1;
                        7'd16: sha2finish  = 1'b1;
                        7'd32: begin
                            sha2read  = 1'b1;
                            reg_write = 1'b1;
                        end
                        default: ;
                    endcase
                end
            end

            default: begin
                // NOP / Unknown
            end
        endcase
    end

endmodule
