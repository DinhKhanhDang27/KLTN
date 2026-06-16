module sha256_avalon_wrapper (
    input  wire        clk,
    input  wire        reset_n,

    // Avalon-MM Slave Interface
    input  wire        avs_chipselect,
    input  wire [4:0]  avs_address,      // Word address for 32 registers
    input  wire        avs_read,
    output reg  [31:0] avs_readdata,
    input  wire        avs_write,
    input  wire [3:0]  avs_byteenable,
    input  wire [31:0] avs_writedata,
    output wire        avs_waitrequest,
    output wire        irq
);

    // Register map, word addressed:
    // 0x00..0x3c: block words 0..15
    // 0x40      : control {irq_en, init, start}
    // 0x44      : status  {irq_pending, done, ready}
    // 0x48..0x64: digest words 0..7
    // write 1 to status bit 2 to clear irq_pending.
    reg [31:0] data_in_regs [0:15];
    reg        start_reg;
    reg        init_reg;
    reg        irq_enable;
    reg        irq_pending;

    // Core connections
    wire [511:0] block_in;
    wire [255:0] hash_out;
    wire ready;
    wire hash_valid;
    reg  hash_valid_d;

    wire write_en = avs_chipselect & avs_write;
    wire read_en  = avs_chipselect & avs_read;

    // Combine 16x32-bit registers into 512-bit block_in
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : gen_block_in
            assign block_in[(15 - i) * 32 +: 32] = data_in_regs[i];
        end
    endgenerate

    // Instantiation of the SHA-256 Core
    sha256_core u_sha256_core (
        .clk        (clk),
        .rst_n      (reset_n),
        .start      (start_reg),
        .init       (init_reg),
        .block_in   (block_in),
        .ready      (ready),
        .hash_valid (hash_valid),
        .hash_out   (hash_out)
    );

    // Avalon-MM Write Logic
    integer j;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            for (j = 0; j < 16; j = j + 1) begin
                data_in_regs[j] <= 32'd0;
            end
            start_reg    <= 1'b0;
            init_reg     <= 1'b1;
            irq_enable   <= 1'b0;
            irq_pending  <= 1'b0;
            hash_valid_d <= 1'b0;
        end else begin
            start_reg <= 1'b0;
            hash_valid_d <= hash_valid;

            if (hash_valid & ~hash_valid_d)
                irq_pending <= 1'b1;

            if (write_en) begin
                if (avs_address <= 5'd15) begin
                    if (avs_byteenable[0]) data_in_regs[avs_address][7:0]   <= avs_writedata[7:0];
                    if (avs_byteenable[1]) data_in_regs[avs_address][15:8]  <= avs_writedata[15:8];
                    if (avs_byteenable[2]) data_in_regs[avs_address][23:16] <= avs_writedata[23:16];
                    if (avs_byteenable[3]) data_in_regs[avs_address][31:24] <= avs_writedata[31:24];
                end else if (avs_address == 5'd16) begin
                    if (avs_byteenable[0]) begin
                        start_reg  <= avs_writedata[0] & ready;
                        init_reg   <= avs_writedata[1];
                        irq_enable <= avs_writedata[2];
                    end
                end else if (avs_address == 5'd17) begin
                    if (avs_byteenable[0] && avs_writedata[2])
                        irq_pending <= 1'b0;
                end
            end
        end
    end

    // Avalon-MM Read Logic
    always @(*) begin
        avs_readdata = 32'd0;
        if (read_en) begin
            if (avs_address <= 5'd15) begin
                avs_readdata = data_in_regs[avs_address];
            end else if (avs_address == 5'd16) begin
                avs_readdata = {29'd0, irq_enable, init_reg, 1'b0};
            end else if (avs_address == 5'd17) begin
                avs_readdata = {29'd0, irq_pending, (hash_valid | irq_pending), ready};
            end else if (avs_address >= 5'd18 && avs_address <= 5'd25) begin
                case (avs_address)
                    5'd18: avs_readdata = hash_out[255:224];
                    5'd19: avs_readdata = hash_out[223:192];
                    5'd20: avs_readdata = hash_out[191:160];
                    5'd21: avs_readdata = hash_out[159:128];
                    5'd22: avs_readdata = hash_out[127:96];
                    5'd23: avs_readdata = hash_out[95:64];
                    5'd24: avs_readdata = hash_out[63:32];
                    5'd25: avs_readdata = hash_out[31:0];
                endcase
            end
        end
    end

    // Allow Avalon bus to proceed immediately (no wait states for register access)
    assign avs_waitrequest = 1'b0;
    assign irq = irq_enable & irq_pending;

endmodule
