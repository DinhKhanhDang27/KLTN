class sha256_monitor extends uvm_monitor;
    `uvm_component_utils(sha256_monitor)
    
    virtual sha256_if vif;
    uvm_analysis_port#(sha256_seq_item) ap;

    function new(string name="sha256_monitor", uvm_component parent=null);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual sha256_if)::get(this, "", "vif", vif))
            `uvm_fatal("NO_VIF", {"virtual interface must be set for: ", get_full_name(), ".vif"});
    endfunction

    virtual task run_phase(uvm_phase phase);
        sha256_seq_item item;
        wait(vif.reset_n);
        
        forever begin
            @(posedge vif.clk);
            if (vif.avs_chipselect) begin
                if (vif.avs_write) begin
                    item = sha256_seq_item::type_id::create("item");
                    item.op = (vif.avs_byteenable == 4'hf) ? WRITE : WRITE_MASK;
                    item.addr = vif.avs_address;
                    item.data = vif.avs_writedata;
                    item.avsByteEnable = vif.avs_byteenable;
                    ap.write(item);
                end 
                
                if (vif.avs_read) begin
                    item = sha256_seq_item::type_id::create("item");
                    item.op = READ;
                    item.addr = vif.avs_address;
                    item.rdata = vif.avs_readdata;
                    ap.write(item);
                end
            end
        end
    endtask
endclass