class sha256_base_test extends uvm_test;
    `uvm_component_utils(sha256_base_test)
    sha256_env env;

    function new(string name="sha256_base_test", uvm_component parent=null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = sha256_env::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        // Base test run_phase can be empty or handle background tasks
        super.run_phase(phase);
    endtask
endclass

class sha256_sanity_test extends sha256_base_test;
    `uvm_component_utils(sha256_sanity_test)

    function new(string name="sha256_sanity_test", uvm_component parent=null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        sha256_sanity_sequence seq = sha256_sanity_sequence::type_id::create("seq");
        
        phase.raise_objection(this);
        // Run the sanity sequence
        seq.start(env.agent.sequencer);
        #100;
        phase.drop_objection(this);
    endtask
endclass

class sha256_with_masktest extends sha256_base_test;
    `uvm_component_utils(sha256_with_masktest)
     function new(string name="sha256_with_masktest", uvm_component parent=null);
        super.new(name, parent);
    endfunction
    virtual task run_phase(uvm_phase phase);
        sha256_test_avsByteEnable seq = sha256_test_avsByteEnable::type_id::create("seq");
        
        phase.raise_objection(this);
        // Run the sanity sequence
        seq.start(env.agent.sequencer);
        #100;
        phase.drop_objection(this);
    endtask

endclass