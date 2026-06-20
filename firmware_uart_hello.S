.option norvc
.text
.globl _start

.equ UART_BASE, 0x020080A0

_start:
    lui  s1, 0x2008
    addi s1, s1, 0x0a0

    addi t0, zero, 'H'
wait_0:
    lw   t1, 4(s1)
    srli t1, t1, 16
    beq  t1, zero, wait_0
    sw   t0, 0(s1)

    addi t0, zero, 'E'
wait_1:
    lw   t1, 4(s1)
    srli t1, t1, 16
    beq  t1, zero, wait_1
    sw   t0, 0(s1)

    addi t0, zero, 'L'
wait_2:
    lw   t1, 4(s1)
    srli t1, t1, 16
    beq  t1, zero, wait_2
    sw   t0, 0(s1)

    addi t0, zero, 'L'
wait_3:
    lw   t1, 4(s1)
    srli t1, t1, 16
    beq  t1, zero, wait_3
    sw   t0, 0(s1)

    addi t0, zero, 'O'
wait_4:
    lw   t1, 4(s1)
    srli t1, t1, 16
    beq  t1, zero, wait_4
    sw   t0, 0(s1)

    addi t0, zero, 13
wait_5:
    lw   t1, 4(s1)
    srli t1, t1, 16
    beq  t1, zero, wait_5
    sw   t0, 0(s1)

    addi t0, zero, 10
wait_6:
    lw   t1, 4(s1)
    srli t1, t1, 16
    beq  t1, zero, wait_6
    sw   t0, 0(s1)

    addi t1, zero, -1
delay:
    addi t1, t1, -1
    bne  t1, zero, delay

    jal zero, _start
