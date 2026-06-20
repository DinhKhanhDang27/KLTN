if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vlog -sv sha256Core.sv sha256Wrapper.sv sha256_avalon_wrapper_tb.sv
vlog -sv avalon_simple_dma.sv avalon_simple_dma_tb.sv
vlog -sv rtl_riscv/adder.sv rtl_riscv/adder_tb.sv
vlog -sv rtl_riscv/alu.sv rtl_riscv/alu_control.sv rtl_riscv/branch_control.sv rtl_riscv/control_unit.sv rtl_riscv/imm_gen.sv rtl_riscv/instruction_memory.sv rtl_riscv/riscv_avalon_wrapper.sv rtl_riscv/riscv_avalon_wrapper_tb.sv rtl_riscv/riscv_uart_firmware_tb.sv rtl_riscv/riscv_sha_uart_firmware_tb.sv rtl_riscv/riscv_sdram_sha_uart_tb.sv
vsim sha256_avalon_wrapper_tb
onfinish stop
run -all
quit -sim
vsim avalon_simple_dma_tb
onfinish stop
run -all
quit -sim
vsim riscv_avalon_wrapper_tb
onfinish stop
run -all
quit -sim
vsim riscv_uart_firmware_tb
onfinish stop
run -all
quit -sim
vsim riscv_sha_uart_firmware_tb
onfinish stop
run -all
quit -sim
vsim riscv_sdram_sha_uart_tb
onfinish stop
run -all
quit -sim
vsim adder_tb
onfinish stop
run -all
quit -sim
quit -f
