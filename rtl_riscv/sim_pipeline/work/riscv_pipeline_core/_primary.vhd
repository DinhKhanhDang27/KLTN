library verilog;
use verilog.vl_types.all;
entity riscv_pipeline_core is
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        dmem_read       : out    vl_logic;
        dmem_write      : out    vl_logic;
        dmem_addr       : out    vl_logic_vector(31 downto 0);
        dmem_wdata      : out    vl_logic_vector(31 downto 0);
        dmem_rdata      : in     vl_logic_vector(31 downto 0);
        dmem_ready      : in     vl_logic;
        out_pc          : out    vl_logic_vector(31 downto 0);
        out_alu_result  : out    vl_logic_vector(31 downto 0)
    );
end riscv_pipeline_core;
