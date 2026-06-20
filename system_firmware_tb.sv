`timescale 1ns/1ps

module system_firmware_tb;
    reg clk;
    reg reset_n;

    wire [12:0] dram_addr;
    wire [1:0]  dram_ba;
    wire        dram_cas_n;
    wire        dram_cke;
    wire        dram_cs_n;
    wire [15:0] dram_dq;
    wire [1:0]  dram_dqm;
    wire        dram_ras_n;
    wire        dram_we_n;
    wire [63:0] out_pc;
    wire [63:0] out_alu_result;
    wire        irq;

    reg [8*64-1:0] uart_text;
    integer uart_count;
    integer cycles;

    system dut (
        .clk_clk                                     (clk),
        .reset_reset_n                               (reset_n),
        .new_sdram_controller_0_wire_addr            (dram_addr),
        .new_sdram_controller_0_wire_ba              (dram_ba),
        .new_sdram_controller_0_wire_cas_n           (dram_cas_n),
        .new_sdram_controller_0_wire_cke             (dram_cke),
        .new_sdram_controller_0_wire_cs_n            (dram_cs_n),
        .new_sdram_controller_0_wire_dq              (dram_dq),
        .new_sdram_controller_0_wire_dqm             (dram_dqm),
        .new_sdram_controller_0_wire_ras_n           (dram_ras_n),
        .new_sdram_controller_0_wire_we_n            (dram_we_n),
        .riscv_avalon_wrapper_0_debug_out_pc         (out_pc),
        .riscv_avalon_wrapper_0_debug_out_alu_result (out_alu_result),
        .sha256_avalon_wrapper_0_irq_conduit_irq     (irq)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(posedge clk) begin
        if (!reset_n) begin
            uart_count <= 0;
            uart_text <= '0;
        end else if (dut.jtag_uart_0_avalon_jtag_slave_translator_avalon_anti_slave_0_write &&
                     dut.jtag_uart_0_avalon_jtag_slave_translator_avalon_anti_slave_0_chipselect &&
                     !dut.jtag_uart_0_avalon_jtag_slave_translator_avalon_anti_slave_0_waitrequest &&
                     dut.jtag_uart_0_avalon_jtag_slave_translator_avalon_anti_slave_0_address == 1'b0) begin
            if (uart_count < 64)
                uart_text[(63 - uart_count) * 8 +: 8] <=
                    dut.jtag_uart_0_avalon_jtag_slave_translator_avalon_anti_slave_0_writedata[7:0];
            uart_count <= uart_count + 1;
        end
    end

    initial begin
        reset_n = 1'b0;
        cycles = 0;
        repeat (10) @(posedge clk);
        reset_n = 1'b1;

        while (cycles < 20000 && uart_count < 64) begin
            @(posedge clk);
            cycles = cycles + 1;
        end

        if (uart_count < 64) begin
            $display("[FAIL] system only saw %0d UART chars, pc=%h alu=%h",
                     uart_count, out_pc, out_alu_result);
            $finish;
        end

        if (uart_text !== "4d0943b7744c6396b0760c96cc601e8d86ba510a19564e78b2fa145c04a480aa") begin
            $display("[FAIL] system UART text = %s", uart_text);
            $finish;
        end

        repeat (50) @(posedge clk);
        if (uart_count != 64) begin
            $display("[FAIL] system UART kept writing after digest, count=%0d text=%s",
                     uart_count, uart_text);
            $finish;
        end

        $display("[PASS] generated system prints SHA digest through JTAG UART");
        $finish;
    end
endmodule
