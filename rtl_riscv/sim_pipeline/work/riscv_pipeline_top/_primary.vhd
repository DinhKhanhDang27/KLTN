library verilog;
use verilog.vl_types.all;
entity riscv_pipeline_top is
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        out_pc          : out    vl_logic_vector(31 downto 0);
        out_alu_result  : out    vl_logic_vector(31 downto 0)
    );
end riscv_pipeline_top;
