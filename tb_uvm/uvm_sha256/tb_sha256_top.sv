`timescale 1ns/1ps
import uvm_pkg::*;
`include "uvm_macros.svh"
import sha256_pkg::*;

module tb_sha256_top;
    logic clk;
    logic reset_n;

    sha256_if vif(clk, reset_n);

    sha256_avalon_wrapper dut (
        .clk(clk),
        .reset_n(reset_n),
        .avs_chipselect(vif.avs_chipselect),
        .avs_address(vif.avs_address),
        .avs_read(vif.avs_read),
        .avs_readdata(vif.avs_readdata),
        .avs_write(vif.avs_write),
        .avs_byteenable(vif.avs_byteenable),
        .avs_writedata(vif.avs_writedata),
        .avs_waitrequest(vif.avs_waitrequest),
        .irq(vif.irq)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        reset_n = 0;
        #20 reset_n = 1;
    end

    initial begin
        uvm_config_db#(virtual sha256_if)::set(null, "*", "vif", vif);
        // Bạn có thể để trống run_test() và truyền +UVM_TESTNAME từ Vivado
        // hoặc ghi cứng tên test muốn chạy vào đây:
        run_test("sha256_all_test");
    end
endmodule
