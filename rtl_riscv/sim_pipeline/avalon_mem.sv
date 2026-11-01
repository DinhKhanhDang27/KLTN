// Avalon-MM slave with waitrequest busy (WLAT) + delayed readdatavalid (RLAT)
module avalon_mem #(parameter RLAT=3, parameter WLAT=2) (
    input         clk, input rst,
    input  [31:0] address, input read, input write,
    input  [31:0] writedata, input [3:0] byteenable,
    output reg [31:0] readdata, output reg readdatavalid, output waitrequest
);
    reg [31:0] mem [0:1023];
    integer i; initial for (i=0;i<1024;i=i+1) mem[i]=0;
    wire req = read | write;
    reg [3:0] wt; reg active; reg [3:0] cnt; reg [31:0] rdat;
    assign waitrequest = req & (wt != 0);
    wire accept = req & (wt==0) & ~active;
    always @(posedge clk or posedge rst) begin
        if (rst) begin wt<=WLAT[3:0]; active<=0; cnt<=0; readdatavalid<=0; readdata<=0; end
        else begin
            readdatavalid<=0;
            // waitrequest countdown per request
            if (req) begin if (wt!=0) wt<=wt-1; else wt<=WLAT[3:0]; end else wt<=WLAT[3:0];
            // accept
            if (accept) begin
                if (write) mem[address[11:2]] <= writedata;
                if (read)  begin rdat<=mem[address[11:2]]; active<=1; cnt<=RLAT[3:0]; end
            end else if (active) begin
                if (cnt==0) begin readdatavalid<=1; readdata<=rdat; active<=0; end
                else cnt<=cnt-1;
            end
        end
    end
endmodule
