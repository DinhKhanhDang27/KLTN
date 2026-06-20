# Run in Intel/Altera System Console after adding a JTAG-to-Avalon Master.
set m [lindex [get_service_paths master] 0]
open_service master $m
# Clear magic first so firmware waits while data is being loaded.
master_write_32 $m 0x00000000 0x00000000
master_write_32 $m 0x00000004 0x0000002e
master_write_32 $m 0x00000008 0x44696e68
master_write_32 $m 0x0000000c 0x204b6861
master_write_32 $m 0x00000010 0x6e682044
master_write_32 $m 0x00000014 0x616e6720
master_write_32 $m 0x00000018 0x32333532
master_write_32 $m 0x0000001c 0x30323234
master_write_32 $m 0x00000020 0x20506861
master_write_32 $m 0x00000024 0x6d204368
master_write_32 $m 0x00000028 0x69204461
master_write_32 $m 0x0000002c 0x74203233
master_write_32 $m 0x00000030 0x35323032
master_write_32 $m 0x00000034 0x36350000
# Commit input. Firmware starts hashing after this word becomes 0x53484132.
master_write_32 $m 0x00000000 0x53484132
puts "magic  = [master_read_32 $m 0x00000000 1]"
puts "length = [master_read_32 $m 0x00000004 1]"
close_service master $m
