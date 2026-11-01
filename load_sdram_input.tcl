# Run in Intel/Altera System Console after adding a JTAG-to-Avalon Master.
set m [lindex [get_service_paths master] 0]
open_service master $m
# Clear magic first so firmware waits while data is being loaded.
master_write_32 $m 0x00000000 0x00000000
master_write_32 $m 0x00000004 0x00000016
master_write_32 $m 0x00000008 0x6368756f
master_write_32 $m 0x0000000c 0x695f6361
master_write_32 $m 0x00000010 0x6e5f6861
master_write_32 $m 0x00000014 0x73685f63
master_write_32 $m 0x00000018 0x75615f62
master_write_32 $m 0x0000001c 0x616e0000
# Commit input. Firmware starts hashing after this word becomes 0x53484132.
master_write_32 $m 0x00000000 0x53484132
puts "magic  = [master_read_32 $m 0x00000000 1]"
puts "length = [master_read_32 $m 0x00000004 1]"
close_service master $m
