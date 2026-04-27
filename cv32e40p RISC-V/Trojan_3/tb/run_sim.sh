#!/usr/bin/env bash
# =============================================================================
# Trojan 3 simulation runner
#
# Requires:
#   - Icarus Verilog (iverilog, vvp)
#   - Environment variable CV32E40P_RTL pointing to the cv32e40p repo's
#     rtl/ directory (needed for cv32e40p_obi_interface.sv).
#
# Example:
#   export CV32E40P_RTL=~/cv32e40p/rtl
#   bash run_sim.sh
# =============================================================================
set -e

if [ -z "$CV32E40P_RTL" ]; then
    echo "ERROR: Set CV32E40P_RTL to your cv32e40p rtl/ directory." >&2
    exit 1
fi

if [ ! -f "$CV32E40P_RTL/cv32e40p_obi_interface.sv" ]; then
    echo "ERROR: cv32e40p_obi_interface.sv not found in $CV32E40P_RTL" >&2
    exit 1
fi

HERE="$(cd "$(dirname "$0")" && pwd)"
RTL="$HERE/../rtl/cv32e40p_load_store_unit.sv"   # MODIFIED version

echo "[Trojan 3] Compiling..."
iverilog -g2012 \
    -o trojan3.vvp \
    "$CV32E40P_RTL/cv32e40p_obi_interface.sv" \
    "$RTL" \
    "$HERE/tb_trojan3.sv"

echo "[Trojan 3] Running simulation..."
vvp trojan3.vvp | tee trojan3.log

echo "[Trojan 3] Done. Waveform: trojan3.vcd  Log: trojan3.log"
