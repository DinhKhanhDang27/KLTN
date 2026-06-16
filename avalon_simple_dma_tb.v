`timescale 1ns/1ps

module avalon_simple_dma_tb;
    reg         clk;
    reg         reset_n;
    reg         avs_chipselect;
    reg  [2:0]  avs_address;
    reg         avs_read;
    wire [31:0] avs_readdata;
    reg         avs_write;
    reg  [3:0]  avs_byteenable;
    reg  [31:0] avs_writedata;
    wire        avs_waitrequest;
    wire        irq;

    wire [31:0] avm_address;
    wire        avm_read;
    reg  [31:0] avm_readdata;
    reg         avm_readdatavalid;
    wire        avm_write;
    wire [31:0] avm_writedata;
    wire [3:0]  avm_byteenable;
    wire        avm_waitrequest;

    reg [31:0] mem [0:63];
    integer i;

    avalon_simple_dma dut (
        .clk               (clk),
        .reset_n           (reset_n),
        .avs_chipselect    (avs_chipselect),
        .avs_address       (avs_address),
        .avs_read          (avs_read),
        .avs_readdata      (avs_readdata),
        .avs_write         (avs_write),
        .avs_byteenable    (avs_byteenable),
        .avs_writedata     (avs_writedata),
        .avs_waitrequest   (avs_waitrequest),
        .irq               (irq),
        .avm_address       (avm_address),
        .avm_read          (avm_read),
        .avm_readdata      (avm_readdata),
        .avm_readdatavalid (avm_readdatavalid),
        .avm_write         (avm_write),
        .avm_writedata     (avm_writedata),
        .avm_byteenable    (avm_byteenable),
        .avm_waitrequest   (avm_waitrequest)
    );

    assign avm_waitrequest = 1'b0;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task avs_wr;
        input [2:0] addr;
        input [31:0] data;
        begin
            @(posedge clk);
            avs_chipselect <= 1'b1;
            avs_address    <= addr;
            avs_writedata  <= data;
            avs_byteenable <= 4'hf;
            avs_write      <= 1'b1;
            avs_read       <= 1'b0;
            @(posedge clk);
            avs_write      <= 1'b0;
            avs_chipselect <= 1'b0;
        end
    endtask

    always @(posedge clk) begin
        avm_readdatavalid <= avm_read;
        avm_readdata <= mem[avm_address[7:2]];

        if (avm_write) begin
            if (avm_byteenable[0]) mem[avm_address[7:2]][7:0]   <= avm_writedata[7:0];
            if (avm_byteenable[1]) mem[avm_address[7:2]][15:8]  <= avm_writedata[15:8];
            if (avm_byteenable[2]) mem[avm_address[7:2]][23:16] <= avm_writedata[23:16];
            if (avm_byteenable[3]) mem[avm_address[7:2]][31:24] <= avm_writedata[31:24];
        end
    end

    initial begin
        reset_n        = 1'b0;
        avs_chipselect = 1'b0;
        avs_address    = 3'd0;
        avs_read       = 1'b0;
        avs_write      = 1'b0;
        avs_byteenable = 4'hf;
        avs_writedata  = 32'd0;
        avm_readdata   = 32'd0;
        avm_readdatavalid = 1'b0;

        for (i = 0; i < 64; i = i + 1)
            mem[i] = 32'd0;
        mem[4] = 32'h11223344;
        mem[5] = 32'h55667788;

        repeat (4) @(posedge clk);
        reset_n = 1'b1;

        avs_wr(3'd2, 32'h00000010); // src
        avs_wr(3'd3, 32'h00000040); // dst
        avs_wr(3'd4, 32'd8);        // length
        avs_wr(3'd0, 32'h00000003); // start + irq_enable

        i = 0;
        while (!irq && i < 50) begin
            @(posedge clk);
            i = i + 1;
        end

        if (!irq) begin
            $display("[FAIL] DMA did not complete");
            $finish;
        end

        @(posedge clk);

        if (mem[16] !== 32'h11223344 || mem[17] !== 32'h55667788) begin
            $display("[FAIL] DMA copy bad dst0=%08x dst1=%08x", mem[16], mem[17]);
            $finish;
        end

        $display("[PASS] avalon_simple_dma memory copy");
        $finish;
    end
endmodule
