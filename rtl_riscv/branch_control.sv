// ============================================================================
// Branch Control Unit
// Determines if a branch should be taken based on funct3 and ALU result
// ============================================================================
module branch_control (
    input        branch,
    input  [2:0] funct3,
    input  [63:0] alu_result,
    input        zero,
    output reg   branch_taken
);

    always @(*) begin
        if (!branch) begin
            branch_taken = 1'b0;
        end else begin
            case (funct3)
                3'b000: branch_taken = zero;                    // BEQ
                3'b001: branch_taken = ~zero;                   // BNE
                3'b100: branch_taken = alu_result[0];           // BLT  (SLT result)
                3'b101: branch_taken = ~alu_result[0];          // BGE  (not SLT)
                3'b110: branch_taken = alu_result[0];           // BLTU (SLTU result)
                3'b111: branch_taken = ~alu_result[0];          // BGEU (not SLTU)
                default: branch_taken = 1'b0;
            endcase
        end
    end

endmodule
