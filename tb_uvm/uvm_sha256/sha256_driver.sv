class sha256_driver extends uvm_driver#(sha256_seq_item);
    `uvm_component_utils(sha256_driver)
    virtual sha256_if vif;

    function new(string name="sha256_driver", uvm_component parent=null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual sha256_if)::get(this, "", "vif", vif))
            `uvm_fatal("NO_VIF", {"virtual interface must be set for: ", get_full_name(), ".vif"});
    endfunction

    virtual task run_phase(uvm_phase phase);
        vif.avs_chipselect <= 0;
        vif.avs_read <= 0;
        vif.avs_write <= 0;
        vif.avs_byteenable <= 4'hf;
        wait(vif.reset_n);
        forever begin
            seq_item_port.get_next_item(req);
            @(posedge vif.clk);
            vif.avs_chipselect <= 1;
            vif.avs_address <= req.addr;
            if(req.op == WRITE) begin
                vif.avs_byteenable <= 4'hf;
                vif.avs_write <= 1;
                vif.avs_writedata <= req.data;
                @(posedge vif.clk);
                vif.avs_write <= 0;
            end else if (req.op == WRITE_MASK) begin 
                vif.avs_byteenable <= req.avsByteEnable;
                vif.avs_write <= 1;
                vif.avs_writedata <= req.data;
                @(posedge vif.clk);
                vif.avs_write <= 0;
            end else begin
                vif.avs_read <= 1;
                @(posedge vif.clk);
                req.rdata = vif.avs_readdata;
                vif.avs_read <= 0;
            end
            vif.avs_chipselect <= 0;
            seq_item_port.item_done();
        end
    endtask
endclass
