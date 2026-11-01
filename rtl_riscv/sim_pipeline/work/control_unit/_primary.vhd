library verilog;
use verilog.vl_types.all;
entity control_unit is
    port(
        opcode          : in     vl_logic_vector(6 downto 0);
        funct3          : in     vl_logic_vector(2 downto 0);
        funct7          : in     vl_logic_vector(6 downto 0);
        branch          : out    vl_logic;
        mem_read        : out    vl_logic;
        mem_to_reg      : out    vl_logic;
        alu_op          : out    vl_logic_vector(1 downto 0);
        mem_write       : out    vl_logic;
        alu_src         : out    vl_logic;
        reg_write       : out    vl_logic;
        jump            : out    vl_logic;
        jalr            : out    vl_logic
    );
end control_unit;
