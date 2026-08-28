#!/usr/bin/env python3
import argparse
import re


REGS = {
    "zero": 0, "ra": 1, "sp": 2, "gp": 3, "tp": 4,
    "t0": 5, "t1": 6, "t2": 7,
    "s0": 8, "fp": 8, "s1": 9,
    "a0": 10, "a1": 11, "a2": 12, "a3": 13, "a4": 14, "a5": 15,
    "a6": 16, "a7": 17,
    "s2": 18, "s3": 19, "s4": 20, "s5": 21, "s6": 22, "s7": 23,
    "s8": 24, "s9": 25, "s10": 26, "s11": 27,
    "t3": 28, "t4": 29, "t5": 30, "t6": 31,
}
for i in range(32):
    REGS[f"x{i}"] = i


def strip_comment(line):
    return line.split("#", 1)[0].split("//", 1)[0].strip()


CONSTS = {}


def parse_imm(text):
    text = text.strip()
    if len(text) >= 3 and text[0] == "'" and text[-1] == "'":
        return ord(text[1:-1].encode("utf-8").decode("unicode_escape"))
    if re.fullmatch(r"[-+]?((0x[0-9a-fA-F]+)|\d+)", text):
        return int(text, 0)
    if not re.fullmatch(r"[A-Za-z_.$][\w.$]*(\s*[-+]\s*[-+]?((0x[0-9a-fA-F]+)|\d+|[A-Za-z_.$][\w.$]*))*", text):
        raise ValueError(f"bad immediate expression: {text}")
    return eval(text, {"__builtins__": {}}, CONSTS)


def reg(text):
    key = text.strip()
    if key not in REGS:
        raise ValueError(f"unknown register: {text}")
    return REGS[key]


def check_signed(value, bits, what):
    lo = -(1 << (bits - 1))
    hi = (1 << (bits - 1)) - 1
    if not lo <= value <= hi:
        raise ValueError(f"{what} out of {bits}-bit signed range: {value}")


def check_unsigned(value, bits, what):
    if not 0 <= value < (1 << bits):
        raise ValueError(f"{what} out of {bits}-bit unsigned range: {value}")


def enc_r(funct7, rs2, rs1, funct3, rd, opcode):
    return ((funct7 & 0x7f) << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode


def enc_i(imm, rs1, funct3, rd, opcode):
    check_signed(imm, 12, "immediate")
    return ((imm & 0xfff) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode


def enc_s(imm, rs2, rs1, funct3, opcode):
    check_signed(imm, 12, "store offset")
    imm &= 0xfff
    return ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | ((imm & 0x1f) << 7) | opcode


def enc_b(offset, rs2, rs1, funct3, opcode):
    if offset % 2:
        raise ValueError(f"branch offset must be 2-byte aligned: {offset}")
    check_signed(offset, 13, "branch offset")
    imm = offset & 0x1fff
    return (((imm >> 12) & 1) << 31) | (((imm >> 5) & 0x3f) << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (((imm >> 1) & 0xf) << 8) | (((imm >> 11) & 1) << 7) | opcode


def enc_u(imm, rd, opcode):
    check_unsigned(imm, 20, "lui immediate")
    return (imm << 12) | (rd << 7) | opcode


def enc_j(offset, rd, opcode):
    if offset % 2:
        raise ValueError(f"jump offset must be 2-byte aligned: {offset}")
    check_signed(offset, 21, "jump offset")
    imm = offset & 0x1fffff
    return (((imm >> 20) & 1) << 31) | (((imm >> 1) & 0x3ff) << 21) | (((imm >> 11) & 1) << 20) | (((imm >> 12) & 0xff) << 12) | (rd << 7) | opcode


def parse_mem_operand(text):
    match = re.fullmatch(r"\s*([^()]+)\(([^()]+)\)\s*", text)
    if not match:
        raise ValueError(f"bad memory operand: {text}")
    return parse_imm(match.group(1)), reg(match.group(2))


def split_args(text):
    return [part.strip() for part in text.split(",")]


def load_program(path):
    labels = {}
    local_labels = {}
    instructions = []
    pc = 0
    in_block_comment = False

    for lineno, raw in enumerate(open(path, encoding="utf-8"), 1):
        line = raw
        while True:
            if in_block_comment:
                end = line.find("*/")
                if end < 0:
                    line = ""
                    break
                line = line[end + 2:]
                in_block_comment = False
            start = line.find("/*")
            if start < 0:
                break
            end = line.find("*/", start + 2)
            if end < 0:
                line = line[:start]
                in_block_comment = True
                break
            line = line[:start] + line[end + 2:]

        line = strip_comment(line)
        if not line:
            continue
        if line.startswith(".equ"):
            _, rest = line.split(None, 1)
            name, value = split_args(rest)
            CONSTS[name] = parse_imm(value)
            continue
        if line.startswith("."):
            continue

        while ":" in line:
            label, line = line.split(":", 1)
            label = label.strip()
            if re.fullmatch(r"\d+", label):
                local_labels.setdefault(label, []).append(pc)
            elif not re.fullmatch(r"[A-Za-z_.$][\w.$]*", label):
                raise ValueError(f"{path}:{lineno}: bad label: {label}")
            else:
                labels[label] = pc
            line = line.strip()
            if not line:
                break

        if line:
            for part in line.split(";"):
                part = part.strip()
                if part:
                    expanded = expand_pseudo(part)
                    for item in expanded:
                        instructions.append((lineno, pc, item))
                        pc += 4

    return labels, local_labels, instructions


def resolve_label(name, pc, labels, local_labels):
    match = re.fullmatch(r"(\d+)([bf])", name)
    if not match:
        return labels[name]

    number, direction = match.groups()
    pcs = local_labels.get(number, [])
    if direction == "b":
        candidates = [value for value in pcs if value < pc]
        if candidates:
            return candidates[-1]
    else:
        candidates = [value for value in pcs if value > pc]
        if candidates:
            return candidates[0]
    raise KeyError(name)


def signed12(value):
    value &= 0xfff
    return value - 0x1000 if value & 0x800 else value


def expand_pseudo(line):
    op, _, rest = line.partition(" ")
    args = split_args(rest)

    if op == "li":
        value = parse_imm(args[1])
        if -2048 <= value <= 2047:
            return [f"addi {args[0]}, zero, {value}"]
        upper = ((value + 0x800) >> 12) & 0xfffff
        lower = signed12(value)
        result = [f"lui {args[0]}, {upper}"]
        if lower:
            result.append(f"addi {args[0]}, {args[0]}, {lower}")
        return result
    if op == "mv":
        return [f"addi {args[0]}, {args[1]}, 0"]
    if op == "ret":
        return ["jalr zero, 0(ra)"]
    if op == "j":
        return [f"jal zero, {args[0]}"]
    if op == "beqz":
        return [f"beq {args[0]}, zero, {args[1]}"]
    if op == "bnez":
        return [f"bne {args[0]}, zero, {args[1]}"]
    return [line]


def assemble_one(line, pc, labels, local_labels):
    op, _, rest = line.partition(" ")
    op = op.strip()
    args = split_args(rest)

    if op == "lui":
        return enc_u(parse_imm(args[1]), reg(args[0]), 0x37)
    if op == "addi":
        return enc_i(parse_imm(args[2]), reg(args[1]), 0x0, reg(args[0]), 0x13)
    if op == "andi":
        return enc_i(parse_imm(args[2]), reg(args[1]), 0x7, reg(args[0]), 0x13)
    if op == "slti":
        return enc_i(parse_imm(args[2]), reg(args[1]), 0x2, reg(args[0]), 0x13)
    if op == "srli":
        imm = parse_imm(args[2])
        check_unsigned(imm, 6, "shift amount")
        return ((imm & 0x3f) << 20) | (reg(args[1]) << 15) | (0x5 << 12) | (reg(args[0]) << 7) | 0x13
    if op == "slli":
        imm = parse_imm(args[2])
        check_unsigned(imm, 6, "shift amount")
        return ((imm & 0x3f) << 20) | (reg(args[1]) << 15) | (0x1 << 12) | (reg(args[0]) << 7) | 0x13
    if op == "ori":
        return enc_i(parse_imm(args[2]), reg(args[1]), 0x6, reg(args[0]), 0x13)
    if op == "xori":
        return enc_i(parse_imm(args[2]), reg(args[1]), 0x4, reg(args[0]), 0x13)
    if op in ("add", "sub", "and", "or", "xor", "sll"):
        funct3 = {
            "add": 0x0,
            "sub": 0x0,
            "sll": 0x1,
            "xor": 0x4,
            "or":  0x6,
            "and": 0x7,
        }[op]
        funct7 = 0x20 if op == "sub" else 0x00
        return enc_r(funct7, reg(args[2]), reg(args[1]), funct3, reg(args[0]), 0x33)
    if op == "srl":
        return enc_r(0x00, reg(args[2]), reg(args[1]), 0x5, reg(args[0]), 0x33)
    if op == "lw":
        imm, rs1 = parse_mem_operand(args[1])
        return enc_i(imm, rs1, 0x2, reg(args[0]), 0x03)
    if op == "sw":
        imm, rs1 = parse_mem_operand(args[1])
        return enc_s(imm, reg(args[0]), rs1, 0x2, 0x23)
    if op in ("beq", "bne"):
        target = resolve_label(args[2], pc, labels, local_labels)
        funct3 = 0x0 if op == "beq" else 0x1
        return enc_b(target - pc, reg(args[1]), reg(args[0]), funct3, 0x63)
    if op == "blt":
        target = resolve_label(args[2], pc, labels, local_labels)
        return enc_b(target - pc, reg(args[1]), reg(args[0]), 0x4, 0x63)
    if op == "jal":
        target = resolve_label(args[1], pc, labels, local_labels)
        return enc_j(target - pc, reg(args[0]), 0x6f)
    if op == "jalr":
        imm, rs1 = parse_mem_operand(args[1])
        return enc_i(imm, rs1, 0x0, reg(args[0]), 0x67)

    raise ValueError(f"unsupported instruction: {line}")


def main():
    parser = argparse.ArgumentParser(description="Small RV assembler for this project's firmware .S files.")
    parser.add_argument("input")
    parser.add_argument("-o", "--output", default="firmware.hex")
    args = parser.parse_args()

    labels, local_labels, instructions = load_program(args.input)
    words = []
    for lineno, pc, line in instructions:
        try:
            words.append(assemble_one(line, pc, labels, local_labels))
        except Exception as exc:
            raise SystemExit(f"{args.input}:{lineno}: {exc}") from exc

    with open(args.output, "w", encoding="ascii", newline="\n") as out:
        for word in words:
            out.write(f"{word:08x}\n")

    print(f"Wrote {len(words)} instructions to {args.output}")


if __name__ == "__main__":
    main()
