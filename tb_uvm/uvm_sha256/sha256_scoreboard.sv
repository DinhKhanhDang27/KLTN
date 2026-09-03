// Import DPI-C functions from sha256_ref.c
import "DPI-C" function void c_sha256_hw_init();
import "DPI-C" function void c_sha256_hw_process(input int block_in[16]);
import "DPI-C" function void c_sha256_hw_get_hash(output int hash_out[8]);

class sha256_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(sha256_scoreboard)

    uvm_analysis_imp#(sha256_seq_item, sha256_scoreboard) ap_imp;

    // Buffer to hold the 16 32-bit words written to the core
    int block_data[16];
    
    // Expected hash from the C Reference Model
    int expected_hash[8];

    function new(string name="sha256_scoreboard", uvm_component parent=null);
        super.new(name, parent);
        ap_imp = new("ap_imp", this);
    endfunction

    virtual function void write(sha256_seq_item item);
        
        // --- CAPTURE WRITES TO BUILD THE C MODEL STATE ---
        if (item.op == WRITE || item.op == WRITE_MASK) begin
            // 1. Data Block registers (addr 0 to 15)
            if (item.addr >= 5'd0 && item.addr <= 5'd15) begin
                logic [31:0] current_val;
                logic [31:0] new_val;
                current_val = block_data[item.addr];
                new_val = current_val;
                
                if (item.avsByteEnable[0]) new_val[7:0]   = item.data[7:0];
                if (item.avsByteEnable[1]) new_val[15:8]  = item.data[15:8];
                if (item.avsByteEnable[2]) new_val[23:16] = item.data[23:16];
                if (item.avsByteEnable[3]) new_val[31:24] = item.data[31:24];
                
                block_data[item.addr] = new_val;
            end 
            // 2. Control Register (addr 16)
            else if (item.addr == 5'd16) begin
                if (item.data[1]) begin
                    // init=1
                    `uvm_info("SCOREBOARD", "C-Model: Initializing state", UVM_HIGH)
                    c_sha256_hw_init();
                end
                if (item.data[0]) begin
                    // start=1
                    `uvm_info("SCOREBOARD", "C-Model: Processing block", UVM_HIGH)
                    c_sha256_hw_process(block_data);
                    c_sha256_hw_get_hash(expected_hash);
                end
            end
        end

        // --- COMPARE HARDWARE OUTPUT (READS) WITH EXPECTED HASH ---
        if (item.op == READ && item.addr >= 5'd18 && item.addr <= 5'd25) begin
            int word_idx = item.addr - 18; 
            logic [31:0] exp_data = expected_hash[word_idx];
            
            if (item.rdata === exp_data) begin
                `uvm_info("SCOREBOARD", $sformatf("[PASS] Hash Word %0d match! Expected: %08x == Actual: %08x", word_idx, exp_data, item.rdata), UVM_LOW)
            end else begin
                `uvm_error("SCOREBOARD", $sformatf("[FAIL] Hash Word %0d MISMATCH! Expected: %08x != Actual: %08x", word_idx, exp_data, item.rdata))
            end
            if (word_idx == 7 ) begin
                `uvm_info("SCOREBOARD", $sformatf("[PASS] 1 testcase"), UVM_LOW)
                end

        end

    endfunction
endclass
