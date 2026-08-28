.option norvc
.text
.globl _start

/*
 * Soft SHA-256 firmware for the RISC-V system.
 *
 * Input layout in SDRAM is kept compatible with firmware_sdram_sha_uart.S:
 *   0x00000000: magic 0x53484132 ("SHA2")
 *   0x00000004: message length in bytes
 *   0x00000008: message bytes packed big-endian into 32-bit words
 *
 * Output over JTAG UART:
 *   digest as 64 lowercase hex chars
 *   newline
 *   elapsed timer ticks/cycles as 8 hex chars
 *
 * This is written for GNU riscv assembler syntax. It intentionally does not
 * touch the SHA hardware base 0x02008000.
 */

.equ SDRAM_BASE, 0x00000000
.equ TIMER_BASE, 0x02008080
.equ UART_BASE,  0x020080A0
.equ SCRATCH,    0x02000000
.equ W_BASE,     SCRATCH
.equ H_BASE,     SCRATCH + 0x100
.equ K_BASE,     SCRATCH + 0x140
.equ BLK_BASE,   SCRATCH + 0x240

/* Altera Avalon timer register byte offsets. */
.equ TIMER_STATUS,  0
.equ TIMER_CONTROL, 4
.equ TIMER_PERIODL, 8
.equ TIMER_PERIODH, 12
.equ TIMER_SNAPL,   16
.equ TIMER_SNAPH,   20

_start:
    li   sp, SCRATCH + 0x1000
    li   s0, SDRAM_BASE
    li   s1, UART_BASE
    li   s2, TIMER_BASE

    li   t0, 'S'
    jal  ra, uart_putc
    li   t0, '3'
    jal  ra, uart_putc
    li   t0, 'W'
    jal  ra, uart_putc

    sw   zero, 0(s0)        /* ignore stale SDRAM magic from a previous run */
    li   t1, 0x53484132
wait_input:
    lw   t0, 0(s0)
    bne  t0, t1, wait_input

    li   t0, 'G'
    jal  ra, uart_putc

    li   t0, '\n'
    jal  ra, uart_putc
    li   t0, 'L'
    jal  ra, uart_putc
    lw   a0, 4(s0)
    jal  ra, print_hex32
    li   t0, 'F'
    jal  ra, uart_putc
    lw   a0, 8(s0)
    jal  ra, print_hex32
    li   t0, 'Z'
    jal  ra, uart_putc
    lw   a0, 156(s0)
    jal  ra, print_hex32
    li   t0, '\n'
    jal  ra, uart_putc

    jal  ra, init_h
    jal  ra, init_k

    li   t0, 'H'
    jal  ra, uart_putc
    jal  ra, timer_start

    addi s3, s0, 8          /* input pointer */
    lw   s4, 4(s0)          /* message length in bytes */
    slli s5, s4, 3          /* low 32-bit bit length */
    srli s6, s4, 6          /* full 64-byte blocks */
    andi s7, s4, 63         /* tail bytes */

full_block_loop:
    beqz s6, final_block
    li   s8, BLK_BASE
    li   s9, 16
copy_full_word:
    lw   t0, 0(s3)
    sw   t0, 0(s8)
    addi s3, s3, 4
    addi s8, s8, 4
    addi s9, s9, -1
    bnez s9, copy_full_word
    li   a0, BLK_BASE
    jal  ra, sha256_compress
    addi s6, s6, -1
    j    full_block_loop

final_block:
    li   s8, BLK_BASE
    srli s9, s7, 2
    andi s10, s7, 3
    li   s11, 0

copy_tail_word:
    beq  s11, s9, write_partial_word
    lw   t0, 0(s3)
    sw   t0, 0(s8)
    addi s3, s3, 4
    addi s8, s8, 4
    addi s11, s11, 1
    j    copy_tail_word

write_partial_word:
    beqz s10, partial_0
    li   t0, 1
    beq  s10, t0, partial_1
    li   t0, 2
    beq  s10, t0, partial_2
partial_3:
    lw   t2, 0(s3)
    li   t4, 0xffffff00
    and  t2, t2, t4
    ori  t2, t2, 0x80
    j    store_partial
partial_2:
    lw   t2, 0(s3)
    li   t4, 0xffff0000
    and  t2, t2, t4
    li   t4, 0x00008000
    or   t2, t2, t4
    j    store_partial
partial_1:
    lw   t2, 0(s3)
    li   t4, 0xff000000
    and  t2, t2, t4
    li   t4, 0x00800000
    or   t2, t2, t4
    j    store_partial
partial_0:
    li   t2, 0x80000000

store_partial:
    sw   t2, 0(s8)
    addi s8, s8, 4
    addi s11, s11, 1

    slti t0, s7, 56
    bnez t0, pad_one_block

pad_first_block:
    li   t0, 16
    beq  s11, t0, send_first_pad
    sw   zero, 0(s8)
    addi s8, s8, 4
    addi s11, s11, 1
    j    pad_first_block

send_first_pad:
    li   a0, BLK_BASE
    jal  ra, sha256_compress
    li   s8, BLK_BASE
    li   s11, 0

pad_second_block:
    li   t0, 15
    beq  s11, t0, write_length
    sw   zero, 0(s8)
    addi s8, s8, 4
    addi s11, s11, 1
    j    pad_second_block

pad_one_block:
    li   t0, 15
    beq  s11, t0, write_length
    sw   zero, 0(s8)
    addi s8, s8, 4
    addi s11, s11, 1
    j    pad_one_block

write_length:
    sw   s5, 0(s8)          /* high length word is zero for this project */
    li   a0, BLK_BASE
    jal  ra, sha256_compress

    jal  ra, timer_stop_read_elapsed
    mv   s11, a0

    li   t0, 'D'
    jal  ra, uart_putc
    li   t0, '\n'
    jal  ra, uart_putc
    jal  ra, print_digest
    li   t0, '\n'
    jal  ra, uart_putc
    li   t0, 'C'
    jal  ra, uart_putc
    li   t0, '='
    jal  ra, uart_putc
    mv   a0, s11
    jal  ra, print_hex32
    li   t0, '\n'
    jal  ra, uart_putc

done:
    j    done

timer_start:
    li   t0, 0
    sw   t0, TIMER_CONTROL(s2)       /* stop */
    sw   t0, TIMER_STATUS(s2)        /* clear timeout */
    li   t0, 0xffff
    sw   t0, TIMER_PERIODL(s2)
    sw   t0, TIMER_PERIODH(s2)
    li   t0, 6                       /* continuous + start */
    sw   t0, TIMER_CONTROL(s2)
    ret

timer_stop_read_elapsed:
    sw   zero, TIMER_SNAPL(s2)
    lw   t0, TIMER_SNAPL(s2)
    lw   t1, TIMER_SNAPH(s2)
    slli t1, t1, 16
    or   t0, t0, t1                  /* remaining down-counter */
    li   t1, 0xffffffff
    sub  a0, t1, t0                  /* elapsed ticks, modulo 2^32 */
    li   t2, 8                       /* stop */
    sw   t2, TIMER_CONTROL(s2)
    ret

sha256_compress:
    addi sp, sp, -64
    sw   ra, 60(sp)
    sw   s0, 56(sp)
    sw   s1, 52(sp)
    sw   s2, 48(sp)
    sw   s3, 44(sp)
    sw   s4, 40(sp)
    sw   s5, 36(sp)
    sw   s6, 32(sp)
    sw   s7, 28(sp)
    sw   s8, 24(sp)
    sw   s9, 20(sp)
    sw   s10, 16(sp)
    sw   s11, 12(sp)

    li   t0, W_BASE
    mv   t1, a0
    li   t2, 16
1:
    lw   t3, 0(t1)
    sw   t3, 0(t0)
    addi t1, t1, 4
    addi t0, t0, 4
    addi t2, t2, -1
    bnez t2, 1b

    li   s8, 16
2:
    li   t0, W_BASE
    slli t1, s8, 2
    add  t0, t0, t1
    lw   a0, -8(t0)                  /* W[i-2] */
    jal  ra, small_sigma1
    mv   s9, a0
    li   t0, W_BASE
    slli t1, s8, 2
    add  t0, t0, t1
    lw   t4, -28(t0)                 /* W[i-7] */
    add  s9, s9, t4
    slli s9, s9, 32
    srli s9, s9, 32
    lw   a0, -60(t0)                 /* W[i-15] */
    jal  ra, small_sigma0
    add  s9, s9, a0
    slli s9, s9, 32
    srli s9, s9, 32
    li   t0, W_BASE
    slli t1, s8, 2
    add  t0, t0, t1
    lw   t4, -64(t0)                 /* W[i-16] */
    add  s9, s9, t4
    slli s9, s9, 32
    srli s9, s9, 32
    sw   s9, 0(t0)
    addi s8, s8, 1
    li   t5, 64
    bne  s8, t5, 2b

    li   t0, H_BASE
    lw   s0, 0(t0)                   /* a */
    lw   s1, 4(t0)                   /* b */
    lw   s2, 8(t0)                   /* c */
    lw   s3, 12(t0)                  /* d */
    lw   s4, 16(t0)                  /* e */
    lw   s5, 20(t0)                  /* f */
    lw   s6, 24(t0)                  /* g */
    lw   s7, 28(t0)                  /* h */

    li   s8, 0
3:
    mv   a0, s4
    jal  ra, big_sigma1
    mv   s9, a0
    mv   a0, s4
    mv   a1, s5
    mv   a2, s6
    jal  ra, ch
    add  s9, s9, a0
    slli s9, s9, 32
    srli s9, s9, 32
    add  s9, s9, s7
    slli s9, s9, 32
    srli s9, s9, 32
    li   t0, K_BASE
    slli t1, s8, 2
    add  t0, t0, t1
    lw   t2, 0(t0)
    add  s9, s9, t2
    slli s9, s9, 32
    srli s9, s9, 32
    li   t0, W_BASE
    add  t0, t0, t1
    lw   t2, 0(t0)
    add  s9, s9, t2                 /* T1 */
    slli s9, s9, 32
    srli s9, s9, 32

    mv   a0, s0
    jal  ra, big_sigma0
    mv   s10, a0
    mv   a0, s0
    mv   a1, s1
    mv   a2, s2
    jal  ra, maj
    add  s10, s10, a0               /* T2 */
    slli s10, s10, 32
    srli s10, s10, 32

    mv   s7, s6
    mv   s6, s5
    mv   s5, s4
    add  s4, s3, s9
    slli s4, s4, 32
    srli s4, s4, 32
    mv   s3, s2
    mv   s2, s1
    mv   s1, s0
    add  s0, s9, s10
    slli s0, s0, 32
    srli s0, s0, 32

    addi s8, s8, 1
    li   t0, 64
    bne  s8, t0, 3b

    li   t0, H_BASE
    lw   t1, 0(t0)
    add  t1, t1, s0
    slli t1, t1, 32
    srli t1, t1, 32
    sw   t1, 0(t0)
    lw   t1, 4(t0)
    add  t1, t1, s1
    slli t1, t1, 32
    srli t1, t1, 32
    sw   t1, 4(t0)
    lw   t1, 8(t0)
    add  t1, t1, s2
    slli t1, t1, 32
    srli t1, t1, 32
    sw   t1, 8(t0)
    lw   t1, 12(t0)
    add  t1, t1, s3
    slli t1, t1, 32
    srli t1, t1, 32
    sw   t1, 12(t0)
    lw   t1, 16(t0)
    add  t1, t1, s4
    slli t1, t1, 32
    srli t1, t1, 32
    sw   t1, 16(t0)
    lw   t1, 20(t0)
    add  t1, t1, s5
    slli t1, t1, 32
    srli t1, t1, 32
    sw   t1, 20(t0)
    lw   t1, 24(t0)
    add  t1, t1, s6
    slli t1, t1, 32
    srli t1, t1, 32
    sw   t1, 24(t0)
    lw   t1, 28(t0)
    add  t1, t1, s7
    slli t1, t1, 32
    srli t1, t1, 32
    sw   t1, 28(t0)

    lw   ra, 60(sp)
    lw   s0, 56(sp)
    lw   s1, 52(sp)
    lw   s2, 48(sp)
    lw   s3, 44(sp)
    lw   s4, 40(sp)
    lw   s5, 36(sp)
    lw   s6, 32(sp)
    lw   s7, 28(sp)
    lw   s8, 24(sp)
    lw   s9, 20(sp)
    lw   s10, 16(sp)
    lw   s11, 12(sp)
    addi sp, sp, 64
    ret

rotr:
    srl  t0, a0, a1
    li   t1, 32
    sub  t1, t1, a1
    sll  t2, a0, t1
    or   a0, t0, t2
    slli a0, a0, 32
    srli a0, a0, 32
    ret

big_sigma0:
    addi sp, sp, -16
    sw   ra, 12(sp)
    sw   a0, 8(sp)
    li   a1, 2
    jal  ra, rotr
    mv   t3, a0
    lw   a0, 8(sp)
    li   a1, 13
    jal  ra, rotr
    xor  t3, t3, a0
    lw   a0, 8(sp)
    li   a1, 22
    jal  ra, rotr
    xor  a0, t3, a0
    lw   ra, 12(sp)
    addi sp, sp, 16
    ret

big_sigma1:
    addi sp, sp, -16
    sw   ra, 12(sp)
    sw   a0, 8(sp)
    li   a1, 6
    jal  ra, rotr
    mv   t3, a0
    lw   a0, 8(sp)
    li   a1, 11
    jal  ra, rotr
    xor  t3, t3, a0
    lw   a0, 8(sp)
    li   a1, 25
    jal  ra, rotr
    xor  a0, t3, a0
    lw   ra, 12(sp)
    addi sp, sp, 16
    ret

small_sigma0:
    addi sp, sp, -16
    sw   ra, 12(sp)
    sw   a0, 8(sp)
    li   a1, 7
    jal  ra, rotr
    mv   t3, a0
    lw   a0, 8(sp)
    li   a1, 18
    jal  ra, rotr
    xor  t3, t3, a0
    lw   a0, 8(sp)
    srli a0, a0, 3
    xor  a0, t3, a0
    lw   ra, 12(sp)
    addi sp, sp, 16
    ret

small_sigma1:
    addi sp, sp, -16
    sw   ra, 12(sp)
    sw   a0, 8(sp)
    li   a1, 17
    jal  ra, rotr
    mv   t3, a0
    lw   a0, 8(sp)
    li   a1, 19
    jal  ra, rotr
    xor  t3, t3, a0
    lw   a0, 8(sp)
    srli a0, a0, 10
    xor  a0, t3, a0
    lw   ra, 12(sp)
    addi sp, sp, 16
    ret

ch:
    and  t0, a0, a1
    xori t1, a0, -1
    and  t1, t1, a2
    xor  a0, t0, t1
    ret

maj:
    and  t0, a0, a1
    and  t1, a0, a2
    xor  t0, t0, t1
    and  t1, a1, a2
    xor  a0, t0, t1
    ret

print_digest:
    addi sp, sp, -16
    sw   ra, 12(sp)
    li   t0, H_BASE
    lw   a0, 0(t0)
    jal  ra, print_hex32
    li   t0, H_BASE
    lw   a0, 4(t0)
    jal  ra, print_hex32
    li   t0, H_BASE
    lw   a0, 8(t0)
    jal  ra, print_hex32
    li   t0, H_BASE
    lw   a0, 12(t0)
    jal  ra, print_hex32
    li   t0, H_BASE
    lw   a0, 16(t0)
    jal  ra, print_hex32
    li   t0, H_BASE
    lw   a0, 20(t0)
    jal  ra, print_hex32
    li   t0, H_BASE
    lw   a0, 24(t0)
    jal  ra, print_hex32
    li   t0, H_BASE
    lw   a0, 28(t0)
    jal  ra, print_hex32
    lw   ra, 12(sp)
    addi sp, sp, 16
    ret

print_hex32:
    addi sp, sp, -16
    sw   ra, 12(sp)
    sw   a0, 8(sp)
    li   t2, 8
    li   t3, 28
1:
    lw   t0, 8(sp)
    srl  t1, t0, t3
    andi t1, t1, 15
    li   t0, 10
    blt  t1, t0, 2f
    addi t0, t1, 87
    j    3f
2:
    addi t0, t1, '0'
3:
    jal  ra, uart_putc
    addi t3, t3, -4
    addi t2, t2, -1
    bnez t2, 1b
    lw   ra, 12(sp)
    addi sp, sp, 16
    ret

uart_putc:
    lw   t1, 4(s1)
    srli t1, t1, 16
    beqz t1, uart_putc
    sw   t0, 0(s1)
    ret

init_h:
    li   t0, H_BASE
    li   t1, 0x6a09e667
    sw   t1, 0(t0)
    li   t1, 0xbb67ae85
    sw   t1, 4(t0)
    li   t1, 0x3c6ef372
    sw   t1, 8(t0)
    li   t1, 0xa54ff53a
    sw   t1, 12(t0)
    li   t1, 0x510e527f
    sw   t1, 16(t0)
    li   t1, 0x9b05688c
    sw   t1, 20(t0)
    li   t1, 0x1f83d9ab
    sw   t1, 24(t0)
    li   t1, 0x5be0cd19
    sw   t1, 28(t0)
    ret

init_k:
    li   t0, K_BASE
    li t1,0x428a2f98; sw t1,0(t0)
    li t1,0x71374491; sw t1,4(t0)
    li t1,0xb5c0fbcf; sw t1,8(t0)
    li t1,0xe9b5dba5; sw t1,12(t0)
    li t1,0x3956c25b; sw t1,16(t0)
    li t1,0x59f111f1; sw t1,20(t0)
    li t1,0x923f82a4; sw t1,24(t0)
    li t1,0xab1c5ed5; sw t1,28(t0)
    li t1,0xd807aa98; sw t1,32(t0)
    li t1,0x12835b01; sw t1,36(t0)
    li t1,0x243185be; sw t1,40(t0)
    li t1,0x550c7dc3; sw t1,44(t0)
    li t1,0x72be5d74; sw t1,48(t0)
    li t1,0x80deb1fe; sw t1,52(t0)
    li t1,0x9bdc06a7; sw t1,56(t0)
    li t1,0xc19bf174; sw t1,60(t0)
    li t1,0xe49b69c1; sw t1,64(t0)
    li t1,0xefbe4786; sw t1,68(t0)
    li t1,0x0fc19dc6; sw t1,72(t0)
    li t1,0x240ca1cc; sw t1,76(t0)
    li t1,0x2de92c6f; sw t1,80(t0)
    li t1,0x4a7484aa; sw t1,84(t0)
    li t1,0x5cb0a9dc; sw t1,88(t0)
    li t1,0x76f988da; sw t1,92(t0)
    li t1,0x983e5152; sw t1,96(t0)
    li t1,0xa831c66d; sw t1,100(t0)
    li t1,0xb00327c8; sw t1,104(t0)
    li t1,0xbf597fc7; sw t1,108(t0)
    li t1,0xc6e00bf3; sw t1,112(t0)
    li t1,0xd5a79147; sw t1,116(t0)
    li t1,0x06ca6351; sw t1,120(t0)
    li t1,0x14292967; sw t1,124(t0)
    li t1,0x27b70a85; sw t1,128(t0)
    li t1,0x2e1b2138; sw t1,132(t0)
    li t1,0x4d2c6dfc; sw t1,136(t0)
    li t1,0x53380d13; sw t1,140(t0)
    li t1,0x650a7354; sw t1,144(t0)
    li t1,0x766a0abb; sw t1,148(t0)
    li t1,0x81c2c92e; sw t1,152(t0)
    li t1,0x92722c85; sw t1,156(t0)
    li t1,0xa2bfe8a1; sw t1,160(t0)
    li t1,0xa81a664b; sw t1,164(t0)
    li t1,0xc24b8b70; sw t1,168(t0)
    li t1,0xc76c51a3; sw t1,172(t0)
    li t1,0xd192e819; sw t1,176(t0)
    li t1,0xd6990624; sw t1,180(t0)
    li t1,0xf40e3585; sw t1,184(t0)
    li t1,0x106aa070; sw t1,188(t0)
    li t1,0x19a4c116; sw t1,192(t0)
    li t1,0x1e376c08; sw t1,196(t0)
    li t1,0x2748774c; sw t1,200(t0)
    li t1,0x34b0bcb5; sw t1,204(t0)
    li t1,0x391c0cb3; sw t1,208(t0)
    li t1,0x4ed8aa4a; sw t1,212(t0)
    li t1,0x5b9cca4f; sw t1,216(t0)
    li t1,0x682e6ff3; sw t1,220(t0)
    li t1,0x748f82ee; sw t1,224(t0)
    li t1,0x78a5636f; sw t1,228(t0)
    li t1,0x84c87814; sw t1,232(t0)
    li t1,0x8cc70208; sw t1,236(t0)
    li t1,0x90befffa; sw t1,240(t0)
    li t1,0xa4506ceb; sw t1,244(t0)
    li t1,0xbef9a3f7; sw t1,248(t0)
    li t1,0xc67178f2; sw t1,252(t0)
    ret
