# =============================================================
# Timing constraints - RISC-V pipeline Fmax characterization
# DE0-Nano on-board oscillator = 50 MHz, but for Fmax we constrain
# an aggressive target so the design is not artificially capped.
# The actual Fmax is read from the "Report Fmax" (Slow corner),
# which is independent of the period value chosen here.
# =============================================================

create_clock -name clk -period 5.000 [get_ports {clk}]

derive_clock_uncertainty

# rst / debug outputs are not timing-critical for core Fmax.
set_false_path -from [get_ports {rst}] -to [all_registers]
