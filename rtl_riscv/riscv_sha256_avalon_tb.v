`timescale 1ns/1ps

module riscv_sha256_avalon_tb;
    reg clk;
    reg reset;

    wire [31:0] avm_address;
    wire        avm_read;
    wire        avm_write;
    wire [31:0] avm_writedata;
    reg  [31:0] avm_readdata;
    wire        avm_waitrequest;
    reg         avm_readdatavalid;
    wire [3:0]  avm_byteenable;
    wire [63:0] out_pc;
    wire [63:0] out_alu_result;
    wire [3:0]  debug_state;

    reg [31:0] mem [0:255];
    integer i;

    function [31:0] r_inst;
        input [6:0] funct7;
        input [4:0] rs2;
        input [4:0] rs1;
        input [2:0] funct3;
        input [4:0] rd;
        input [6:0] opcode;
        begin
            r_inst = {funct7, rs2, rs1, funct3, rd, opcode};
        end
    endfunction

    function [31:0] i_inst;
        input integer imm;
        input [4:0] rs1;
        input [2:0] funct3;
        input [4:0] rd;
        input [6:0] opcode;
        begin
            i_inst = {imm[11:0], rs1, funct3, rd, opcode};
        end
    endfunction

    function [31:0] s_inst;
        input integer imm;
        input [4:0] rs2;
        input [4:0] rs1;
        input [2:0] funct3;
        begin
            s_inst = {imm[11:5], rs2, rs1, funct3, imm[4:0], 7'b0100011};
        end
    endfunction

    function [31:0] b_inst;
        input integer imm;
        input [4:0] rs2;
        input [4:0] rs1;
        input [2:0] funct3;
        begin
            b_inst = {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], 7'b1100011};
        end
    endfunction

    function [31:0] u_inst;
        input [19:0] imm20;
        input [4:0] rd;
        input [6:0] opcode;
        begin
            u_inst = {imm20, rd, opcode};
        end
    endfunction

    assign avm_waitrequest = 1'b0;

    riscv_sha256_avalon dut (
        .clk               (clk),
        .reset             (reset),
        .avm_address       (avm_address),
        .avm_read          (avm_read),
        .avm_write         (avm_write),
        .avm_writedata     (avm_writedata),
        .avm_readdata      (avm_readdata),
        .avm_waitrequest   (avm_waitrequest),
        .avm_readdatavalid (avm_readdatavalid),
        .avm_byteenable    (avm_byteenable),
        .out_pc            (out_pc),
        .out_alu_result    (out_alu_result),
        .debug_state       (debug_state)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        for (i = 0; i < 256; i = i + 1)
            mem[i] = 32'h00000013; // nop

        // Copy four bytes from 0x100 to 0x200 using C-like byte accesses.
        mem[0]  = i_inst(12'h100, 5'd0, 3'b000, 5'd1, 7'b0010011); // addi x1, x0, 0x100
        mem[1]  = i_inst(12'h200, 5'd0, 3'b000, 5'd2, 7'b0010011); // addi x2, x0, 0x200
        mem[2]  = i_inst(4,      5'd0, 3'b000, 5'd3, 7'b0010011); // addi x3, x0, 4
        mem[3]  = i_inst(0,      5'd1, 3'b100, 5'd4, 7'b0000011); // lbu  x4, 0(x1)
        mem[4]  = s_inst(0,      5'd4, 5'd2, 3'b000);             // sb   x4, 0(x2)
        mem[5]  = i_inst(1,      5'd1, 3'b000, 5'd1, 7'b0010011); // addi x1, x1, 1
        mem[6]  = i_inst(1,      5'd2, 3'b000, 5'd2, 7'b0010011); // addi x2, x2, 1
        mem[7]  = i_inst(-1,     5'd3, 3'b000, 5'd3, 7'b0010011); // addi x3, x3, -1
        mem[8]  = b_inst(-20,    5'd0, 5'd3, 3'b001);             // bne  x3, x0, loop

        // Load extension tests.
        mem[9]  = i_inst(12'h203, 5'd0, 3'b000, 5'd5, 7'b0010011); // addi x5, x0, 0x203
        mem[10] = i_inst(0,       5'd5, 3'b000, 5'd6, 7'b0000011); // lb   x6, 0(x5)
        mem[11] = i_inst(12'h202, 5'd0, 3'b000, 5'd5, 7'b0010011); // addi x5, x0, 0x202
        mem[12] = i_inst(0,       5'd5, 3'b001, 5'd7, 7'b0000011); // lh   x7, 0(x5)
        mem[13] = i_inst(0,       5'd5, 3'b101, 5'd8, 7'b0000011); // lhu  x8, 0(x5)

        // Word-op tests commonly emitted by RV64 C compilers.
        mem[14] = u_inst(20'hfffff, 5'd9, 7'b0110111);             // lui  x9, 0xfffff
        mem[15] = i_inst(1,        5'd9, 3'b000, 5'd9, 7'b0011011); // addiw x9, x9, 1
        mem[16] = r_inst(7'b0000000, 5'd9, 5'd9, 3'b000, 5'd10, 7'b0111011); // addw x10,x9,x9
        mem[17] = i_inst(1,        5'd10, 3'b101, 5'd11, 7'b0011011); // srliw x11,x10,1
        mem[18] = i_inst(12'h401,  5'd10, 3'b101, 5'd12, 7'b0011011); // sraiw x12,x10,1
        mem[19] = i_inst(12'h220, 5'd0, 3'b000, 5'd13, 7'b0010011); // addi x13, x0, 0x220
        mem[20] = s_inst(0,       5'd10, 5'd13, 3'b010);            // sw   x10, 0(x13)
        mem[21] = i_inst(0,       5'd13, 3'b010, 5'd14, 7'b0000011); // lw  x14, 0(x13)
        mem[22] = i_inst(0,       5'd13, 3'b110, 5'd15, 7'b0000011); // lwu x15, 0(x13)
        mem[23] = 32'h0000006f; // halt: jal x0, 0

        mem[64] = 32'haabbccdd; // source bytes at 0x100
    end

    always @(posedge clk) begin
        avm_readdatavalid <= avm_read;
        avm_readdata <= mem[avm_address[9:2]];

        if (avm_write) begin
            if (avm_byteenable[0]) mem[avm_address[9:2]][7:0]   <= avm_writedata[7:0];
            if (avm_byteenable[1]) mem[avm_address[9:2]][15:8]  <= avm_writedata[15:8];
            if (avm_byteenable[2]) mem[avm_address[9:2]][23:16] <= avm_writedata[23:16];
            if (avm_byteenable[3]) mem[avm_address[9:2]][31:24] <= avm_writedata[31:24];
        end
    end

    initial begin
        reset = 1'b1;
        avm_readdatavalid = 1'b0;
        avm_readdata = 32'd0;
        repeat (4) @(posedge clk);
        reset = 1'b0;

        repeat (240) @(posedge clk);

        if (mem[128] !== 32'haabbccdd) begin
            $display("[FAIL] byte copy through SDRAM-like Avalon wrote %08x", mem[128]);
            $finish;
        end

        if (dut.u_regfile.registers[6] !== 64'hffffffffffffffaa) begin
            $display("[FAIL] LB sign extension x6=%016x", dut.u_regfile.registers[6]);
            $finish;
        end

        if (dut.u_regfile.registers[7] !== 64'hffffffffffffaabb) begin
            $display("[FAIL] LH sign extension x7=%016x", dut.u_regfile.registers[7]);
            $finish;
        end

        if (dut.u_regfile.registers[8] !== 64'h000000000000aabb) begin
            $display("[FAIL] LHU zero extension x8=%016x", dut.u_regfile.registers[8]);
            $finish;
        end

        if (dut.u_regfile.registers[9] !== 64'hfffffffffffff001) begin
            $display("[FAIL] ADDIW sign extension x9=%016x", dut.u_regfile.registers[9]);
            $finish;
        end

        if (dut.u_regfile.registers[10] !== 64'hffffffffffffe002) begin
            $display("[FAIL] ADDW sign extension x10=%016x", dut.u_regfile.registers[10]);
            $finish;
        end

        if (dut.u_regfile.registers[11] !== 64'h000000007ffff001) begin
            $display("[FAIL] SRLIW x11=%016x", dut.u_regfile.registers[11]);
            $finish;
        end

        if (dut.u_regfile.registers[12] !== 64'hfffffffffffff001) begin
            $display("[FAIL] SRAIW x12=%016x", dut.u_regfile.registers[12]);
            $finish;
        end

        if (dut.u_regfile.registers[14] !== 64'hffffffffffffe002) begin
            $display("[FAIL] LW sign extension x14=%016x", dut.u_regfile.registers[14]);
            $finish;
        end

        if (dut.u_regfile.registers[15] !== 64'h00000000ffffe002) begin
            $display("[FAIL] LWU zero extension x15=%016x", dut.u_regfile.registers[15]);
            $finish;
        end

        $display("[PASS] riscv_sha256_avalon C-oriented logical/load-store smoke test");
        $finish;
    end
endmodule
