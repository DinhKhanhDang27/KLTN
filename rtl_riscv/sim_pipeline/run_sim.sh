#!/usr/bin/env bash
# Functional simulation of the pipelined RISC-V (ModelSim ASE 32-bit).
#   tb.sv        : standalone pipeline core (riscv_pipeline_top, 1-cycle memory)
#   tb_bridge.sv : SoC path  = riscv_avalon_wrapper (thin bridge) + riscv_pipeline_core
#                  driven by an Avalon memory model with waitrequest + read latency
set -e
MSIM=~/altera/13.0sp1/modelsim_ase
export MODEL_TECH=$MSIM/linux
export LD_LIBRARY_PATH=$MSIM/linux
R="$(cd "$(dirname "$0")/.." && pwd)"
cd "$(dirname "$0")"

# ModelSim ASE 32-bit vsim needs libncurses.so.5 (32-bit). Shim with any
# 32-bit libtinfo if the 32-bit libncurses5 package is not installed.
if ! ldconfig -p 2>/dev/null | grep -qE "libncurses\.so\.5 \(libc6\)"; then
  SHIM=$(find / -name 'libtinfo.so.6*' 2>/dev/null | while read -r f; do
           file -b "$f" | grep -q 80386 && { echo "$f"; break; }; done)
  if [ -n "$SHIM" ]; then mkdir -p shim; ln -sf "$SHIM" shim/libncurses.so.5
    export LD_LIBRARY_PATH=$PWD/shim:$LD_LIBRARY_PATH
  fi
fi

SUBS="$R/alu.sv $R/alu_control.sv $R/branch_control.sv $R/control_unit.sv \
      $R/imm_gen.sv $R/register_file.sv"

rm -rf work && "$MSIM/linux/vlib" work >/dev/null

echo "=================== TB1: standalone pipeline core ==================="
"$MSIM/linux/vlog" -sv -quiet $SUBS "$R/data_memory.sv" "$R/mux.sv" \
  "$R/riscv_pipeline_top.sv" test_imem.sv tb.sv
"$MSIM/linux/vsim" -c work.tb -do "run -all; quit -f"

echo "=============== TB2: SoC path (thin bridge + core, Avalon) ==========="
"$MSIM/linux/vlog" -sv -quiet \
  "$R/riscv_pipeline_core.sv" "$R/riscv_avalon_wrapper.sv" avalon_mem.sv tb_bridge.sv
"$MSIM/linux/vsim" -c work.tb_bridge -do "run -all; quit -f"
