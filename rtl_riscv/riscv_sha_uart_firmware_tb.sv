`timescale 1ns/1ps

module riscv_sha_uart_firmware_tb;
    localparam [31:0] SHA_BASE  = 32'h0200_8000;
    localparam [31:0] UART_BASE = 32'h0200_80a0;

    reg         clk;
    reg         reset_n;
    wire [31:0] avm_address;
    wire        avm_read;
    reg  [31:0] avm_readdata;
    wire        avm_readdatavalid;
    wire        avm_write;
    wire [31:0] avm_writedata;
    wire [3:0]  avm_byteenable;
    wire        avm_waitrequest;
    wire [63:0] out_pc;
    wire [63:0] out_alu_result;

    wire sha_select = (avm_address >= SHA_BASE) && (avm_address < (SHA_BASE + 32'h80));
    wire uart_status_select = avm_read && (avm_address == (UART_BASE + 32'd4));
    wire [31:0] sha_readdata;
    wire sha_waitrequest;
    wire irq;

    reg [8*64-1:0] uart_text;
    integer uart_count;
    integer cycles;

    riscv_avalon_wrapper dut (
        .clk               (clk),
        .reset_n           (reset_n),
        .avm_address       (avm_address),
        .avm_read          (avm_read),
        .avm_readdata      (avm_readdata),
        .avm_readdatavalid (avm_readdatavalid),
        .avm_write         (avm_write),
        .avm_writedata     (avm_writedata),
        .avm_byteenable    (avm_byteenable),
        .avm_waitrequest   (avm_waitrequest),
        .out_pc            (out_pc),
        .out_alu_result    (out_alu_result)
    );

    sha256_avalon_wrapper sha (
        .clk             (clk),
        .reset_n         (reset_n),
        .avs_chipselect  (sha_select && (avm_read || avm_write)),
        .avs_address     (avm_address[6:2]),
        .avs_read        (avm_read && sha_select),
        .avs_readdata    (sha_readdata),
        .avs_write       (avm_write && sha_select),
        .avs_byteenable  (avm_byteenable),
        .avs_writedata   (avm_writedata),
        .avs_waitrequest (sha_waitrequest),
        .irq             (irq)
    );

    assign avm_waitrequest   = sha_select ? sha_waitrequest : 1'b0;
    assign avm_readdatavalid = avm_read && !avm_waitrequest;

    always @(*) begin
        avm_readdata = 32'd0;
        if (sha_select)
            avm_readdata = sha_readdata;
        else if (uart_status_select)
            avm_readdata = 32'h0001_0000;
    end

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(posedge clk) begin
        if (!reset_n) begin
            uart_count <= 0;
            uart_text <= '0;
        end else if (avm_write && avm_address == UART_BASE) begin
            if (uart_count < 64)
                uart_text[(63 - uart_count) * 8 +: 8] <= avm_writedata[7:0];
            uart_count <= uart_count + 1;
        end
    end

    initial begin
        reset_n = 1'b0;
        cycles = 0;
        repeat (5) @(posedge clk);
        reset_n = 1'b1;

        while (cycles < 10000 && uart_count < 64) begin
            @(posedge clk);
            cycles = cycles + 1;
        end

        if (uart_count < 64) begin
            $display("[FAIL] only saw %0d UART chars, pc=%h alu=%h", uart_count, out_pc, out_alu_result);
            $finish;
        end

        if (uart_text !== "4d0943b7744c6396b0760c96cc601e8d86ba510a19564e78b2fa145c04a480aa") begin
            $display("[FAIL] UART text = %s", uart_text);
            $finish;
        end

        repeat (20) @(posedge clk);
        if (uart_count != 64) begin
            $display("[FAIL] UART kept writing after digest, count=%0d text=%s", uart_count, uart_text);
            $finish;
        end

        $display("[PASS] RISC-V firmware reads SHA wrapper and prints digest");
        $finish;
    end
endmodule
