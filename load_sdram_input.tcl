# Run in Intel/Altera System Console after adding a JTAG-to-Avalon Master.
set m [lindex [get_service_paths master] 0]
open_service master $m
# Clear magic first so firmware waits while data is being loaded.
master_write_32 $m 0x00000000 0x00000000
master_write_32 $m 0x00000004 0x00000096
master_write_32 $m 0x00000008 0x6b696120
master_write_32 $m 0x0000000c 0x6d616e20
master_write_32 $m 0x00000010 0x64656d20
master_write_32 $m 0x00000014 0x68697520
master_write_32 $m 0x00000018 0x68616320
master_write_32 $m 0x0000001c 0x6d616e67
master_write_32 $m 0x00000020 0x2074656e
master_write_32 $m 0x00000024 0x20656d20
master_write_32 $m 0x00000028 0x71756179
master_write_32 $m 0x0000002c 0x20766520
master_write_32 $m 0x00000030 0x74726f6e
master_write_32 $m 0x00000034 0x67206b79
master_write_32 $m 0x00000038 0x20756320
master_write_32 $m 0x0000003c 0x63756120
master_write_32 $m 0x00000040 0x616e6820
master_write_32 $m 0x00000044 0x71756120
master_write_32 $m 0x00000048 0x74686f69
master_write_32 $m 0x0000004c 0x20676961
master_write_32 $m 0x00000050 0x6e206368
master_write_32 $m 0x00000054 0x69657520
master_write_32 $m 0x00000058 0x6c616e67
master_write_32 $m 0x0000005c 0x20696d20
master_write_32 $m 0x00000060 0x6e676865
master_write_32 $m 0x00000064 0x2067696f
master_write_32 $m 0x00000068 0x2064756e
master_write_32 $m 0x0000006c 0x67206475
master_write_32 $m 0x00000070 0x61206361
master_write_32 $m 0x00000074 0x79206e68
master_write_32 $m 0x00000078 0x75206c61
master_write_32 $m 0x0000007c 0x2062616f
master_write_32 $m 0x00000080 0x206e6f69
master_write_32 $m 0x00000084 0x206e686f
master_write_32 $m 0x00000088 0x2063756f
master_write_32 $m 0x0000008c 0x6e20616e
master_write_32 $m 0x00000090 0x68207472
master_write_32 $m 0x00000094 0x6f692076
master_write_32 $m 0x00000098 0x65206461
master_write_32 $m 0x0000009c 0x753f0000
# Commit input. Firmware starts hashing after this word becomes 0x53484132.
master_write_32 $m 0x00000000 0x53484132
puts "magic  = [master_read_32 $m 0x00000000 1]"
puts "length = [master_read_32 $m 0x00000004 1]"
close_service master $m
