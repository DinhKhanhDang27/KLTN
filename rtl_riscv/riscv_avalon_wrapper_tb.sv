`timescale 1ns/1ps

module riscv_avalon_wrapper_tb;
    reg         clk;
    reg         reset_n;
    wire [31:0] avm_address;
    wire        avm_read;
    wire [31:0] avm_readdata;
    wire        avm_readdatavalid;
    wire        avm_write;
    wire [31:0] avm_writedata;
    wire [3:0]  avm_byteenable;
    wire        avm_waitrequest;
    wire [63:0] out_pc;
    wire [63:0] out_alu_result;

    wire [4:0]  sha_address = avm_address[6:2];
    wire        irq;
    reg  [255:0] digest;

    riscv_avalon_wrapper dut (
        .clk                 (clk),
        .reset_n             (reset_n),
        .avm_address         (avm_address),
        .avm_read            (avm_read),
        .avm_readdata        (avm_readdata),
        .avm_readdatavalid   (avm_readdatavalid),
        .avm_write           (avm_write),
        .avm_writedata       (avm_writedata),
        .avm_byteenable      (avm_byteenable),
        .avm_waitrequest     (avm_waitrequest),
        .out_pc              (out_pc),
        .out_alu_result      (out_alu_result)
    );

    sha256_avalon_wrapper sha (
        .clk             (clk),
        .reset_n         (reset_n),
        .avs_chipselect  (avm_read | avm_write),
        .avs_address     (sha_address),
        .avs_read        (avm_read),
        .avs_readdata    (avm_readdata),
        .avs_write       (avm_write),
        .avs_byteenable  (avm_byteenable),
        .avs_writedata   (avm_writedata),
        .avs_waitrequest (avm_waitrequest),
        .irq             (irq)
    );

    assign avm_readdatavalid = avm_read & ~avm_waitrequest;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        reset_n = 1'b0;
        repeat (5) @(posedge clk);
        reset_n = 1'b1;

        repeat (200) @(posedge clk);

        if (!irq) begin
            $display("[FAIL] RISC-V did not start SHA through Avalon");
            $finish;
        end

        digest = {
            sha.u_sha256_core.hash_out[255:224],
            sha.u_sha256_core.hash_out[223:192],
            sha.u_sha256_core.hash_out[191:160],
            sha.u_sha256_core.hash_out[159:128],
            sha.u_sha256_core.hash_out[127:96],
            sha.u_sha256_core.hash_out[95:64],
            sha.u_sha256_core.hash_out[63:32],
            sha.u_sha256_core.hash_out[31:0]
        };

        if (digest !== 256'hba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad) begin
            $display("[FAIL] RISC-V/SHA digest = %064x", digest);
            $finish;
        end

        $display("[PASS] riscv_avalon_wrapper controls sha256_avalon_wrapper");
        $finish;
    end
endmodule
