`timescale 1ns/1ps
module tb_bridge;
    reg clk=0, reset_n=0;
    wire [31:0] avm_address, avm_readdata, avm_writedata; wire [3:0] avm_byteenable;
    wire avm_read, avm_write, avm_readdatavalid, avm_waitrequest;
    wire [31:0] out_pc, out_alu;
    riscv_avalon_wrapper dut (
        .clk(clk), .reset_n(reset_n),
        .avm_address(avm_address), .avm_read(avm_read), .avm_readdata(avm_readdata),
        .avm_readdatavalid(avm_readdatavalid), .avm_write(avm_write),
        .avm_writedata(avm_writedata), .avm_byteenable(avm_byteenable),
        .avm_waitrequest(avm_waitrequest), .out_pc(out_pc), .out_alu_result(out_alu)
    );
    avalon_mem #(.RLAT(3), .WLAT(2)) u_mem (
        .clk(clk), .rst(~reset_n), .address(avm_address), .read(avm_read),
        .write(avm_write), .writedata(avm_writedata), .byteenable(avm_byteenable),
        .readdata(avm_readdata), .readdatavalid(avm_readdatavalid), .waitrequest(avm_waitrequest)
    );
    always #5 clk=~clk;
    integer errors=0;
    task chk(input [8*8:1] nm, input [31:0] got, input [31:0] exp);
        begin if (got!==exp) begin $display("FAIL %s = %0d (exp %0d)",nm,got,exp); errors=errors+1; end
              else $display("PASS %s = %0d",nm,got); end
    endtask
    initial begin
        repeat(3) @(posedge clk); #1 reset_n=1;
        repeat(140) @(posedge clk);
        chk("x1", dut.u_core.u_regfile.registers[1], 32'd5);
        chk("x2", dut.u_core.u_regfile.registers[2], 32'd8);
        chk("x3", dut.u_core.u_regfile.registers[3], 32'd13);
        chk("x4", dut.u_core.u_regfile.registers[4], 32'd13);
        chk("x5", dut.u_core.u_regfile.registers[5], 32'd18);
        chk("x6", dut.u_core.u_regfile.registers[6], 32'd99);
        chk("x7", dut.u_core.u_regfile.registers[7], 32'd7);
        chk("x8", dut.u_core.u_regfile.registers[8], 32'h30);
        chk("x9", dut.u_core.u_regfile.registers[9], 32'd0);
        chk("x10",dut.u_core.u_regfile.registers[10],32'd42);
        chk("avmem0", u_mem.mem[0], 32'd13);
        if (errors==0) $display("\n*** ALL TESTS PASSED (thin bridge + core) ***");
        else $display("\n*** %0d FAILURE(S) ***", errors);
        $finish;
    end
endmodule
