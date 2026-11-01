xvlog -sv ../tb/if/riscv_if.sv
xvlog -sv ../rtl/instruction_memory.sv ../rtl/register_file.sv ../rtl/data_memory.sv \
          ../rtl/control_unit.sv ../rtl/imm_gen.sv ../rtl/alu_control.sv ../rtl/alu.sv \
          ../rtl/branch_control.sv ../rtl/mux.sv ../rtl/adder.sv ../rtl/riscv_pipeline_top.sv
xvlog -sv ../tb/top/riscv_tb_top.sv
xelab -timescale 1ns/1ps riscv_tb_top -s top_sim
xsim top_sim -R

