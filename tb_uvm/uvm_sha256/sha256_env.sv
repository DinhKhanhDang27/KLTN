class sha256_env extends uvm_env;
    `uvm_component_utils(sha256_env)
    sha256_agent agent;
    sha256_scoreboard scoreboard;

    function new(string name="sha256_env", uvm_component parent=null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = sha256_agent::type_id::create("agent", this);
        scoreboard = sha256_scoreboard::type_id::create("scoreboard", this);
    endfunction
    
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent.monitor.ap.connect(scoreboard.ap_imp);
    endfunction
endclass
