def R(op,rd,f3,rs1,rs2,f7): return (f7<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|op
def I(op,rd,f3,rs1,imm):
    imm&=0xFFF; return (imm<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|op
def S(op,f3,rs1,rs2,imm):
    imm&=0xFFF; return ((imm>>5)<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|((imm&0x1F)<<7)|op
def B(op,f3,rs1,rs2,imm):
    i=imm&0x1FFF
    b12=(i>>12)&1; b11=(i>>11)&1; b10_5=(i>>5)&0x3F; b4_1=(i>>1)&0xF
    return (b12<<31)|(b10_5<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|(b4_1<<8)|(b11<<7)|op
def J(op,rd,imm):
    i=imm&0x1FFFFF
    b20=(i>>20)&1; b10_1=(i>>1)&0x3FF; b11=(i>>11)&1; b19_12=(i>>12)&0xFF
    return (b20<<31)|(b10_1<<21)|(b11<<20)|(b19_12<<12)|(rd<<7)|op
OPI=0x13; OPR=0x33; OPL=0x03; OPS=0x23; OPB=0x63; OPJAL=0x6F
prog=[
 I(OPI,1,0,0,5),      # 00 addi x1,x0,5     -> x1=5
 I(OPI,2,0,1,3),      # 04 addi x2,x1,3     -> x2=8  (fwd x1 EX/MEM)
 R(OPR,3,0,1,2,0),    # 08 add  x3,x1,x2    -> x3=13 (fwd)
 S(OPS,2,0,3,0),      # 0C sw   x3,0(x0)    -> mem[0]=13 (fwd x3)
 I(OPL,4,2,0,0),      # 10 lw   x4,0(x0)    -> x4=13
 R(OPR,5,0,4,1,0),    # 14 add  x5,x4,x1    -> x5=18 (LOAD-USE stall + fwd)
 B(OPB,0,1,0,8),      # 18 beq  x1,x0,+8    -> NOT taken
 I(OPI,6,0,0,99),     # 1C addi x6,x0,99    -> x6=99 (runs)
 B(OPB,1,1,0,8),      # 20 bne  x1,x0,+8    -> TAKEN -> flush next
 I(OPI,6,0,0,123),    # 24 addi x6,x0,123   -> SKIPPED
 I(OPI,7,0,0,7),      # 28 addi x7,x0,7     -> x7=7 (bne target)
 J(OPJAL,8,8),        # 2C jal  x8,+8       -> x8=0x30, jump 0x34
 I(OPI,9,0,0,55),     # 30 addi x9,x0,55    -> SKIPPED (jal)
 I(OPI,10,0,0,42),    # 34 addi x10,x0,42   -> x10=42 (jal target)
 B(OPB,0,0,0,0),      # 38 beq  x0,x0,0     -> halt loop
]
for w in prog: print("%08x"%(w&0xFFFFFFFF))
