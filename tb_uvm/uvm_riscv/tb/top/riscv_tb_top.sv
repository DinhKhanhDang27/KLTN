// tb/top/riscv_tb_top.sv — top mô phỏng Lab 1 (chưa có UVM)
`timescale 1ns/1ps

module riscv_tb_top;

  logic clk = 0;
  always #5 clk = ~clk;          // chu kỳ 10ns

  // Interface
  riscv_if vif (.clk(clk));

  // DUT: pipeline, cùng ports như single-cycle riscv_top
  riscv_pipeline_top dut (
    .clk            (clk),
    .rst            (vif.rst),
    .out_pc         (),
    .out_alu_result ()
  );

  // ---- Probe thô ----
  assign vif.pc_if         = dut.pc_if;
  assign vif.alu_result_ex = dut.alu_result_ex;
  assign vif.stall         = dut.stall;
  assign vif.redirect      = dut.redirect;

  // ======================================================================
  //  SHADOW PIPELINE — tái dựng retire mà KHÔNG sửa DUT.
  //  Mỗi tầng ta giữ song song: valid + pc + instr, đi theo đúng điều kiện
  //  bubble/flush của riscv_pipeline_top.
  //    insert_bubble(ID/EX) = redirect | stall   (rst xử lý ở nhánh reset)
  //    EX/MEM luôn tiến (top dùng bộ nhớ single-cycle, không có mem_stall)
  //  Thông tin store của lệnh đang ở MEM (dut.exmem_*) được chốt sang MEM/WB.
  // ======================================================================
  logic        s_idex_valid,  s_exmem_valid,  s_memwb_valid;
  logic [31:0] s_idex_pc,      s_exmem_pc,     s_memwb_pc;
  logic [31:0] s_idex_instr,   s_exmem_instr,  s_memwb_instr;
  logic        s_memwb_mwrite;
  logic [31:0] s_memwb_maddr,  s_memwb_mwdata;

  always @(posedge clk or posedge vif.rst) begin
    if (vif.rst) begin
      s_idex_valid  <= 1'b0;
      s_exmem_valid <= 1'b0;
      s_memwb_valid <= 1'b0;
    end else begin
      // --- ID/EX: mirror idex_valid_r ---
      s_idex_valid <= (dut.redirect | dut.stall) ? 1'b0 : dut.ifid_valid;
      s_idex_pc    <= dut.ifid_pc;
      s_idex_instr <= dut.ifid_instr;
      // --- EX/MEM: luôn tiến ---
      s_exmem_valid <= s_idex_valid;
      s_exmem_pc    <= s_idex_pc;
      s_exmem_instr <= s_idex_instr;
      // --- MEM/WB: chốt cả thông tin store của lệnh vừa qua MEM ---
      s_memwb_valid  <= s_exmem_valid;
      s_memwb_pc     <= s_exmem_pc;
      s_memwb_instr  <= s_exmem_instr;
      s_memwb_mwrite <= dut.exmem_mem_write;
      s_memwb_maddr  <= dut.exmem_alu_result;
      s_memwb_mwdata <= dut.exmem_store_data;
    end
  end

  // ---- Lái cổng retire của interface (tổ hợp, ở tầng WB) ----
  assign vif.ret_valid     = s_memwb_valid;
  assign vif.ret_pc        = s_memwb_pc;
  assign vif.ret_instr     = s_memwb_instr;
  assign vif.ret_reg_write = dut.memwb_reg_write_r;
  assign vif.ret_rd        = dut.memwb_rd_r;
  assign vif.ret_wb_data   = dut.memwb_wb_value_r;
  assign vif.ret_mem_write = s_memwb_mwrite;
  assign vif.ret_mem_addr  = s_memwb_maddr;
  assign vif.ret_mem_wdata = s_memwb_mwdata;

  // ---- Smoke test: nạp chương trình, nhả reset, in mỗi lần retire ----
  initial begin
    vif.rst = 1'b1;
    vif.clear_imem();
    // addi x1,x0,5 ; addi x2,x1,3 ; add x3,x1,x2 ; jal x0,0 (loop)
    vif.load_instr(0, 32'h00500093);
    vif.load_instr(1, 32'h00308113);
    vif.load_instr(2, 32'h002081b3);
    vif.load_instr(3, 32'h0000006f);
    repeat (2) @(posedge clk);
    vif.rst = 1'b0;

    repeat (12) @(posedge clk) begin
      if (vif.ret_valid)
        $display("[%0t] RETIRE pc=0x%08h instr=0x%08h rw=%b rd=x%0d wb=0x%08h",
                 $time, vif.ret_pc, vif.ret_instr, vif.ret_reg_write, vif.ret_rd, vif.ret_wb_data);
    end
    $display("x1=%0d x2=%0d x3=%0d (mong 5, 8, 13)",
             vif.peek_reg(1), vif.peek_reg(2), vif.peek_reg(3));
    $finish;
  end

endmodule