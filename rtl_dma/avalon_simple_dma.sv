module avalon_simple_dma (
    input  wire        clk,
    input  wire        reset_n,

    input  wire        avs_chipselect,
    input  wire [2:0]  avs_address,
    input  wire        avs_read,
    output reg  [31:0] avs_readdata,
    input  wire        avs_write,
    input  wire [3:0]  avs_byteenable,
    input  wire [31:0] avs_writedata,
    output wire        avs_waitrequest,
    output wire        irq,

    output reg  [31:0] avm_address,
    output reg         avm_read,
    input  wire [31:0] avm_readdata,
    input  wire        avm_readdatavalid,
    output reg         avm_write,
    output reg  [31:0] avm_writedata,
    output reg  [3:0]  avm_byteenable,
    input  wire        avm_waitrequest
);

    localparam REG_CONTROL = 3'd0; // bit0 start, bit1 irq_enable
    localparam REG_STATUS  = 3'd1; // bit0 busy, bit1 done
    localparam REG_SRC     = 3'd2;
    localparam REG_DST     = 3'd3;
    localparam REG_LEN     = 3'd4; // bytes

    localparam S_IDLE      = 3'd0;
    localparam S_READ_REQ  = 3'd1;
    localparam S_READ_WAIT = 3'd2;
    localparam S_WRITE_REQ = 3'd3;
    localparam S_DONE      = 3'd4;

    reg [2:0]  state;
    reg [31:0] src_addr;
    reg [31:0] dst_addr;
    reg [31:0] length_bytes;
    reg [31:0] bytes_left;
    reg [31:0] read_data_hold;
    reg        irq_enable;
    reg        done;

    wire slave_write = avs_chipselect & avs_write;
    wire slave_read  = avs_chipselect & avs_read;
    wire busy        = (state != S_IDLE) && (state != S_DONE);
    wire start_pulse = slave_write && (avs_address == REG_CONTROL) && avs_byteenable[0] && avs_writedata[0];

    function [3:0] byteenable_for_count;
        input [31:0] count;
        begin
            if (count >= 32'd4)
                byteenable_for_count = 4'b1111;
            else begin
                case (count[1:0])
                    2'd1: byteenable_for_count = 4'b0001;
                    2'd2: byteenable_for_count = 4'b0011;
                    2'd3: byteenable_for_count = 4'b0111;
                    default: byteenable_for_count = 4'b0000;
                endcase
            end
        end
    endfunction

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state         <= S_IDLE;
            src_addr      <= 32'd0;
            dst_addr      <= 32'd0;
            length_bytes  <= 32'd0;
            bytes_left    <= 32'd0;
            read_data_hold <= 32'd0;
            irq_enable    <= 1'b0;
            done          <= 1'b0;
            avm_address   <= 32'd0;
            avm_read      <= 1'b0;
            avm_write     <= 1'b0;
            avm_writedata <= 32'd0;
            avm_byteenable <= 4'hf;
        end else begin
            avm_read  <= 1'b0;
            avm_write <= 1'b0;

            if (slave_write) begin
                case (avs_address)
                    REG_CONTROL: begin
                        if (avs_byteenable[0])
                            irq_enable <= avs_writedata[1];
                    end
                    REG_STATUS: begin
                        if (avs_byteenable[0] && avs_writedata[1])
                            done <= 1'b0;
                    end
                    REG_SRC: begin
                        if (avs_byteenable[0]) src_addr[7:0]   <= avs_writedata[7:0];
                        if (avs_byteenable[1]) src_addr[15:8]  <= avs_writedata[15:8];
                        if (avs_byteenable[2]) src_addr[23:16] <= avs_writedata[23:16];
                        if (avs_byteenable[3]) src_addr[31:24] <= avs_writedata[31:24];
                    end
                    REG_DST: begin
                        if (avs_byteenable[0]) dst_addr[7:0]   <= avs_writedata[7:0];
                        if (avs_byteenable[1]) dst_addr[15:8]  <= avs_writedata[15:8];
                        if (avs_byteenable[2]) dst_addr[23:16] <= avs_writedata[23:16];
                        if (avs_byteenable[3]) dst_addr[31:24] <= avs_writedata[31:24];
                    end
                    REG_LEN: begin
                        if (avs_byteenable[0]) length_bytes[7:0]   <= avs_writedata[7:0];
                        if (avs_byteenable[1]) length_bytes[15:8]  <= avs_writedata[15:8];
                        if (avs_byteenable[2]) length_bytes[23:16] <= avs_writedata[23:16];
                        if (avs_byteenable[3]) length_bytes[31:24] <= avs_writedata[31:24];
                    end
                    default: ;
                endcase
            end

            case (state)
                S_IDLE: begin
                    if (start_pulse && (length_bytes != 32'd0)) begin
                        done       <= 1'b0;
                        bytes_left <= length_bytes;
                        state      <= S_READ_REQ;
                    end
                end

                S_READ_REQ: begin
                    avm_address <= src_addr;
                    avm_read    <= 1'b1;
                    if (!avm_waitrequest)
                        state <= S_READ_WAIT;
                end

                S_READ_WAIT: begin
                    if (avm_readdatavalid) begin
                        read_data_hold <= avm_readdata;
                        state <= S_WRITE_REQ;
                    end
                end

                S_WRITE_REQ: begin
                    avm_address    <= dst_addr;
                    avm_writedata  <= read_data_hold;
                    avm_byteenable <= byteenable_for_count(bytes_left);
                    avm_write      <= 1'b1;
                    if (!avm_waitrequest) begin
                        if (bytes_left <= 32'd4) begin
                            bytes_left <= 32'd0;
                            done       <= 1'b1;
                            state      <= S_DONE;
                        end else begin
                            bytes_left <= bytes_left - 32'd4;
                            src_addr   <= src_addr + 32'd4;
                            dst_addr   <= dst_addr + 32'd4;
                            state      <= S_READ_REQ;
                        end
                    end
                end

                S_DONE: begin
                    if (start_pulse && (length_bytes != 32'd0)) begin
                        done       <= 1'b0;
                        bytes_left <= length_bytes;
                        state      <= S_READ_REQ;
                    end else if (slave_write && (avs_address == REG_STATUS) && avs_byteenable[0] && avs_writedata[1]) begin
                        state <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    always @(*) begin
        avs_readdata = 32'd0;
        if (slave_read) begin
            case (avs_address)
                REG_CONTROL: avs_readdata = {30'd0, irq_enable, 1'b0};
                REG_STATUS:  avs_readdata = {30'd0, done, busy};
                REG_SRC:     avs_readdata = src_addr;
                REG_DST:     avs_readdata = dst_addr;
                REG_LEN:     avs_readdata = length_bytes;
                default:     avs_readdata = 32'd0;
            endcase
        end
    end

    assign avs_waitrequest = 1'b0;
    assign irq = irq_enable & done;

endmodule
