package sha256_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    typedef enum {READ, WRITE, WRITE_MASK} op_t;

    class sha256_seq_item extends uvm_sequence_item;
        rand op_t op;
        rand logic [4:0]  addr;
        rand logic [31:0] data;
        rand logic [3:0] avsByteEnable;
        logic [31:0]      rdata;

        `uvm_object_utils_begin(sha256_seq_item)
            `uvm_field_enum(op_t, op, UVM_ALL_ON)
            `uvm_field_int(addr, UVM_ALL_ON)
            `uvm_field_int(data, UVM_ALL_ON)
            `uvm_field_int(rdata, UVM_ALL_ON)
        `uvm_object_utils_end

        function new(string name = "sha256_seq_item");
            super.new(name);
        endfunction
    endclass

    `include "sha256_sequencer.sv"
    `include "sha256_sequence.sv"
    `include "sha256_driver.sv"
    `include "sha256_monitor.sv"
    `include "sha256_agents.sv"
    `include "sha256_scoreboard.sv"
    `include "sha256_env.sv"
    `include "sha256_test.sv"
endpackage
