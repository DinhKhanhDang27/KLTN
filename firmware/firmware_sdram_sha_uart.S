.option norvc
.text
.globl _start

.equ SDRAM_BASE, 0x00000000
.equ SHA_BASE,   0x02008000
.equ UART_BASE,  0x020080A0

# SDRAM layout expected by this firmware:
#   0x00000000: magic word 0x53484132 ("SHA2"), written last by the loader
#   0x00000004: message length in bytes, 32-bit unsigned
#   0x00000008: message bytes packed into 32-bit big-endian words.
#               Example bytes "ABCD" are stored as word 0x41424344.
#
# This firmware supports messages up to 0x1fffffff bytes because it keeps
# bit_length = byte_length << 3 in one 32-bit SHA length word.

_start:
    lui  s0, 0x2008
    lui  s1, 0x2008
    addi s1, s1, 0x0a0

    lui  t1, 0x53484
    addi t1, t1, 306

wait_input:
    lw   t0, 0(zero)
    bne  t0, t1, wait_input

    addi s2, zero, 8
    lw   s3, 4(zero)
    slli s9, s3, 3
    srli s5, s3, 6
    andi s6, s3, 63
    addi s7, zero, 3

full_block_loop:
    beq  s5, zero, final_block
    addi s8, s0, 0
    addi s4, zero, 16

copy_full_word:
    lw   t0, 0(s2)
    sw   t0, 0(s8)
    addi s2, s2, 4
    addi s8, s8, 4
    addi s4, s4, -1
    bne  s4, zero, copy_full_word

    jal  ra, start_hash
    addi s5, s5, -1
    jal  zero, full_block_loop

final_block:
    addi s8, s0, 0
    srli s5, s6, 2
    andi t5, s6, 3
    addi s4, zero, 0

copy_tail_word:
    beq  s4, s5, write_partial_word
    lw   t0, 0(s2)
    sw   t0, 0(s8)
    addi s2, s2, 4
    addi s8, s8, 4
    addi s4, s4, 1
    jal  zero, copy_tail_word

write_partial_word:
    beq  t5, zero, partial_0
    addi t0, zero, 1
    beq  t5, t0, partial_1
    addi t0, zero, 2
    beq  t5, t0, partial_2

partial_3:
    lw   t2, 0(s2)
    lui  t4, 0xfffff
    addi t4, t4, -256
    and  t2, t2, t4
    addi t4, zero, 128
    or   t2, t2, t4
    jal  zero, store_partial

partial_2:
    lw   t2, 0(s2)
    lui  t4, 0xffff0
    and  t2, t2, t4
    lui  t4, 0x8
    or   t2, t2, t4
    jal  zero, store_partial

partial_1:
    lw   t2, 0(s2)
    lui  t4, 0xff000
    and  t2, t2, t4
    lui  t4, 0x800
    or   t2, t2, t4
    jal  zero, store_partial

partial_0:
    lui  t2, 0x80000

store_partial:
    sw   t2, 0(s8)
    addi s8, s8, 4
    addi s4, s4, 1

    slti t0, s6, 56
    bne  t0, zero, pad_one_block

pad_first_block:
    slti t0, s4, 16
    beq  t0, zero, send_first_pad
    sw   zero, 0(s8)
    addi s8, s8, 4
    addi s4, s4, 1
    jal  zero, pad_first_block

send_first_pad:
    jal  ra, start_hash
    addi s8, s0, 0
    addi s4, zero, 0

pad_second_block:
    slti t0, s4, 15
    beq  t0, zero, write_length
    sw   zero, 0(s8)
    addi s8, s8, 4
    addi s4, s4, 1
    jal  zero, pad_second_block

pad_one_block:
    slti t0, s4, 15
    beq  t0, zero, write_length
    sw   zero, 0(s8)
    addi s8, s8, 4
    addi s4, s4, 1
    jal  zero, pad_one_block

write_length:
    sw   s9, 0(s8)
    jal  ra, start_hash
    jal  zero, print_digest

start_hash:
    addi t0, zero, 4
    sw   t0, 68(s0)
    sw   s7, 64(s0)

wait_hash:
    lw   t0, 68(s0)
    andi t0, t0, 2
    beq  t0, zero, wait_hash

    addi t0, zero, 4
    sw   t0, 68(s0)
    addi s7, zero, 1
    jalr zero, 0(ra)

print_digest:
    addi s2, s0, 72
    addi s3, zero, 8

print_word:
    lw   t2, 0(s2)
    addi s4, zero, 8
    addi s5, zero, 28

print_nibble:
    srl  t3, t2, s5
    andi t3, t3, 15
    slti t4, t3, 10
    beq  t4, zero, hex_letter

    addi t0, t3, '0'
    jal  zero, send_hex

hex_letter:
    addi t0, t3, 87

send_hex:
    lw   t1, 4(s1)
    srli t1, t1, 16
    beq  t1, zero, send_hex
    sw   t0, 0(s1)

    addi s5, s5, -4
    addi s4, s4, -1
    bne  s4, zero, print_nibble

    addi s2, s2, 4
    addi s3, s3, -1
    bne  s3, zero, print_word

done:
    jal zero, done
