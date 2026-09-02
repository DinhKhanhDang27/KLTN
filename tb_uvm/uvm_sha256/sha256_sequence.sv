class sha256_base_sequence extends uvm_sequence#(sha256_seq_item);
    `uvm_object_utils(sha256_base_sequence)
    function new(string name="sha256_base_sequence");
        super.new(name);
    endfunction

    task write_reg(logic [4:0] addr, logic [31:0] data);
        req = sha256_seq_item::type_id::create("req");
        start_item(req);
        req.op = WRITE;
        req.addr = addr;
        req.data = data;
        req.avsByteEnable = 4'hf;
        finish_item(req);
    endtask

    task write_reg_with_mask(logic [4:0] addr, logic [31:0] data, logic [3:0] avs_byteenable);
        req = sha256_seq_item::type_id::create("req");
        start_item(req);
        req.op = WRITE_MASK;
        req.addr = addr;
        req.data = data;
        req.avsByteEnable = avs_byteenable;
        finish_item(req);
    endtask

    task read_reg(logic [4:0] addr, output logic [31:0] rdata);
        req = sha256_seq_item::type_id::create("req");
        start_item(req);
        req.op = READ;
        req.addr = addr;
        req.avsByteEnable = 4'hf;
        finish_item(req);
        rdata = req.rdata;
    endtask

    // Virtual body task for base class, can be overridden or empty
    virtual task body();
        `uvm_info("SHA256_SEQ", "Executing base sequence body (empty)", UVM_LOW)
    endtask
endclass

class sha256_sanity_sequence extends sha256_base_sequence;
    `uvm_object_utils(sha256_sanity_sequence)
    
    function new(string name="sha256_sanity_sequence");
        super.new(name);
    endfunction

    virtual task body();

 
        logic [31:0] rdata;

        // --- BLOCK 0 ---
        // Block 0: 61626380
        write_reg(5'd0, 32'h61626380);
        // Block 1..13: 0
        for(int i=1; i<=13; i++) write_reg(i[4:0], 32'h0);
        // Block 14: MSB length
        write_reg(5'd14, 32'h00000000);
        // Block 15: length in bits = 24 = 0x18
        write_reg(5'd15, 32'h00000018);

        // Control (init=1, start=1)
        write_reg(5'd16, 32'h00000003); // bit 0: start, bit 1: init

        // Wait for done
        do begin
            read_reg(5'd17, rdata);
        end while((rdata & 32'h2) == 0); // bit 1 is done/hash_valid

        // Read hash
        for(int i=18; i<=25; i++) begin
            read_reg(i[4:0], rdata);
        end

    endtask
endclass

class sha256_test_avsByteEnable extends sha256_base_sequence;
    `uvm_object_utils(sha256_test_avsByteEnable)
    
    function new(string name="sha256_test_avsByteEnable");
        super.new(name);
    endfunction

    virtual task body();

 
        logic [31:0] rdata2;

        // --- BLOCK 0 ---
        // Block 0: 61626380
        write_reg(5'd0, 32'h00000000);
        write_reg_with_mask(5'd0, 32'h61626380, 4'b0111);
        // Block 1..13: 0
        for(int i=1; i<=13; i++) write_reg(i[4:0], 32'h0);
        // Block 14: MSB length
        write_reg(5'd14, 32'h00000000);
        // Block 15: length in bits = 24 = 0x18
        write_reg(5'd15, 32'h00000018);

        // Control (init=1, start=1)
        write_reg(5'd16, 32'h00000003); // bit 0: start, bit 1: init

        // Wait for done
        do begin
            read_reg(5'd17, rdata2);
        end while((rdata2 & 32'h2) == 0); // bit 1 is done/hash_valid

        // Read hash
        for(int i=18; i<=25; i++) begin
            read_reg(i[4:0], rdata2);
        end

    endtask
endclass //sha26_next_testcase extends superClass

