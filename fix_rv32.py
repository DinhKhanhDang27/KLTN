import os
import glob

# Files to process
files = glob.glob('rtl_riscv/*.sv')

for file in files:
    with open(file, 'r') as f:
        content = f.read()

    # Replacements for widths and constants
    content = content.replace('[63:0]', '[31:0]')
    content = content.replace('64\'d', '32\'d')
    content = content.replace('64\'h', '32\'h')
    content = content.replace('64\'b', '32\'b')
    content = content.replace('b[5:0]', 'b[4:0]')
    content = content.replace('63:1', '31:1')

    # Specific replacements for data_memory.sv
    if 'data_memory.sv' in file:
        content = content.replace('// 256 doublewords (2048 bytes)', '// 512 words (2048 bytes)')
        content = content.replace('doubleword', 'word')
        # We need to change the memory accessing logic. 
        # Actually it's easier to just write a new data_memory.sv for 32-bit.

    with open(file, 'w') as f:
        f.write(content)
