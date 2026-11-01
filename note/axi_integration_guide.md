# Hướng dẫn thay Avalon bằng AXI4 trong SoC hiện tại

## 0. Các file RTL AXI đã có / vừa viết (trong `rtl_Axi/`)

| File | Vai trò | Trạng thái |
|---|---|---|
| `axi_4_full.sv` | `axi_interconnect` (crossbar chia sẻ, Forencich) | có sẵn |
| `arbiter.sv` | **(mới)** bộ phân xử round-robin mà interconnect cần | **đã thiếu, nay viết** |
| `axi_4_wrapper_riscv.sv` | **(viết lại)** RISC-V → AXI4 master đầy đủ tín hiệu | hoàn chỉnh |
| `axi_4_wrapper_sha256.sv` | **(mới)** SHA-256 → AXI4 slave, giữ nguyên register map | hoàn chỉnh |
| `axi_ram.sv` | **(mới)** RAM AXI4 slave, thay on-chip/SDRAM | hoàn chỉnh |
| `axi_soc_top.sv` | **(mới)** top: CPU → interconnect → {RAM, SHA} | hoàn chỉnh |

Register map SHA giữ nguyên như bản Avalon (firmware không phải đổi):
word0–15 = block (0x00–0x3C), word16 = control (0x40), word17 = status (0x44),
word18–25 = digest (0x48–0x64). Decode offset byte `addr[6:2]`.

---

## Có HAI con đường. Chọn 1.

- **Path A – Platform Designer (KHUYẾN NGHỊ):** để Qsys tự chèn interconnect +
  bộ chuyển đổi AXI↔Avalon. Chỉ cần đổi 2 interface (CPU master, SHA slave)
  sang AXI4; UART/timer/SDRAM/on-chip RAM giữ nguyên IP Avalon. Ít việc nhất,
  đúng tinh thần đồ án (dùng công cụ Vivado/Platform Designer để đóng gói).
- **Path B – Thuần RTL:** tự instantiate `axi_interconnect` qua `axi_soc_top.sv`.
  Phải có AXI slave cho MỌI thiết bị (hoặc cầu AXI→Avalon). Nhiều việc hơn,
  nhưng độc lập công cụ, hợp để mô phỏng/kiểm chứng AXI backbone.

---

## PATH A — Platform Designer (thay interface, giữ IP Avalon)

### A1. Đóng gói lại CPU thành AXI4 master
Tạo `rtl_riscv/riscv_axi_wrapper_hw.tcl` (hoặc sửa bản cũ). Thay khối
`add_interface m0 avalon start` bằng AXI4. Dùng TOP_LEVEL = `axi_4_wrapper_riscv`
và thêm file RTL mới:

```tcl
set_module_property NAME riscv_axi_wrapper
set_fileset_property QUARTUS_SYNTH TOP_LEVEL axi_4_wrapper_riscv
add_fileset_file axi_4_wrapper_riscv.sv SYSTEM_VERILOG PATH ../rtl_Axi/axi_4_wrapper_riscv.sv
# + các file lõi: instruction_memory.sv, control_unit.sv, imm_gen.sv,
#   alu_control.sv, alu.sv, branch_control.sv  (như bản cũ)

add_interface m0 axi4 start
set_interface_property m0 associatedClock clock
set_interface_property m0 associatedReset  reset
set_interface_property m0 readIssuingCapability  1
set_interface_property m0 writeIssuingCapability 1
# map từng port AXI (tên_port  tên_tín_hiệu_AXI  hướng  rộng)
add_interface_port m0 m_axi_awid     awid     Output 8
add_interface_port m0 m_axi_awaddr   awaddr   Output 32
add_interface_port m0 m_axi_awlen    awlen    Output 8
add_interface_port m0 m_axi_awsize   awsize   Output 3
add_interface_port m0 m_axi_awburst  awburst  Output 2
add_interface_port m0 m_axi_awlock   awlock   Output 1
add_interface_port m0 m_axi_awcache  awcache  Output 4
add_interface_port m0 m_axi_awprot   awprot   Output 3
add_interface_port m0 m_axi_awqos    awqos    Output 4
add_interface_port m0 m_axi_awvalid  awvalid  Output 1
add_interface_port m0 m_axi_awready  awready  Input  1
add_interface_port m0 m_axi_wdata    wdata    Output 32
add_interface_port m0 m_axi_wstrb    wstrb    Output 4
add_interface_port m0 m_axi_wlast    wlast    Output 1
add_interface_port m0 m_axi_wvalid   wvalid   Output 1
add_interface_port m0 m_axi_wready   wready   Input  1
add_interface_port m0 m_axi_bid      bid      Input  8
add_interface_port m0 m_axi_bresp    bresp    Input  2
add_interface_port m0 m_axi_bvalid   bvalid   Input  1
add_interface_port m0 m_axi_bready   bready   Output 1
add_interface_port m0 m_axi_arid     arid     Output 8
add_interface_port m0 m_axi_araddr   araddr   Output 32
add_interface_port m0 m_axi_arlen    arlen    Output 8
add_interface_port m0 m_axi_arsize   arsize   Output 3
add_interface_port m0 m_axi_arburst  arburst  Output 2
add_interface_port m0 m_axi_arlock   arlock   Output 1
add_interface_port m0 m_axi_arcache  arcache  Output 4
add_interface_port m0 m_axi_arprot   arprot   Output 3
add_interface_port m0 m_axi_arqos    arqos    Output 4
add_interface_port m0 m_axi_arvalid  arvalid  Output 1
add_interface_port m0 m_axi_arready  arready  Input  1
add_interface_port m0 m_axi_rid      rid      Input  8
add_interface_port m0 m_axi_rdata    rdata    Input  32
add_interface_port m0 m_axi_rresp    rresp    Input  2
add_interface_port m0 m_axi_rlast    rlast    Input  1
add_interface_port m0 m_axi_rvalid   rvalid   Input  1
add_interface_port m0 m_axi_rready   rready   Output 1
```

### A2. Đóng gói SHA thành AXI4 slave
Tạo `rtl_sha256/sha256_axi_wrapper_hw.tcl`, TOP_LEVEL = `axi_4_wrapper_sha256`.
Interface slave:

```tcl
add_interface s0 axi4 end
set_interface_property s0 associatedClock clock
set_interface_property s0 associatedReset  reset
set_interface_property s0 readAcceptanceCapability  1
set_interface_property s0 writeAcceptanceCapability 1
# map s_axi_* tương tự trên nhưng ĐẢO hướng (slave):
#   s_axi_awaddr ... Input, s_axi_awready Output, s_axi_bvalid Output, v.v.
add_interface_port s0 s_axi_awaddr awaddr Input 32
# ... (khai báo đủ như A1 nhưng đổi start→end và đảo in/out)
add_interface irq_conduit conduit end
add_interface_port irq_conduit irq irq Output 1
```

### A3. Trong Platform Designer (Qsys)
1. Mở `system.qsys`. Xoá 2 component cũ `riscv_avalon_wrapper_0`,
   `sha256_avalon_wrapper_0`.
2. Refresh IP catalog, thêm `riscv_axi_wrapper` và `sha256_axi_wrapper`.
3. Nối `clk`, `reset` như cũ.
4. Nối master AXI `m0` của CPU tới các slave:
   - `sha256_axi_wrapper.s0`  (AXI – AXI, trực tiếp)
   - `onchip_memory2_0.s1`, `new_sdram_controller_0.s1`, `timer_0.s1`,
     `jtag_uart_0` (Avalon) → **Qsys tự chèn AXI-to-Avalon adapter**, không cần làm gì thêm.
5. Giữ nguyên **Base Address** cũ để firmware không đổi:
   - on-chip `0x0200_0000`, SHA `0x0200_8000`, timer `0x0200_8080`,
     UART `0x0200_80A0`, SDRAM `0x0000_0000`.
6. Nối `sha256_axi_wrapper.irq_conduit` ra ngoài (hoặc vào CSR `mip` khi CPU đã
   có interrupt).
7. `Generate HDL`. Qsys tự sinh interconnect AXI + adapter.

### A4. Build
- Thêm file `rtl_Axi/*.sv` vào `.qsf` nếu Qsys chưa tự thêm.
- Compile Quartus như cũ. Nạp board, chạy firmware cũ (không cần recompile ASM
  vì memory map giữ nguyên).

> Path A KHÔNG dùng `axi_4_full.sv`/`arbiter.sv`/`axi_ram.sv` của ta — Qsys
> cung cấp interconnect riêng. Các file đó dành cho Path B / mô phỏng.

---

## PATH B — Thuần RTL (dùng `axi_soc_top.sv`)

### B1. Mô phỏng trước (khuyến nghị)
Biên dịch toàn bộ để kiểm tra đấu nối:

```bash
iverilog -g2012 -o sim.out \
  rtl_Axi/axi_soc_top.sv rtl_Axi/axi_4_full.sv rtl_Axi/arbiter.sv \
  rtl_Axi/axi_4_wrapper_riscv.sv rtl_Axi/axi_4_wrapper_sha256.sv rtl_Axi/axi_ram.sv \
  rtl_riscv/instruction_memory.sv rtl_riscv/control_unit.sv rtl_riscv/imm_gen.sv \
  rtl_riscv/alu_control.sv rtl_riscv/alu.sv rtl_riscv/branch_control.sv \
  rtl_sha256/sha256Core.sv  <testbench.sv>
```

(cần testbench phát clk/reset; chưa có sẵn — xem phần UVM trong tb_uvm/).

### B2. Address map (sửa trong `axi_soc_top.sv`)
Hiện cấu hình:
- M0 RAM  @ `0x0000_0000`, 64 KB (`M_ADDR_WIDTH=16`)
- M1 SHA  @ `0x0200_8000`,  4 KB (`M_ADDR_WIDTH=12`)

Muốn thêm slave (UART/timer): tăng `M_COUNT`, nới `M_BASE_ADDR` và
`M_ADDR_WIDTH` (lưu ý: mỗi vùng tối thiểu width=12 tức 4 KB, base phải căn
theo size), rồi instantiate slave tương ứng và slice bus `m_axi_*[i*W +: W]`.

### B3. Thiếu gì cho Path B đầy đủ
- UART/timer chưa có bản AXI → cần **AXI slave** riêng, hoặc **cầu AXI→Avalon**
  rồi tái dùng IP Avalon cũ (lúc đó lại cần Qsys → nên dùng Path A).
- SDRAM controller tương tự.
- Nạp firmware: `axi_ram` có tham số `INIT_FILE` → đặt `.INIT_FILE("firmware_sdram.hex")`
  cho `u_ram` khi mô phỏng/synthesis.

---

## Lưu ý kỹ thuật (đã xử lý trong RTL, cần biết khi mở rộng)

1. **Load dưới-từ (LB/LH/LBU/LHU):** master hiện đọc nguyên 32-bit (giống bản
   Avalon cũ). Nếu firmware dùng lw/sw word-aligned thì OK. Muốn đúng chuẩn,
   thêm mở rộng dấu theo `funct3` + byte-offset `araddr[1:0]` ở `STATE_R`.
2. **ID/response:** slave echo `bid=awid`, `rid=arid`, luôn trả `OKAY`. Chưa
   phát `SLVERR` khi lỗi — đủ cho hệ hiện tại.
3. **Burst:** master phát single-beat (`awlen=0`). Slave vẫn hỗ trợ INCR burst
   sẵn để sau này DMA (AXI master nhiều beat) dùng được.
4. **Arbiter:** cấu hình round-robin + block-until-ack, đúng cho nhiều master
   (CPU + DMA) khi `S_COUNT>1`.

---

## Phần CÒN LẠI của đồ án (ngoài phạm vi "thay Avalon")
Theo đề cương, kiến trúc đích còn cần (đây là MỤC TIÊU CẢI TIẾN, không bắt buộc
để thay Avalon):
- **DMA controller** (AXI4 master) + **kênh AXI4-Stream** riêng đẩy dữ liệu vào SHA.
- **Unified SHA wrapper (SHA-256/512)** với Stream FIFO + adapter 32→64-bit,
  interface AXI4-Stream slave (`axi_4_stream.sv` hiện đang rỗng).
- **CSR + interrupt** trong CPU (`mtvec/mepc/mcause/mstatus/mip`) nhận
  `dma_done_irq`, `sha_done_irq`.
- Hoàn thiện **UVM** (driver/monitor/scoreboard/sequence/test đang rỗng).
