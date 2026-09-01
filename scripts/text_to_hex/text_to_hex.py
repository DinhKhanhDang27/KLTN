import sys
import struct
import os
import hashlib

def generate_sequence():
    input_file = 'input_py_text_to_hex.txt'
    output_file = 'output_sequence.txt'
    
    # Kiểm tra file input
    if not os.path.exists(input_file):
        with open(input_file, 'w') as f:
            f.write("abc")
        print(f"Đã tạo file {input_file} mẫu chứa chữ 'abc'.")

    # Đọc dữ liệu (dạng text)
    with open(input_file, 'r', encoding='utf-8') as f:
        text = f.read().strip()
    
    data = text.encode('utf-8')
    orig_len_bits = len(data) * 8

    # Tính toán mã băm chuẩn (Golden Hash) bằng thư viện Python
    real_hash_hex = hashlib.sha256(data).hexdigest()
    hash_words = [real_hash_hex[i:i+8] for i in range(0, 64, 8)]

    # In ra dạng hex của chuỗi gốc
    hex_str = ' '.join(f"{b:02X}" for b in data)

    # Padding SHA-256
    padded_data = bytearray(data)
    padded_data.append(0x80)
    while len(padded_data) % 64 != 56:
        padded_data.append(0x00)
    padded_data += struct.pack('>Q', orig_len_bits)

    blocks = len(padded_data) // 64
    out_lines = []
    
    out_lines.append(f"        // ==========================================")
    out_lines.append(f"        // Generated UVM Sequence for input: \"{text}\"")
    out_lines.append(f"        // Input in hex: {hex_str}. Padding added.")
    out_lines.append(f"        // Total length: {len(data)} bytes = {orig_len_bits} bits")
    out_lines.append(f"        // ==========================================\n")
    out_lines.append(f"        logic [31:0] rdata;\n")

    for b in range(blocks):
        out_lines.append(f"        // --- BLOCK {b} ---")
        block_data = padded_data[b*64 : (b+1)*64]
        
        words = []
        for i in range(16):
            words.append(struct.unpack('>I', block_data[i*4:i*4+4])[0])
            
        i = 0
        while i < 16:
            # Xử lý dồn các thanh ghi bằng 0 thành vòng lặp for
            if words[i] == 0 and i != 14 and i != 15:
                start = i
                while i < 14 and words[i] == 0:
                    i += 1
                end = i - 1
                if start == end:
                    out_lines.append(f"        write_reg(5'd{start}, 32'h00000000);")
                else:
                    out_lines.append(f"        // Block {start}..{end}: 0")
                    out_lines.append(f"        for(int i={start}; i<={end}; i++) write_reg(i[4:0], 32'h0);")
            else:
                if b == blocks - 1 and i == 14:
                    out_lines.append(f"        // Block 14: MSB length")
                    out_lines.append(f"        write_reg(5'd14, 32'h{words[14]:08X});")
                elif b == blocks - 1 and i == 15:
                    out_lines.append(f"        // Block 15: length in bits = {orig_len_bits} = 0x{words[15]:02X}")
                    out_lines.append(f"        write_reg(5'd15, 32'h{words[15]:08X});")
                else:
                    if b == 0 and i == 0:
                        out_lines.append(f"        // Block 0: {words[0]:08X}")
                    out_lines.append(f"        write_reg(5'd{i}, 32'h{words[i]:08X});")
                i += 1
        
        # In lệnh Control
        if b == 0:
            ctrl_val = 3 # start=1, init=1
            out_lines.append(f"\n        // Control (init=1, start=1)")
        else:
            ctrl_val = 1 # start=1, init=0
            out_lines.append(f"\n        // Control (init=0, start=1) - Tiếp tục tính toán")
            
        out_lines.append(f"        write_reg(5'd16, 32'h{ctrl_val:08X}); // bit 0: start, bit 1: init")
        
        # In Polling
        out_lines.append(f"\n        // Wait for done")
        out_lines.append(f"        do begin")
        out_lines.append(f"            read_reg(5'd17, rdata);")
        out_lines.append(f"        end while((rdata & 32'h2) == 0); // bit 1 is done/hash_valid\n")

    # Đọc kết quả
    out_lines.append(f"        // Read hash")
    out_lines.append(f"        for(int i=18; i<=25; i++) begin")
    out_lines.append(f"            read_reg(i[4:0], rdata);")
    out_lines.append(f"        end\n")
    
    # === TẠO CODE SCOREBOARD ===
    out_lines.append(f"        // ==========================================")
    out_lines.append(f"        // [COPY TO SCOREBOARD] EXPECTED HASH (Golden Model)")
    out_lines.append(f"        // ==========================================")
    out_lines.append(f"        logic [31:0] expected_hash [8] = '{{")
    out_lines.append(f"            32'h{hash_words[0]}, 32'h{hash_words[1]}, 32'h{hash_words[2]}, 32'h{hash_words[3]},")
    out_lines.append(f"            32'h{hash_words[4]}, 32'h{hash_words[5]}, 32'h{hash_words[6]}, 32'h{hash_words[7]}")
    out_lines.append(f"        }};")

    final_output = '\n'.join(out_lines)
    
    # Ghi ra file
    with open(output_file, 'w') as f:
        f.write(final_output)
    
    print(f"Đã xử lý xong! Hãy mở file {output_file} để xem kết quả.")

if __name__ == "__main__":
    generate_sequence()
