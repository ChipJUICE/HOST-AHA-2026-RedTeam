#!/usr/bin/env bash
# =============================================================================
# Trojan 1 simulation runner
#
# cv32e40p_cs_registers.sv uses SystemVerilog struct literals that Icarus
# Verilog cannot parse directly. This script uses sv2v to flatten the design
# to Verilog-2001 first, then compiles with iverilog.
#
# Requires:
#   - sv2v     (brew install sv2v)
#   - iverilog (brew install icarus-verilog)
#   - CV32E40P_RTL env var pointing to your cv32e40p repo's rtl/ directory
#
# Example:
#   export CV32E40P_RTL=~/cv32e40p/rtl
#   bash run_sim.sh
# =============================================================================
set -e

if [ -z "$CV32E40P_RTL" ]; then
    echo "ERROR: Set CV32E40P_RTL to your cv32e40p rtl/ directory." >&2
    echo "       e.g. export CV32E40P_RTL=~/cv32e40p/rtl" >&2
    exit 1
fi

command -v sv2v     >/dev/null 2>&1 || { echo "ERROR: sv2v not found. Install with: brew install sv2v" >&2; exit 1; }
command -v iverilog >/dev/null 2>&1 || { echo "ERROR: iverilog not found. Install with: brew install icarus-verilog" >&2; exit 1; }

HERE="$(cd "$(dirname "$0")" && pwd)"
RTL="$HERE/../rtl/cv32e40p_cs_registers.sv"

# Find package files (may live in rtl/include/ or rtl/)
find_pkg() {
    local name="$1"
    for d in "$CV32E40P_RTL/include" "$CV32E40P_RTL"; do
        [ -f "$d/$name" ] && echo "$d/$name" && return
    done
    echo "ERROR: $name not found under $CV32E40P_RTL" >&2
    exit 1
}

APU_PKG=$(find_pkg "cv32e40p_apu_core_pkg.sv")
FPU_PKG=$(find_pkg "cv32e40p_fpu_pkg.sv")
PKG=$(find_pkg "cv32e40p_pkg.sv")

echo "[Trojan 1] Running sv2v to flatten SystemVerilog -> Verilog-2001..."
sv2v "$APU_PKG" "$FPU_PKG" "$PKG" "$RTL" > "$HERE/trojan1_flat.v"

echo "[Trojan 1] Compiling..."
iverilog -g2012 \
    -o trojan1.vvp \
    "$HERE/trojan1_flat.v" \
    "$HERE/tb_trojan1.sv"

echo "[Trojan 1] Running simulation..."
vvp trojan1.vvp | tee trojan1.log

echo "[Trojan 1] Done. Waveform: trojan1.vcd  Log: trojan1.log"
