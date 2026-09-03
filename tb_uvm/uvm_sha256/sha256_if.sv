interface sha256_if(input logic clk, input logic reset_n);
    logic        avs_chipselect;
    logic [4:0]  avs_address;
    logic        avs_read;
    logic [31:0] avs_readdata;
    logic        avs_write;
    logic [3:0]  avs_byteenable;
    logic [31:0] avs_writedata;
    logic        avs_waitrequest;
    logic        irq;
endinterface
