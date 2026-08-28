#!/usr/bin/env python3
import argparse
import hashlib


def words_for_message(data):
    padded = data + b"\x00" * ((4 - (len(data) % 4)) % 4)
    words = [0x53484132, len(data)]
    words.extend(int.from_bytes(padded[i:i + 4], "big") for i in range(0, len(padded), 4))
    return words


def main():
    parser = argparse.ArgumentParser(description="Pack a byte string for firmware_sdram_sha_uart.S SDRAM input layout.")
    parser.add_argument("input", help="Text/binary file to hash")
    parser.add_argument("-o", "--output", default="load_sdram_input.tcl", help="System Console TCL output")
    parser.add_argument("--base", default="0x00000000", help="SDRAM base address")
    args = parser.parse_args()

    data = open(args.input, "rb").read()
    base = int(args.base, 0)
    digest = hashlib.sha256(data).hexdigest()
    words = words_for_message(data)

    with open(args.output, "w", encoding="ascii", newline="\n") as out:
        out.write("# Run in Intel/Altera System Console after adding a JTAG-to-Avalon Master.\n")
        out.write("set m [lindex [get_service_paths master] 0]\n")
        out.write("open_service master $m\n")
        out.write("# Clear magic first so firmware waits while data is being loaded.\n")
        out.write(f"master_write_32 $m 0x{base:08x} 0x00000000\n")
        for index, word in enumerate(words[1:], start=1):
            out.write(f"master_write_32 $m 0x{base + index * 4:08x} 0x{word:08x}\n")
        out.write("# Commit input. Firmware starts hashing after this word becomes 0x53484132.\n")
        out.write(f"master_write_32 $m 0x{base:08x} 0x53484132\n")
        out.write(f"puts \"magic  = [master_read_32 $m 0x{base:08x} 1]\"\n")
        out.write(f"puts \"length = [master_read_32 $m 0x{base + 4:08x} 1]\"\n")
        out.write("close_service master $m\n")

    print(f"Input bytes : {len(data)}")
    print(f"SHA-256     : {digest}")
    print(f"Words       : {len(words)}")
    print(f"Wrote TCL   : {args.output}")


if __name__ == "__main__":
    main()
