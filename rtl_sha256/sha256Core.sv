module sha256_core (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire init,
    input wire [511:0] block_in,
    output reg ready,
    output reg hash_valid,
    output reg [255:0] hash_out
);

    reg [31:0] h_reg [0:7];
    reg [31:0] w_mem [0:63];
    reg [31:0] a, b, c, d, e, f, g, h;
    reg [6:0] round;
    reg [1:0] state;

    localparam IDLE = 2'd0;
    localparam CALC = 2'd1;
    localparam DONE = 2'd2;

    wire [31:0] k [0:63];
    assign k[0]=32'h428a2f98; assign k[1]=32'h71374491; assign k[2]=32'hb5c0fbcf; assign k[3]=32'he9b5dba5;
    assign k[4]=32'h3956c25b; assign k[5]=32'h59f111f1; assign k[6]=32'h923f82a4; assign k[7]=32'hab1c5ed5;
    assign k[8]=32'hd807aa98; assign k[9]=32'h12835b01; assign k[10]=32'h243185be; assign k[11]=32'h550c7dc3;
    assign k[12]=32'h72be5d74; assign k[13]=32'h80deb1fe; assign k[14]=32'h9bdc06a7; assign k[15]=32'hc19bf174;
    assign k[16]=32'he49b69c1; assign k[17]=32'hefbe4786; assign k[18]=32'h0fc19dc6; assign k[19]=32'h240ca1cc;
    assign k[20]=32'h2de92c6f; assign k[21]=32'h4a7484aa; assign k[22]=32'h5cb0a9dc; assign k[23]=32'h76f988da;
    assign k[24]=32'h983e5152; assign k[25]=32'ha831c66d; assign k[26]=32'hb00327c8; assign k[27]=32'hbf597fc7;
    assign k[28]=32'hc6e00bf3; assign k[29]=32'hd5a79147; assign k[30]=32'h06ca6351; assign k[31]=32'h14292967;
    assign k[32]=32'h27b70a85; assign k[33]=32'h2e1b2138; assign k[34]=32'h4d2c6dfc; assign k[35]=32'h53380d13;
    assign k[36]=32'h650a7354; assign k[37]=32'h766a0abb; assign k[38]=32'h81c2c92e; assign k[39]=32'h92722c85;
    assign k[40]=32'ha2bfe8a1; assign k[41]=32'ha81a664b; assign k[42]=32'hc24b8b70; assign k[43]=32'hc76c51a3;
    assign k[44]=32'hd192e819; assign k[45]=32'hd6990624; assign k[46]=32'hf40e3585; assign k[47]=32'h106aa070;
    assign k[48]=32'h19a4c116; assign k[49]=32'h1e376c08; assign k[50]=32'h2748774c; assign k[51]=32'h34b0bcb5;
    assign k[52]=32'h391c0cb3; assign k[53]=32'h4ed8aa4a; assign k[54]=32'h5b9cca4f; assign k[55]=32'h682e6ff3;
    assign k[56]=32'h748f82ee; assign k[57]=32'h78a5636f; assign k[58]=32'h84c87814; assign k[59]=32'h8cc70208;
    assign k[60]=32'h90befffa; assign k[61]=32'ha4506ceb; assign k[62]=32'hbef9a3f7; assign k[63]=32'hc67178f2;

    function [31:0] rotr;
        input [31:0] x;
        input [4:0] n;
        begin
            rotr = (x >> n) | (x << (32 - n));
        end
    endfunction

    function [31:0] ch_func;
        input [31:0] x, y, z;
        begin
            ch_func = (x & y) ^ (~x & z);
        end
    endfunction

    function [31:0] maj_func;
        input [31:0] x, y, z;
        begin
            maj_func = (x & y) ^ (x & z) ^ (y & z);
        end
    endfunction

    function [31:0] bsig0;
        input [31:0] x;
        begin
            bsig0 = rotr(x, 2) ^ rotr(x, 13) ^ rotr(x, 22);
        end
    endfunction

    function [31:0] bsig1;
        input [31:0] x;
        begin
            bsig1 = rotr(x, 6) ^ rotr(x, 11) ^ rotr(x, 25);
        end
    endfunction

    function [31:0] ssig0;
        input [31:0] x;
        begin
            ssig0 = rotr(x, 7) ^ rotr(x, 18) ^ (x >> 3);
        end
    endfunction

    function [31:0] ssig1;
        input [31:0] x;
        begin
            ssig1 = rotr(x, 17) ^ rotr(x, 19) ^ (x >> 10);
        end
    endfunction

    wire [31:0] w_t = (round < 16) ? w_mem[round] :
                      (ssig1(w_mem[round-2]) + w_mem[round-7] + ssig0(w_mem[round-15]) + w_mem[round-16]);
    wire [31:0] t1 = h + bsig1(e) + ch_func(e, f, g) + k[round] + w_t;
    wire [31:0] t2 = bsig0(a) + maj_func(a, b, c);
    wire [31:0] h0_new = h_reg[0] + a;
    wire [31:0] h1_new = h_reg[1] + b;
    wire [31:0] h2_new = h_reg[2] + c;
    wire [31:0] h3_new = h_reg[3] + d;
    wire [31:0] h4_new = h_reg[4] + e;
    wire [31:0] h5_new = h_reg[5] + f;
    wire [31:0] h6_new = h_reg[6] + g;
    wire [31:0] h7_new = h_reg[7] + h;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            ready <= 1'b1;
            hash_valid <= 1'b0;
            hash_out <= 256'd0;
            round <= 7'd0;
            for (i = 0; i < 8; i = i + 1) h_reg[i] <= 32'd0;
            for (i = 0; i < 64; i = i + 1) w_mem[i] <= 32'd0;
            a <= 32'd0; b <= 32'd0; c <= 32'd0; d <= 32'd0;
            e <= 32'd0; f <= 32'd0; g <= 32'd0; h <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    hash_valid <= 1'b0;
                    if (start) begin
                        if (init) begin
                            h_reg[0] <= 32'h6a09e667; h_reg[1] <= 32'hbb67ae85; h_reg[2] <= 32'h3c6ef372; h_reg[3] <= 32'ha54ff53a;
                            h_reg[4] <= 32'h510e527f; h_reg[5] <= 32'h9b05688c; h_reg[6] <= 32'h1f83d9ab; h_reg[7] <= 32'h5be0cd19;
                            a <= 32'h6a09e667; b <= 32'hbb67ae85; c <= 32'h3c6ef372; d <= 32'ha54ff53a;
                            e <= 32'h510e527f; f <= 32'h9b05688c; g <= 32'h1f83d9ab; h <= 32'h5be0cd19;
                        end else begin
                            a <= h_reg[0]; b <= h_reg[1]; c <= h_reg[2]; d <= h_reg[3];
                            e <= h_reg[4]; f <= h_reg[5]; g <= h_reg[6]; h <= h_reg[7];
                        end

                        for (i = 0; i < 16; i = i + 1) begin
                            w_mem[i] <= block_in[(15 - i) * 32 +: 32];
                        end
                        for (i = 16; i < 64; i = i + 1) begin
                            w_mem[i] <= 32'd0;
                        end

                        round <= 7'd0;
                        ready <= 1'b0;
                        state <= CALC;
                    end
                end

                CALC: begin
                    if (round >= 16) begin
                        w_mem[round] <= w_t;
                    end

                    h <= g;
                    g <= f;
                    f <= e;
                    e <= d + t1;
                    d <= c;
                    c <= b;
                    b <= a;
                    a <= t1 + t2;

                    if (round == 7'd63) begin
                        state <= DONE;
                    end else begin
                        round <= round + 7'd1;
                    end
                end

                DONE: begin
                    h_reg[0] <= h0_new;
                    h_reg[1] <= h1_new;
                    h_reg[2] <= h2_new;
                    h_reg[3] <= h3_new;
                    h_reg[4] <= h4_new;
                    h_reg[5] <= h5_new;
                    h_reg[6] <= h6_new;
                    h_reg[7] <= h7_new;

                    hash_out <= {
                        h0_new, h1_new, h2_new, h3_new,
                        h4_new, h5_new, h6_new, h7_new
                    };

                    ready <= 1'b1;
                    hash_valid <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
