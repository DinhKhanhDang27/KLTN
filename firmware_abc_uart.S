.option norvc
.text
.globl _start

.equ SHA_BASE,  0x02008000
.equ UART_BASE, 0x020080A0

_start:
    lui  s0, 0x2008
    lui  s1, 0x2008
    addi s1, s1, 0x0a0

    lui  t0, 0x61626
    addi t0, t0, 0x380
    sw   t0, 0(s0)

    addi t0, zero, 0
    sw   t0, 4(s0)
    sw   t0, 8(s0)
    sw   t0, 12(s0)
    sw   t0, 16(s0)
    sw   t0, 20(s0)
    sw   t0, 24(s0)
    sw   t0, 28(s0)
    sw   t0, 32(s0)
    sw   t0, 36(s0)
    sw   t0, 40(s0)
    sw   t0, 44(s0)
    sw   t0, 48(s0)
    sw   t0, 52(s0)
    sw   t0, 56(s0)

    addi t0, zero, 24
    sw   t0, 60(s0)

    addi t0, zero, 3
    sw   t0, 64(s0)

wait_hash:
    lw   t0, 68(s0)
    andi t0, t0, 2
    beq  t0, zero, wait_hash

wait_uart:
    lw   t1, 4(s1)
    srli t1, t1, 16
    beq  t1, zero, wait_uart

    addi t0, zero, 'b'
    sw   t0, 0(s1)
    addi t0, zero, 'a'
    sw   t0, 0(s1)
    addi t0, zero, '7'
    sw   t0, 0(s1)
    addi t0, zero, '8'
    sw   t0, 0(s1)
    addi t0, zero, '1'
    sw   t0, 0(s1)
    addi t0, zero, '6'
    sw   t0, 0(s1)
    addi t0, zero, 'b'
    sw   t0, 0(s1)
    addi t0, zero, 'f'
    sw   t0, 0(s1)
    addi t0, zero, '8'
    sw   t0, 0(s1)
    addi t0, zero, 'f'
    sw   t0, 0(s1)
    addi t0, zero, '0'
    sw   t0, 0(s1)
    addi t0, zero, '1'
    sw   t0, 0(s1)
    addi t0, zero, 'c'
    sw   t0, 0(s1)
    addi t0, zero, 'f'
    sw   t0, 0(s1)
    addi t0, zero, 'e'
    sw   t0, 0(s1)
    addi t0, zero, 'a'
    sw   t0, 0(s1)
    addi t0, zero, '4'
    sw   t0, 0(s1)
    addi t0, zero, '1'
    sw   t0, 0(s1)
    addi t0, zero, '4'
    sw   t0, 0(s1)
    addi t0, zero, '1'
    sw   t0, 0(s1)
    addi t0, zero, '4'
    sw   t0, 0(s1)
    addi t0, zero, '0'
    sw   t0, 0(s1)
    addi t0, zero, 'd'
    sw   t0, 0(s1)
    addi t0, zero, 'e'
    sw   t0, 0(s1)
    addi t0, zero, '5'
    sw   t0, 0(s1)
    addi t0, zero, 'd'
    sw   t0, 0(s1)
    addi t0, zero, 'a'
    sw   t0, 0(s1)
    addi t0, zero, 'e'
    sw   t0, 0(s1)
    addi t0, zero, '2'
    sw   t0, 0(s1)
    addi t0, zero, '2'
    sw   t0, 0(s1)
    addi t0, zero, '2'
    sw   t0, 0(s1)
    addi t0, zero, '3'
    sw   t0, 0(s1)
    addi t0, zero, 'b'
    sw   t0, 0(s1)
    addi t0, zero, '0'
    sw   t0, 0(s1)
    addi t0, zero, '0'
    sw   t0, 0(s1)
    addi t0, zero, '3'
    sw   t0, 0(s1)
    addi t0, zero, '6'
    sw   t0, 0(s1)
    addi t0, zero, '1'
    sw   t0, 0(s1)
    addi t0, zero, 'a'
    sw   t0, 0(s1)
    addi t0, zero, '3'
    sw   t0, 0(s1)
    addi t0, zero, '9'
    sw   t0, 0(s1)
    addi t0, zero, '6'
    sw   t0, 0(s1)
    addi t0, zero, '1'
    sw   t0, 0(s1)
    addi t0, zero, '7'
    sw   t0, 0(s1)
    addi t0, zero, '7'
    sw   t0, 0(s1)
    addi t0, zero, 'a'
    sw   t0, 0(s1)
    addi t0, zero, '9'
    sw   t0, 0(s1)
    addi t0, zero, 'c'
    sw   t0, 0(s1)
    addi t0, zero, 'b'
    sw   t0, 0(s1)
    addi t0, zero, '4'
    sw   t0, 0(s1)
    addi t0, zero, '1'
    sw   t0, 0(s1)
    addi t0, zero, '0'
    sw   t0, 0(s1)
    addi t0, zero, 'f'
    sw   t0, 0(s1)
    addi t0, zero, 'f'
    sw   t0, 0(s1)
    addi t0, zero, '6'
    sw   t0, 0(s1)
    addi t0, zero, '1'
    sw   t0, 0(s1)
    addi t0, zero, 'f'
    sw   t0, 0(s1)
    addi t0, zero, '2'
    sw   t0, 0(s1)
    addi t0, zero, '0'
    sw   t0, 0(s1)
    addi t0, zero, '0'
    sw   t0, 0(s1)
    addi t0, zero, '1'
    sw   t0, 0(s1)
    addi t0, zero, '5'
    sw   t0, 0(s1)
    addi t0, zero, 'a'
    sw   t0, 0(s1)
    addi t0, zero, 'd'
    sw   t0, 0(s1)

done:
    jal zero, done
