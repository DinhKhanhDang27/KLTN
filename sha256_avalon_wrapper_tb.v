`timescale 1ns/1ps

module sha256_avalon_wrapper_tb;
    reg         clk;
    reg         reset_n;
    reg         avs_chipselect;
    reg  [4:0]  avs_address;
    reg         avs_read;
    wire [31:0] avs_readdata;
    reg         avs_write;
    reg  [3:0]  avs_byteenable;
    reg  [31:0] avs_writedata;
    wire        avs_waitrequest;
    wire        irq;

    reg [255:0] digest;

    sha256_avalon_wrapper dut (
        .clk             (clk),
        .reset_n         (reset_n),
        .avs_chipselect  (avs_chipselect),
        .avs_address     (avs_address),
        .avs_read        (avs_read),
        .avs_readdata    (avs_readdata),
        .avs_write       (avs_write),
        .avs_byteenable  (avs_byteenable),
        .avs_writedata   (avs_writedata),
        .avs_waitrequest (avs_waitrequest),
        .irq             (irq)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task av_write;
        input [4:0] addr;
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

    task av_read;
        input  [4:0] addr;
        output [31:0] data;
        begin
            @(posedge clk);
            avs_chipselect <= 1'b1;
            avs_address    <= addr;
            avs_read       <= 1'b1;
            avs_write      <= 1'b0;
            @(posedge clk);
            data           = avs_readdata;
            avs_read       <= 1'b0;
            avs_chipselect <= 1'b0;
        end
    endtask

    integer n;
    reg [31:0] word_data;

    initial begin
        reset_n        = 1'b0;
        avs_chipselect = 1'b0;
        avs_address    = 5'd0;
        avs_read       = 1'b0;
        avs_write      = 1'b0;
        avs_byteenable = 4'hf;
        avs_writedata  = 32'd0;
        repeat (4) @(posedge clk);
        reset_n = 1'b1;

        // SHA-256("abc") padded single block.
        av_write(5'd0,  32'h61626380);
        av_write(5'd1,  32'h00000000);
        av_write(5'd2,  32'h00000000);
        av_write(5'd3,  32'h00000000);
        av_write(5'd4,  32'h00000000);
        av_write(5'd5,  32'h00000000);
        av_write(5'd6,  32'h00000000);
        av_write(5'd7,  32'h00000000);
        av_write(5'd8,  32'h00000000);
        av_write(5'd9,  32'h00000000);
        av_write(5'd10, 32'h00000000);
        av_write(5'd11, 32'h00000000);
        av_write(5'd12, 32'h00000000);
        av_write(5'd13, 32'h00000000);
        av_write(5'd14, 32'h00000000);
        av_write(5'd15, 32'h00000018);

        // control: start=1, init=1, irq_enable=1.
        av_write(5'd16, 32'h00000007);

        n = 0;
        while (!irq && n < 100) begin
            @(posedge clk);
            n = n + 1;
        end

        if (!irq) begin
            $display("[FAIL] SHA wrapper did not raise irq");
            $finish;
        end

        av_read(5'd18, digest[255:224]);
        av_read(5'd19, digest[223:192]);
        av_read(5'd20, digest[191:160]);
        av_read(5'd21, digest[159:128]);
        av_read(5'd22, digest[127:96]);
        av_read(5'd23, digest[95:64]);
        av_read(5'd24, digest[63:32]);
        av_read(5'd25, digest[31:0]);

        if (digest !== 256'hba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad) begin
            $display("[FAIL] SHA digest = %064x", digest);
            $finish;
        end

        av_read(5'd17, word_data);
        if (word_data[2:0] !== 3'b111) begin
            $display("[FAIL] bad status = %08x", word_data);
            $finish;
        end

        av_write(5'd17, 32'h00000004);
        @(posedge clk);
        if (irq) begin
            $display("[FAIL] IRQ did not clear");
            $finish;
        end

        $display("[PASS] sha256_avalon_wrapper abc vector and IRQ");
        $finish;
    end
endmodule
