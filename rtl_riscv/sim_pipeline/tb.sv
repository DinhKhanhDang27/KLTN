`timescale 1ns/1ps
module tb;
    reg clk=0, rst=1;
    wire [31:0] out_pc, out_alu;
    riscv_pipeline_top dut(.clk(clk), .rst(rst), .out_pc(out_pc), .out_alu_result(out_alu));
    always #5 clk=~clk;
    integer errors=0;
    task chk(input [8*8:1] nm, input [31:0] got, input [31:0] exp);
        begin
            if (got!==exp) begin $display("FAIL %s = %0d (0x%08x), expected %0d", nm, got, got, exp); errors=errors+1; end
            else $display("PASS %s = %0d", nm, got);
        end
    endtask
    initial begin
        repeat(3) @(posedge clk); #1 rst=0;   // release reset
        repeat(60) @(posedge clk);            // let program finish
        $display("==== Register check ====");
        chk("x1", dut.u_regfile.registers[1], 32'd5);
        chk("x2", dut.u_regfile.registers[2], 32'd8);
        chk("x3", dut.u_regfile.registers[3], 32'd13);
        chk("x4", dut.u_regfile.registers[4], 32'd13);
        chk("x5", dut.u_regfile.registers[5], 32'd18);
        chk("x6", dut.u_regfile.registers[6], 32'd99);   // branch-not-taken ran; taken-branch skipped 123
        chk("x7", dut.u_regfile.registers[7], 32'd7);
        chk("x8", dut.u_regfile.registers[8], 32'h30);   // jal return addr
        chk("x9", dut.u_regfile.registers[9], 32'd0);    // skipped by jal
        chk("x10",dut.u_regfile.registers[10],32'd42);
        $display("==== Memory check ====");
        chk("mem0", {dut.u_dmem.mem[3],dut.u_dmem.mem[2],dut.u_dmem.mem[1],dut.u_dmem.mem[0]}, 32'd13);
        if (errors==0) $display("\n*** ALL TESTS PASSED ***");
        else $display("\n*** %0d FAILURE(S) ***", errors);
        $finish;
    end
endmodule
