// Test-only instruction memory (same interface as the real one), program inline
module instruction_memory (input [31:0] addr, output [31:0] instruction);
    reg [31:0] mem [0:1023];
    assign instruction = mem[addr[11:2]];
    integer k;
    initial begin
        for (k=0;k<1024;k=k+1) mem[k]=32'h00000013; // NOP (addi x0,x0,0)
        mem[0]=32'h00500093; mem[1]=32'h00308113; mem[2]=32'h002081b3;
        mem[3]=32'h00302023; mem[4]=32'h00002203; mem[5]=32'h001202b3;
        mem[6]=32'h00008463; mem[7]=32'h06300313; mem[8]=32'h00009463;
        mem[9]=32'h07b00313; mem[10]=32'h00700393; mem[11]=32'h0080046f;
        mem[12]=32'h03700493; mem[13]=32'h02a00513; mem[14]=32'h00000063;
    end
endmodule
