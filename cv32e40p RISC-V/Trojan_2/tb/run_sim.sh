#!/usr/bin/env bash
# =============================================================================
# Trojan 2 simulation runner
#
# Requires: Icarus Verilog (iverilog, vvp).
# The register file is standalone — no cv32e40p_pkg needed.
#
# Run: bash run_sim.sh
# =============================================================================
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
RTL="$HERE/../rtl/cv32e40p_register_file_ff.sv"   # MODIFIED version

echo "[Trojan 2] Compiling..."
iverilog -g2012 \
    -o trojan2.vvp \
    "$RTL" \
    "$HERE/tb_trojan2.sv"

echo "[Trojan 2] Running simulation..."
vvp trojan2.vvp | tee trojan2.log

echo "[Trojan 2] Done. Waveform: trojan2.vcd  Log: trojan2.log"
