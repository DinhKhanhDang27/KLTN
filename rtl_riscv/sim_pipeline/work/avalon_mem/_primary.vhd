library verilog;
use verilog.vl_types.all;
entity avalon_mem is
    generic(
        RLAT            : integer := 3;
        WLAT            : integer := 2
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        address         : in     vl_logic_vector(31 downto 0);
        read            : in     vl_logic;
        write           : in     vl_logic;
        writedata       : in     vl_logic_vector(31 downto 0);
        byteenable      : in     vl_logic_vector(3 downto 0);
        readdata        : out    vl_logic_vector(31 downto 0);
        readdatavalid   : out    vl_logic;
        waitrequest     : out    vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of RLAT : constant is 1;
    attribute mti_svvh_generic_type of WLAT : constant is 1;
end avalon_mem;
