package require -exact qsys 13.0

set_module_property NAME sha256_avalon_wrapper
set_module_property VERSION 1.0
set_module_property GROUP "User Components/Crypto"
set_module_property DISPLAY_NAME "SHA-256 Avalon-MM Wrapper"
set_module_property DESCRIPTION "32-bit Avalon-MM slave wrapper for sha256_core"
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE false

add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL sha256_avalon_wrapper
add_fileset_file sha256Wrapper.sv SYSTEM_VERILOG PATH sha256Wrapper.sv
add_fileset_file sha256Core.sv SYSTEM_VERILOG PATH sha256Core.sv

add_interface clock clock end
add_interface_port clock clk clk Input 1

add_interface reset reset end
set_interface_property reset associatedClock clock
set_interface_property reset synchronousEdges DEASSERT
add_interface_port reset reset_n reset_n Input 1

add_interface s0 avalon end
set_interface_property s0 associatedClock clock
set_interface_property s0 associatedReset reset
set_interface_property s0 addressUnits WORDS
set_interface_property s0 bitsPerSymbol 8
set_interface_property s0 readLatency 0
add_interface_port s0 avs_chipselect chipselect Input 1
add_interface_port s0 avs_address address Input 5
add_interface_port s0 avs_read read Input 1
add_interface_port s0 avs_readdata readdata Output 32
add_interface_port s0 avs_write write Input 1
add_interface_port s0 avs_byteenable byteenable Input 4
add_interface_port s0 avs_writedata writedata Input 32
add_interface_port s0 avs_waitrequest waitrequest Output 1

add_interface irq_conduit conduit end
set_interface_property irq_conduit associatedClock clock
set_interface_property irq_conduit associatedReset reset
add_interface_port irq_conduit irq irq Output 1
