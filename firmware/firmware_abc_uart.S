.option norvc
.text
.globl _start

.equ SHA_BASE,  0x02008000
.equ UART_BASE, 0x020080A0

_start:
    lui  s0, 0x2008
    lui  s1, 0x2008
    addi s1, s1, 0x0a0

    lui  t0, 0x44697
    addi t0, t0, -408
    sw   t0, 0(s0)

    lui  t0, 0x204b7
    addi t0, t0, -1951
    sw   t0, 4(s0)

    lui  t0, 0x6e682
    addi t0, t0, 68
    sw   t0, 8(s0)

    lui  t0, 0x616e6
    addi t0, t0, 1824
    sw   t0, 12(s0)

    lui  t0, 0x32333
    addi t0, t0, 1330
    sw   t0, 16(s0)

    lui  t0, 0x30323
    addi t0, t0, 564
    sw   t0, 20(s0)

    lui  t0, 0x20507
    addi t0, t0, -1951
    sw   t0, 24(s0)

    lui  t0, 0x6d204
    addi t0, t0, 872
    sw   t0, 28(s0)

    lui  t0, 0x69204
    addi t0, t0, 1121
    sw   t0, 32(s0)

    lui  t0, 0x74203
    addi t0, t0, 563
    sw   t0, 36(s0)

    lui  t0, 0x35323
    addi t0, t0, 50
    sw   t0, 40(s0)

    lui  t0, 0x36358
    addi t0, t0, 0
    sw   t0, 44(s0)

    addi t0, zero, 0
    sw   t0, 48(s0)
    sw   t0, 52(s0)
    sw   t0, 56(s0)

    addi t0, zero, 368
    sw   t0, 60(s0)

    addi t0, zero, 3
    sw   t0, 64(s0)

wait_hash:
    lw   t0, 68(s0)
    andi t0, t0, 2
    beq  t0, zero, wait_hash

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
