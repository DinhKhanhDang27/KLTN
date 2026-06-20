`timescale 1ns/1ps

module riscv_sdram_sha_uart_tb;
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
    wire sdram_select = avm_address < 32'h0200_0000;
    wire [31:0] sha_readdata;
    wire sha_waitrequest;
    wire irq;

    reg [31:0] sdram [0:31];
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
        else if (sdram_select)
            avm_readdata = sdram[avm_address[6:2]];
    end

    initial begin
        sdram[0]  = 32'h53484132;
        sdram[1]  = 32'd83;
        sdram[2]  = 32'h44696e68;
        sdram[3]  = 32'h204b6861;
        sdram[4]  = 32'h6e682044;
        sdram[5]  = 32'h616e6720;
        sdram[6]  = 32'h32333532;
        sdram[7]  = 32'h30323234;
        sdram[8]  = 32'h20506861;
        sdram[9]  = 32'h6d204368;
        sdram[10] = 32'h69204461;
        sdram[11] = 32'h74203233;
        sdram[12] = 32'h35323032;
        sdram[13] = 32'h3635202d;
        sdram[14] = 32'h20534841;
        sdram[15] = 32'h32353620;
        sdram[16] = 32'h6c6f6e67;
        sdram[17] = 32'h206d6573;
        sdram[18] = 32'h73616765;
        sdram[19] = 32'h20696e20;
        sdram[20] = 32'h53445241;
        sdram[21] = 32'h4d207465;
        sdram[22] = 32'h73742e00;
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

        while (cycles < 20000 && uart_count < 64) begin
            @(posedge clk);
            cycles = cycles + 1;
        end

        if (uart_count < 64) begin
            $display("[FAIL] only saw %0d UART chars, pc=%h alu=%h", uart_count, out_pc, out_alu_result);
            $finish;
        end

        if (uart_text !== "07397594b03668d1f2115d8f339450ef4294455ced4ff850bfb0c5358efb7266") begin
            $display("[FAIL] UART text = %s", uart_text);
            $finish;
        end

        $display("[PASS] firmware hashes SDRAM message and prints digest");
        $finish;
    end
endmodule
