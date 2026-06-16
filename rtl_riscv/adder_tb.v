`timescale 1ns / 1ps

module adder_tb;
    reg  [63:0] a;
    reg  [63:0] b;
    wire [63:0] result;

    adder uut (
        .a(a),
        .b(b),
        .result(result)
    );

    initial begin
        $monitor("Time: %0t ns | a = %d, b = %d | result = %d", $time, a, b, result);

        a = 64'd0; 
        b = 64'd0;

        #10; 
        
        a = 64'd15; 
        b = 64'd25;
        #10;
        
        a = 64'd1024; 
        b = 64'd0;
        #10;
        
        a = 64'h0000_0000_FFFF_FFFF; 
        b = 64'h0000_0000_0000_0001;
        #10;
        
        a = 64'hFFFF_FFFF_FFFF_FFFF; 
        b = 64'd1;
        #10;

        $display("================ Simulation Complete ================");
        $finish;
    end

endmodule
