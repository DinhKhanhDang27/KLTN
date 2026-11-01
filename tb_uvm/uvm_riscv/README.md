# UVM RISC-V Speedrun — 15 Labs verify core RV32I bằng UVM

Bộ 15 bài lab (`labs/lab01.html … labs/lab15.html`) hướng dẫn **verify con RISC-V trong dự án này**
(`code/rtl_riscv/`) bằng UVM từ con số 0. Phỏng theo bộ AXI4 speedrun
(`/home/dinhkhanhdang/Study/DV/UVM_BASE_SPEEDRUN`) nhưng DUT là **CPU pipeline 5 tầng RV32I (subset)**
(`riscv_pipeline_top`), nên khung verify đổi cho hợp: transaction = **1 lệnh (instruction)**, có
**reference model (ISS)** và **white-box backdoor** (nạp chương trình + đọc regfile/memory qua hierarchical
reference), cộng **tái dựng retire (RVFI-lite)** vì pipeline không mang PC/instruction xuống tầng WB.

## DUT (nhắc lại đặc tả) — pipeline
- `riscv_pipeline_top(input clk, input rst, output [31:0] out_pc, output [31:0] out_alu_result)` — 5 tầng
  IF→ID→EX→MEM→WB, **cùng ports** như single-cycle `riscv_top` (drop-in). Hazard: forwarding (EX/MEM,
  MEM/WB→EX), load-use stall 1 chu kỳ, branch/jump giải ở EX + flush IF/ID + ID/EX.
- Reset active-high (async-assert), PC=0 sau reset; một lệnh mất ~5 chu kỳ mới commit ở WB.
- Register file: 32×32-bit, `x0`=0, **ghi ở negedge clk** (write-first cho ID); đọc tổ hợp.
- Instruction memory: ROM nạp bằng `$readmemh`, địa chỉ theo word `mem[addr[11:2]]` (instance `u_imem`).
- Data memory: 2048 byte, **chỉ LW/SW (word)**, truy cập ở tầng MEM (instance `u_dmem`), single-cycle.
- **Không** có `sha256` trong pipeline (SoC thật dùng `sha256_avalon_wrapper` qua bus). Bản
  `riscv_avalon_wrapper` (bọc `riscv_pipeline_core`) phơi data-memory qua Avalon-MM — DUT nâng cao ở Lab 15.
- Tập lệnh được RTL hỗ trợ (coverage target, 19 lệnh):
  `add sub and or xor sll srl sra slt sltu` · `addi andi ori xori slli srli srai slti sltiu`
  · `lw sw` · `beq bne blt bge bltu bgeu` · `jal jalr lui auipc`.
- KHÔNG hỗ trợ: `lb/lh/lbu/lhu/sb/sh`, `fence`, `ecall/ebreak`, CSR, M/C extension → out-of-scope (test âm ở Lab 14).

## Lộ trình 15 labs
| Lab | Nội dung | Sản phẩm chính |
|----|----------|----------------|
| 01 | Interface + clocking + modport + backdoor hooks + **shadow pipeline tái dựng retire (RVFI-lite)** | `riscv_if.sv`, `riscv_tb_top.sv` |
| 02 | Sequence item = 1 lệnh RV32I; rand field + constraint sinh lệnh hợp lệ; encode 32-bit | `riscv_seq_item.sv` |
| 03 | Driver: reset DUT, backdoor nạp chương trình, cho chạy từng chu kỳ | `riscv_driver.sv` |
| 04 | Monitor: sample PC/instruction/retire writeback mỗi chu kỳ → analysis port | `riscv_monitor.sv` |
| 05 | Agent + config + package + env + base_test | khung env/agent/test/pkg |
| 06 | Sequences framework: 1 seq cho mỗi lớp lệnh (R/I/Load-Store/Branch/Jump/LUI-AUIPC) | `riscv_*_seq.sv` |
| 07 | Virtual sequencer/sequence: ghép chương trình hỗn hợp + reset | `riscv_virtual_*` |
| 08 | SVA: PC+4, x0≡0, không ghi reg khi `reg_write`=0, align | `riscv_protocol_checker.sv` |
| 09 | Reference model ISS RV32I (golden) dự đoán state | `riscv_ref_model.sv` |
| 10 | Scoreboard in-order: so DUT retire vs ISS | `riscv_scoreboard.sv` |
| 11 | Scoreboard đầy đủ: regfile + PC + memory, self-check chương trình ngẫu nhiên | SB nâng cấp |
| 12 | Functional coverage: covergroup 19 lệnh + cross funct3/funct7 + branch taken/not | `riscv_coverage.sv` |
| 13 | "RAL-like": map data-memory / SHA regs, frontdoor (LW/SW) vs backdoor | `riscv_mem_regmodel.sv` |
| 14 | Factory override + negative test: opcode không hỗ trợ (→NOP), ghi x0, misalign | negative test |
| 15 | Top-level + regression + coverage merge + chạy firmware thật end-to-end + verification plan | portfolio |

## Cách dùng
Mở `labs/index.html` (lộ trình + bản đồ kỹ năng UVM + tiến độ), rồi vào từng `labs/labNN.html`.
Mỗi lab: code FULL trong spoiler (không skeleton), lệnh Vivado 2023.2 (`xvlog/xelab/xsim`) từng lệnh một
kèm expected log, ≥5 iteration "code → change → compare", baseline sạch cho lab sau, và — **thiên về UVM**
(giả định bạn đã biết RISC-V, phần ISA được gấp vào mục "RISC-V recap"):
- **Trọng tâm UVM** đầu lab + mục lý thuyết "UVM bên trong" (cơ chế, bẫy, cách debug bằng plusarg).
- **Mục 12:** 8 câu phỏng vấn UVM/lab, bấm để xem đáp án có ví dụ code/log.
- **Mục 14:** 8 bài tập code & câu hỏi nâng cao UVM/lab (★ → ★★★), có gợi ý/đáp án tham khảo.

Giao diện dùng chung: `labs/assets/lab.css` (design tokens sáng/tối, responsive, print) và `labs/assets/lab.js`
(mục lục cuộn theo, tô màu code SystemVerilog/UVM + nút Copy, lưu tick checklist/bài tập/lab hoàn thành vào
`localStorage`, phím tắt `[` `]` chuyển lab). Trang vẫn đọc được khi tắt JS. Mở qua file hoặc
`python3 -m http.server` trong `labs/` đều được.

> Đã sửa trong code mẫu: `vif.mon.ret_cb`/`vif.drv.rst` → `vif.ret_cb`/`vif.rst` (clocking block là member
> của interface, không phải của modport); `encode()` thành `virtual` (để factory override có hiệu lực);
> driver thực sự `get` `drain`; bỏ dòng không hợp lệ trong `riscv_vseq`; checker SVA dùng `$error`;
> `regress.sh` khớp đúng định dạng summary của UVM và kiểm cả `UVM_FATAL`.

> Nạp môi trường trước: `source /tools/Xilinx/Vivado/2023.2/settings64.sh` → có `xvlog/xelab/xsim`.
> Luôn `-L uvm` (Vivado 2023.2 kèm UVM 1.2). Thư mục làm việc: `sim/`.

Xem `MASTER_SPEC_RISCV.md` để biết "luật chơi" format/flow dùng chung cho 15 lab.
