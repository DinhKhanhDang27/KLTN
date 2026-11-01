library verilog;
use verilog.vl_types.all;
entity branch_control is
    port(
        branch          : in     vl_logic;
        funct3          : in     vl_logic_vector(2 downto 0);
        alu_result      : in     vl_logic_vector(31 downto 0);
        zero            : in     vl_logic;
        branch_taken    : out    vl_logic
    );
end branch_control;
