class sha256_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(sha256_scoreboard)

    uvm_analysis_imp#(sha256_seq_item, sha256_scoreboard) ap_imp;

        // ==========================================
        // [COPY TO SCOREBOARD] EXPECTED HASH (Golden Model)
        // ==========================================
        logic [31:0] expected_hash [8] = '{
            32'h4075b6a6, 32'h8556aaa0, 32'h3188190d, 32'h90619974,
            32'h3692269d, 32'hd8556b03, 32'h4c418f19, 32'h4a70e188
        };
    function new(string name="sha256_scoreboard", uvm_component parent=null);
        super.new(name, parent);
        ap_imp = new("ap_imp", this);
    endfunction

    // Hàm write() sẽ được Monitor gọi mỗi khi bắt được một giao dịch trên bus
    virtual function void write(sha256_seq_item item);
        
        // Chúng ta chỉ quan tâm đến các lệnh ĐỌC từ thanh ghi Hash (địa chỉ 18 đến 25)
        if (item.op == READ && item.addr >= 5'd18 && item.addr <= 5'd25) begin
            int word_idx = item.addr - 18; // Tính toán xem đang đọc Word thứ mấy (0 đến 7)
            logic [31:0] exp_data = expected_hash[word_idx];
            
            // So sánh kết quả thực tế (item.rdata) với kết quả chuẩn (exp_data)
            if (item.rdata === exp_data) begin
                `uvm_info("SCOREBOARD", $sformatf("[PASS] Hash Word %0d chính xác! Expected: %08x == Actual: %08x", word_idx, exp_data, item.rdata), UVM_LOW)
            end else begin
                `uvm_error("SCOREBOARD", $sformatf("[FAIL] Hash Word %0d BỊ SAI! Expected: %08x != Actual: %08x", word_idx, exp_data, item.rdata))
            end
        end
    endfunction
endclass
