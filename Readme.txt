- SHA256 ip including Core & Wrapper
- CPU RISCV 64 bit
- DE0 Nano kit cyclone IV E EP4ce22f17c6
- SDRAM CONTROLLER - SDRAM 32MB
- SystemVerilog 
- Avalon - Bridge -  AXI4 //Cái này nên xem lại
- DMA không?
- Dùng interupt để báo cho riscv thay vì polling
- Phần mềm có cần RTOS không? // cái này nên xem lại
- code C không dùng nios II esclip thì dùng gì? // cái này nên xem lại
==========

********Brainstoming***********
1. Cấu trúc SoC (System on Chip) của hệ thống?
Từ file Readme, hệ thống của bạn là một SoC được xây dựng trên kit DE0 Nano (Cyclone IV E) bằng ngôn ngữ SystemVerilog, với cấu trúc tổng quát gồm các khối chính sau:
1. Bộ xử lý trung tâm (CPU): Core RISC-V 64-bit.
2. Bộ nhớ chính (Memory): SDRAM 32MB, giao tiếp thông qua một khối SDRAM Controller.
3. Bộ tăng tốc phần cứng (Hardware Accelerator): Khối mã hóa SHA256 (bao gồm Core xử lý logic và Wrapper để giao tiếp với hệ thống).
4. Giao thức kết nối (System Interconnect/Bus): Đang cân nhắc giữa Avalon và AXI4.
- Cơ chế điều khiển & Đồng bộ:
Sử dụng Ngắt (Interrupt) để khối SHA báo cho CPU RISC-V biết khi đã tính toán xong (thay vì CPU phải liên tục đọc thanh ghi trạng thái - polling).
Đang cân nhắc sử dụng DMA để truyền dữ liệu trực tiếp từ Bộ nhớ vào khối SHA256 mà không cần CPU can thiệp quá nhiều, giúp tăng tốc độ đáng kể.


2. Có nên dùng AXI Bus không?
Câu trả lời là CÓ NÊN, nhưng cần lưu ý môi trường bạn đang làm việc.
- Vì sao nên dùng AXI4? AXI4 (của ARM) hiện đang là tiêu chuẩn công nghiệp. Hầu hết các core RISC-V mã nguồn mở (như Rocket, BOOM, Pulp...) đều sử dụng AXI4 hoặc AHB làm chuẩn giao tiếp bộ nhớ chính. Nếu bạn tự thiết kế hoặc lấy core RISC-V từ cộng đồng, khả năng cao nó dùng AXI4. Hơn nữa, thiết kế SHA256 bằng AXI4 sẽ giúp IP của bạn có tính tái sử dụng cao (sau này mang sang kit Xilinx/AMD rất dễ).
- Vấn đề với kit DE0 Nano (Intel/Altera): Môi trường của Intel FPGA (Quartus/Platform Designer) hỗ trợ "tận răng" cho bus Avalon. Khối SDRAM Controller mà bạn generate từ Quartus chắc chắn sẽ dùng giao diện Avalon-MM.
=> Khuyến nghị kiến trúc Bus: Bạn nên sử dụng AXI4 làm bus chính cho hệ thống (để CPU RISC-V, DMA, và khối SHA256 kết nối với nhau). Sau đó sử dụng một cầu nối (Bridge) để chuyển đổi từ AXI4 sang Avalon khi cần nói chuyện với SDRAM Controller.


3. Chỉ làm Wrapper cho SHA thôi hay phải làm cả Bridge?
- Bạn sẽ cần làm CẢ HAI, vì chúng phục vụ hai mục đích hoàn toàn khác nhau trong SoC:
- Wrapper cho SHA256: Bắt buộc phải làm. Lõi SHA256 (Core) thường chỉ có các tín hiệu thô như data_in, hash_out, start, done. CPU không thể hiểu các tín hiệu này. Bạn cần một lớp Wrapper để gói các tín hiệu này lại thành một chuẩn giao tiếp chung (ví dụ: AXI4-Lite). Khi đó CPU sẽ điều khiển SHA thông qua việc đọc/ghi vào các địa chỉ thanh ghi cụ thể (Memory-Mapped IO).
- Bridge (AXI to Avalon Bridge): Phải làm (hoặc sử dụng IP có sẵn) nếu CPU RISC-V của bạn dùng AXI4 nhưng SDRAM Controller lại dùng Avalon. Bridge sẽ đóng vai trò như một thông dịch viên: nhận các tín hiệu đọc/ghi chuẩn AXI4 từ CPU và dịch chúng sang tín hiệu đọc/ghi chuẩn Avalon-MM để lấy dữ liệu từ SDRAM, sau đó trả ngược lại.


4. Khối Wrapper nằm trong Bridge hay nằm riêng?
Khối Wrapper phải NẰM RIÊNG và bọc trực tiếp lấy lõi SHA256 của bạn. Chúng không liên quan gì đến Bridge.
- Cấu trúc phân cấp cụ thể sẽ như thế này:
1. Block SHA256 IP:
Nằm độc lập, bao gồm SHA256_Core (xử lý toán học) + SHA256_AXI_Wrapper (chuyển đổi tín hiệu lõi thành chuẩn AXI). Khối này cắm trực tiếp vào AXI Interconnect.
2. Block Bridge (AXI2Avalon):
Là một khối riêng biệt nằm trên đường truyền (Bus) giữa AXI Interconnect (của CPU) và khối SDRAM Controller.
+ Tóm tắt lợi ích của việc tách riêng: Nếu sau này bạn mang khối SHA256 sang một SoC khác thuần AXI (như Xilinx Zynq), bạn chỉ việc bê nguyên khối SHA256 IP (Core + Wrapper) đi mà không cần quan tâm đến Bridge. Tính module (modularity) của phần cứng được đảm bảo.

=====================
1. Ứng dụng của DMA trong hệ thống mã hóa SHA256
Trong đồ án của bạn, CPU RISC-V sẽ cần gửi dữ liệu (ví dụ: một file text hoặc một luồng dữ liệu) từ bộ nhớ chính (SDRAM) vào lõi SHA256 để tiến hành băm (hashing).

Kịch bản không có DMA (CPU tự làm "shipper"):

CPU phải liên tục thực hiện lệnh đọc (Load) dữ liệu từ SDRAM vào thanh ghi của CPU.
Sau đó, CPU lại thực hiện lệnh ghi (Store) dữ liệu từ thanh ghi vào địa chỉ của khối SHA256.
SHA256 xử lý theo block 512-bit (64 byte). Nếu bạn cần băm một file 1MB, CPU phải chạy đi chạy lại việc đọc/ghi hàng vạn lần. Trong lúc làm việc này, CPU không thể làm được việc gì khác, và tốc độ truyền dữ liệu cũng chậm do phải đi qua CPU.


Kịch bản có DMA (DMA làm "shipper" chuyên nghiệp):

DMA giống như một vi điều khiển chuyên dụng chỉ làm nhiệm vụ chuyển đồ.
CPU chỉ cần nói với DMA: "Này DMA, hãy copy 1MB dữ liệu bắt đầu từ địa chỉ X trong SDRAM, nạp thẳng vào địa chỉ Y của khối SHA256 cho tôi".
Sau đó, CPU được giải phóng hoàn toàn và có thể đi làm việc khác.
DMA sẽ tự động nắm quyền điều khiển Bus (AXI/Avalon), kéo dữ liệu với tốc độ cao nhất (burst transfer) trực tiếp từ SDRAM sang SHA256. Khi nào chuyển xong, DMA sẽ gửi một tín hiệu Ngắt (Interrupt) báo cho CPU biết.


2. Ưu và nhược điểm khi đưa DMA vào đồ án
- Ưu điểm:
Tăng tốc độ cực lớn (High Throughput): Khối SHA256 có thể chạy hết công suất vì lúc nào cũng được bơm dữ liệu liên tục.
Giải phóng CPU: CPU có thể chạy hệ điều hành (RTOS) mượt mà hơn, hoặc xử lý các logic khác trong khi dữ liệu đang được mã hóa.
Thể hiện kỹ năng kiến trúc SoC: Việc tích hợp thành công IP (Intellectual Property) DMA, cấu hình Bus đa Master (CPU và DMA cùng tranh chấp Bus), và viết code C điều khiển ngắt sẽ đánh giá năng lực rất tốt trước hội đồng bảo vệ.

- Nhược điểm:
Tăng độ phức tạp phần cứng: Hệ thống Bus (AXI Interconnect) sẽ phức tạp hơn vì lúc này có tới 2 Master (CPU và DMA) muốn truy cập vào các Slave (SDRAM, SHA256).
Tăng độ phức tạp phần mềm: Bạn phải viết thêm Driver (mã C) để cấu hình các thanh ghi của DMA và xử lý ngắt của nó.
Lời khuyên cho tiến độ đồ án của bạn:
Bạn nên áp dụng chiến lược "Phát triển theo từng giai đoạn":

+  Giai đoạn 1 (Bắt buộc phải chạy được): KHÔNG dùng DMA. Hãy để CPU đọc/ghi trực tiếp vào SHA256 Wrapper qua AXI-Lite. Mục đích là để chứng minh core RISC-V, lõi SHA256 và giao tiếp cơ bản (Wrapper/Bridge) hoạt động đúng đắn.
+ Giai đoạn 2 (Nâng cấp tối ưu): Sau khi Phase 1 đã chạy trơn tru, bạn hãy thêm khối DMA vào hệ thống (có thể dùng khối mSGDMA của Quartus hoặc IP DMA mã nguồn mở) để nâng cấp tốc độ và lấy điểm cộng.