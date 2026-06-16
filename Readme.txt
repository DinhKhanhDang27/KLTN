- SHA256 ip including Core & Wrapper
- CPU RISCV 64 bit
- DE0 Nano kit cyclone IV E EP4ce22f17c6
- SDRAM CONTROLLER - SDRAM 32MB
- dự án dùng SystemVerilog 
- Avalon - Bridge -  AXI4 //Cái này nên xem lại
- DMA 
- Dùng interupt để báo cho riscv thay vì polling
- Phần mềm có cần RTOS không? // cái này nên xem lại
- code C không dùng nios II esclip thì dùng gì? // cái này nên xem lại


=======================================
Các IP bạn có thể add trực tiếp từ Qsys:
On-Chip Memory (RAM or ROM)group: Memories and Memory Controllers/On-Chip
JTAG UARTgroup: Interface Protocols/Serial
SDRAM Controllergroup: Memories and Memory Controllers/External Memory Interfaces/SDRAM Interfaces
DMA Controllergroup: Bridges and Adapters/DMA
Scatter-Gather DMA Controllergroup: Bridges and Adapters/DMA


Khuyến nghị cho hệ thống của bạn:
Custom:
- RISC-V wrapper: AXI4 master
- DMA: tự code AXI4 master + AXI slave control
- SHA wrapper: AXI slave control + stream/input data từ DMA

Qsys IP:
- On-Chip Memory
- JTAG UART
- SDRAM Controller
- Qsys interconnect tự sinh adapter/bridge AXI <-> Avalon