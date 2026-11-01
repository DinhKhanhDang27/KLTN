// tb/if/riscv_if.sv — ranh giới UVM ↔ core RISC-V 5-stage pipeline
`ifndef RISCV_IF_SV
`define RISCV_IF_SV

interface riscv_if (input logic clk);

  // ---- Tín hiệu điều khiển TB lái ----
  logic        rst = 1'b1;       // active-high; giữ reset cho tới khi driver nhả

  // ---- Probe thô theo tầng (top assign từ net nội bộ DUT) ----
  logic [31:0] pc_if;            // dut.pc_if         (PC tầng IF)
  logic [31:0] alu_result_ex;    // dut.alu_result_ex (ALU tầng EX)
  logic        stall;            // dut.stall         (load-use stall)
  logic        redirect;         // dut.redirect      (branch/jump taken ở EX)

  // ---- CỔNG RETIRE (RVFI-lite): mô tả lệnh vừa commit ở WB ----
  logic        ret_valid;        // 1 = có 1 lệnh thật commit chu kỳ này
  logic [31:0] ret_pc;           // PC của lệnh commit
  logic [31:0] ret_instr;        // instruction word gốc
  logic        ret_reg_write;    // ghi regfile?
  logic [4:0]  ret_rd;           // thanh ghi đích
  logic [31:0] ret_wb_data;      // dữ liệu writeback
  logic        ret_mem_write;    // store?
  logic [31:0] ret_mem_addr;     // địa chỉ store
  logic [31:0] ret_mem_wdata;    // dữ liệu store

  // ---- Clocking block cho MONITOR: chỉ sample, chống race ----
  clocking ret_cb @(posedge clk);
    default input #1step;
    input ret_valid, ret_pc, ret_instr, ret_reg_write, ret_rd, ret_wb_data;
    input ret_mem_write, ret_mem_addr, ret_mem_wdata;
    input pc_if, alu_result_ex, stall, redirect;
  endclocking

  // ---- Modport ----
  modport mon (clocking ret_cb, input clk, input rst);
  modport drv (input clk, output rst);   // driver cầm reset + gọi backdoor

  // ======================================================================
  //  BACKDOOR HOOKS — hierarchical reference tới DUT.
  //  `dut` được tìm ĐI LÊN từ interface instance, nên chạy với mọi harness (riscv_tb_top, riscv_drv_tb, ...)
  //  miễn là module chứa interface cũng có instance tên `dut`.
  // ======================================================================

  // Ghi 1 lệnh vào ROM tại word-index idx (= địa chỉ byte >> 2).
  task automatic load_instr(input int idx, input logic [31:0] data);
    dut.u_imem.mem[idx] = data;
  endtask

  // Nạp cả file hex (mỗi dòng 1 word theo chuẩn $readmemh).
  task automatic load_hex(input string path);
    $readmemh(path, dut.u_imem.mem);
  endtask

  // Xóa ROM về NOP (addi x0,x0,0 = 0x00000013) để chương trình sạch.
  task automatic clear_imem(input int n = 1024);
    for (int i = 0; i < n; i++) dut.u_imem.mem[i] = 32'h00000013;
  endtask

  // Đọc trộm 1 thanh ghi (x0..x31). x0 luôn 0.
  function automatic logic [31:0] peek_reg(input int r);
    if (r == 0) return 32'd0;
    return dut.u_regfile.registers[r];
  endfunction

  // Đọc trộm 1 word data memory tại địa chỉ byte (căn chỉnh 4).
  function automatic logic [31:0] peek_mem(input int byte_addr);
    int b; b = byte_addr & 11'h7fc;
    return {dut.u_dmem.mem[b+3], dut.u_dmem.mem[b+2],
            dut.u_dmem.mem[b+1], dut.u_dmem.mem[b]};
  endfunction

endinterface
`endif