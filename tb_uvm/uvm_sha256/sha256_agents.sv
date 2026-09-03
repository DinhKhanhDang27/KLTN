class sha256_agent extends uvm_agent;
    `uvm_component_utils(sha256_agent)
    sha256_driver driver;
    sha256_sequencer sequencer;
    sha256_monitor monitor;

    function new(string name="sha256_agent", uvm_component parent=null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        driver = sha256_driver::type_id::create("driver", this);
        sequencer = sha256_sequencer::type_id::create("sequencer", this);
        monitor = sha256_monitor::type_id::create("monitor", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction
endclass
