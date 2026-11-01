# MASTER SPEC — UVM RISC-V Verification Speedrun (15 Labs)

Luật chơi dùng chung cho 15 lab HTML verify core **RV32I single-cycle** trong `code/rtl_riscv/`.
Phỏng theo `UVM_BASE_SPEEDRUN/lab_specs/00_MASTER_SPEC.md`; phần khác biệt vì DUT là CPU:

## 1. Triết lý & format (giữ nguyên bản AXI4)
- "Code → change → compare → repeat": mỗi lab ≥5 iteration, mỗi iteration có full code trong spoiler,
  lệnh chạy, expected log, và "khác biệt so với lần trước".
- Code SV/UVM **FULL, chạy được**, không skeleton/`// TODO`/`...`. Escape HTML (`<`→`&lt;` …) trong spoiler.
- Mỗi lệnh Vivado 1-lệnh/1-block + expected log dạng xsim+UVM 1.2 (không thực chạy, dự đoán hợp lý).
- CSS tối giản (bản AXI4 Mục 2.2), thêm `.toc`. 14 section theo template bản gốc + TOC.
- Mỗi lab: baseline sạch cho lab sau; bảng keyword mới; QA 5–8 câu có ví dụ; cheat-sheet cuối.

## 2. Khác biệt cốt lõi so với AXI4
| Khía cạnh | AXI4 | RISC-V (bộ này) |
|---|---|---|
| DUT có từ lab nào | Lab 9 (slave RAM) | **Có sẵn từ Lab 1** (`riscv_pipeline_top`) — monitor/SB/ISS xây dần |
| Transaction | burst read/write | **1 instruction** (opcode/funct/rs/rd/imm) |
| Giao tiếp | handshake VALID/READY 5 kênh | **không handshake bus**: pipeline 5 tầng, retire ở WB (độ trễ ~5 chu kỳ, có stall/flush) |
| Stimulus vào DUT | driver lái bus | driver **backdoor nạp imem** + điều khiển reset + drain pipeline |
| Quan sát | monitor sample bus | monitor sample **cổng RETIRE tái dựng (RVFI-lite)**: PC+instruction+writeback+mem (white-box) |
| Golden | slave RAM + scoreboard | **ISS reference model** (Lab 9) + scoreboard (Lab 10–11) |
| RAL | CSR qua AXI | map **data-memory/SHA regs** qua LW/SW (Lab 13) |

## 3. Tham số & tên tín hiệu thống nhất (DUT = riscv_pipeline_top)
```
XLEN = 32
riscv_pipeline_top ports:  clk, rst (active-high), out_pc[31:0], out_alu_result[31:0]
  (cùng ports như single-cycle riscv_top — drop-in)
Backdoor path (absolute hierarchical, dùng trong interface):
  riscv_tb_top.dut.u_imem.mem[idx]          // instruction ROM (idx = word index = addr>>2)
  riscv_tb_top.dut.u_regfile.registers[r]   // register file
  riscv_tb_top.dut.u_dmem.mem[byte]         // data memory (byte-addressable)
Probe thô (assign ở top):  pc_if=dut.pc_if  alu_result_ex=dut.alu_result_ex
  stall=dut.stall  redirect=dut.redirect
RETIRE (RVFI-lite) — tái dựng bằng SHADOW PIPELINE trong riscv_tb_top (KHÔNG sửa DUT):
  shadow valid/pc/instr qua ID/EX->EX/MEM->MEM/WB; bubble = dut.redirect|dut.stall
  ret_valid=s_memwb_valid  ret_pc=s_memwb_pc  ret_instr=s_memwb_instr
  ret_reg_write=dut.memwb_reg_write_r  ret_rd=dut.memwb_rd_r  ret_wb_data=dut.memwb_wb_value_r
  ret_mem_write=dut.exmem_mem_write(chốt)  ret_mem_addr=dut.exmem_alu_result  ret_mem_wdata=dut.exmem_store_data
Lưu ý: PC/instruction KHÔNG được RTL mang xuống WB -> phải dựng shadow. Monitor sample khi ret_valid=1.
```

## 4. Flow Vivado 2023.2
```
source /tools/Xilinx/Vivado/2023.2/settings64.sh
cd sim
xvlog -sv ../tb/if/riscv_if.sv
# 11 file RTL pipeline (KHÔNG gồm riscv_top/riscv_avalon_wrapper/riscv_pipeline_core/sha256):
xvlog -sv ../rtl/instruction_memory.sv ../rtl/register_file.sv ../rtl/data_memory.sv \
          ../rtl/control_unit.sv ../rtl/imm_gen.sv ../rtl/alu_control.sv ../rtl/alu.sv \
          ../rtl/branch_control.sv ../rtl/mux.sv ../rtl/adder.sv ../rtl/riscv_pipeline_top.sv
xvlog -sv ../tb/sva/riscv_protocol_checker.sv ../tb/sva/riscv_regfile_checker.sv ../tb/sva/riscv_bind.sv
xvlog -sv -L uvm -i ../tb/agent -i ../tb/seq -i ../tb/ref -i ../tb/sb -i ../tb/cov -i ../tb/ral \
          -i ../tb/env -i ../tb/test ../tb/pkg/riscv_pkg.sv
xvlog -sv -L uvm ../tb/top/riscv_tb_top.sv
xelab -L uvm -timescale 1ns/1ps riscv_tb_top -s top_sim
xsim top_sim -R -testplusarg "UVM_TESTNAME=riscv_base_test"
```

## 5. Quy ước thư mục
```
uvm_riscv/
├── rtl/        -> symlink/sao chép từ ../../rtl_riscv (DUT)
├── tb/
│   ├── if/     riscv_if.sv
│   ├── agent/  riscv_seq_item.sv riscv_agent_config.sv riscv_driver.sv riscv_monitor.sv
│   │           riscv_sequencer.sv riscv_agent.sv
│   ├── seq/    riscv_base_seq.sv riscv_rtype_seq.sv riscv_itype_seq.sv riscv_ls_seq.sv
│   │           riscv_branch_seq.sv riscv_jump_seq.sv riscv_random_prog_seq.sv riscv_virtual_seq.sv
│   ├── ref/    riscv_ref_model.sv          # ISS golden (Lab 9)
│   ├── sva/    riscv_protocol_checker.sv   # Lab 8
│   ├── sb/     riscv_scoreboard.sv         # Lab 10–11
│   ├── cov/    riscv_coverage.sv           # Lab 12
│   ├── ral/    riscv_mem_regmodel.sv       # Lab 13
│   ├── env/    riscv_env.sv riscv_virtual_sequencer.sv
│   ├── test/   riscv_base_test.sv riscv_*_test.sv
│   ├── pkg/    riscv_pkg.sv
│   └── top/    riscv_tb_top.sv
├── sim/        # chạy ở đây
└── scripts/    # Makefile/run.tcl (Lab 15)
```

## 6. Keyword progression
| Lab | SV mới | UVM mới | RISC-V mới |
|---|---|---|---|
| 1 | interface, clocking, modport, hierarchical ref, task/function trong interface, **shadow pipeline** | — | ports core, reset, backdoor imem/regfile, **tái dựng retire (RVFI-lite) ở WB** |
| 2 | class, rand, constraint, enum, `with{}`, function encode, `<<`/`\|` bit pack | uvm_sequence_item, field macros, create | encode 32-bit mỗi format (R/I/S/B/U/J) |
| 3 | virtual task, @(posedge), fork | uvm_driver, get_next_item/item_done, config_db get vif | nạp chương trình + bước chu kỳ |
| 4 | sample tín hiệu, struct | uvm_monitor, analysis_port, write() | dựng retire txn từ probe |
| 5 | package, include guard | uvm_agent, is_active, uvm_sequencer, env, test, config_db set | — |
| 6 | — | uvm_sequence, start_item/finish_item, `uvm_do_with | sequence theo lớp lệnh |
| 7 | — | virtual sequencer/sequence, p_sequencer | chương trình hỗn hợp |
| 8 | property, sequence, `\|->`, $past, $stable, disable iff, bind | SVA bind vào core | bất biến ISA |
| 9 | assoc/dynamic array, function thuần | reference model (không phải uvm_component bắt buộc) | mô phỏng RV32I |
| 10 | uvm_tlm_analysis_fifo, queue [$] | uvm_scoreboard, export, compare | in-order |
| 11 | — | so sánh toàn kiến trúc, UVM_ERROR debug | regfile/mem/pc |
| 12 | covergroup, coverpoint, bins, cross, ignore/illegal_bins | uvm_subscriber | 19 lệnh + corner |
| 13 | — | RAL (uvm_reg_block/map/adapter/predictor), frontdoor/backdoor | map dmem/SHA |
| 14 | — | uvm_callback, factory override | lệnh không hỗ trợ, ghi x0, misalign |
| 15 | Makefile/tcl | regression, coverage merge (xcrg), verif plan | chạy firmware thật |

*Hết. Mỗi labNN.html bám file này về format và bảng §3/§5.*
