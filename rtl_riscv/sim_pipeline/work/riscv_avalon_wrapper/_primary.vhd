library verilog;
use verilog.vl_types.all;
entity riscv_avalon_wrapper is
    port(
        clk             : in     vl_logic;
        reset_n         : in     vl_logic;
        avm_address     : out    vl_logic_vector(31 downto 0);
        avm_read        : out    vl_logic;
        avm_readdata    : in     vl_logic_vector(31 downto 0);
        avm_readdatavalid: in     vl_logic;
        avm_write       : out    vl_logic;
        avm_writedata   : out    vl_logic_vector(31 downto 0);
        avm_byteenable  : out    vl_logic_vector(3 downto 0);
        avm_waitrequest : in     vl_logic;
        out_pc          : out    vl_logic_vector(31 downto 0);
        out_alu_result  : out    vl_logic_vector(31 downto 0)
    );
end riscv_avalon_wrapper;
