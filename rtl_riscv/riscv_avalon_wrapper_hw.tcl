package require -exact qsys 13.0

set_module_property NAME riscv_avalon_wrapper
set_module_property VERSION 1.0
set_module_property GROUP "User Components/Processors"
set_module_property DISPLAY_NAME "Simple RV64 Avalon-MM Master"
set_module_property DESCRIPTION "Single-cycle RV64 subset with a 32-bit Avalon-MM data master"
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE false

add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL riscv_avalon_wrapper
add_fileset_file riscv_avalon_wrapper.sv SYSTEM_VERILOG PATH riscv_avalon_wrapper.sv
add_fileset_file adder.sv SYSTEM_VERILOG PATH adder.sv
add_fileset_file instruction_memory.sv SYSTEM_VERILOG PATH instruction_memory.sv
add_fileset_file control_unit.sv SYSTEM_VERILOG PATH control_unit.sv
add_fileset_file imm_gen.sv SYSTEM_VERILOG PATH imm_gen.sv
add_fileset_file alu_control.sv SYSTEM_VERILOG PATH alu_control.sv
add_fileset_file alu.sv SYSTEM_VERILOG PATH alu.sv
add_fileset_file branch_control.sv SYSTEM_VERILOG PATH branch_control.sv
add_fileset_file data_memory.sv SYSTEM_VERILOG PATH data_memory.sv
add_fileset_file mux.sv SYSTEM_VERILOG PATH mux.sv
add_fileset_file pc_register.sv SYSTEM_VERILOG PATH pc_register.sv
add_fileset_file register_file.sv SYSTEM_VERILOG PATH register_file.sv
add_fileset_file firmware.hex OTHER PATH ../firmware/firmware.hex

add_interface clock clock end
add_interface_port clock clk clk Input 1

add_interface reset reset end
set_interface_property reset associatedClock clock
set_interface_property reset synchronousEdges DEASSERT
add_interface_port reset reset_n reset_n Input 1

add_interface m0 avalon start
set_interface_property m0 associatedClock clock
set_interface_property m0 associatedReset reset
set_interface_property m0 addressUnits SYMBOLS
set_interface_property m0 bitsPerSymbol 8
set_interface_property m0 doStreamReads false
set_interface_property m0 doStreamWrites false
add_interface_port m0 avm_address address Output 32
add_interface_port m0 avm_read read Output 1
add_interface_port m0 avm_readdata readdata Input 32
add_interface_port m0 avm_readdatavalid readdatavalid Input 1
add_interface_port m0 avm_write write Output 1
add_interface_port m0 avm_writedata writedata Output 32
add_interface_port m0 avm_byteenable byteenable Output 4
add_interface_port m0 avm_waitrequest waitrequest Input 1

add_interface debug conduit end
set_interface_property debug associatedClock clock
set_interface_property debug associatedReset reset
add_interface_port debug out_pc out_pc Output 64
add_interface_port debug out_alu_result out_alu_result Output 64
