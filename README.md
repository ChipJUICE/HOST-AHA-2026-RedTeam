# IEEE HOST 2026 AHA! Challenge — Red Team Submission
## Target: openhwgroup cv32e40p RISC-V Processor

---

## 1. Overview

Three hardware Trojans inserted into the cv32e40p RISC-V core. Every RTL edit
and every testbench line was produced by an AI agent (Claude Opus 4.7) operating
through the claude.ai interface with filesystem and bash tools. **No hand-written
hardware.**

| # | Name | File | Lines added | CVSS |
|---|------|------|-------------|------|
| 1 | Interrupt killswitch | `cv32e40p_cs_registers.sv` | 8 | 7.5 (High) |
| 2 | Return address hijack | `cv32e40p_register_file_ff.sv` | 15 | 9.3 (Critical) |
| 3 | Silent store corruption | `cv32e40p_load_store_unit.sv` | 3 | 8.2 (High) |

Average CVSS = **8.33** (rubric: *Exemplary, 7.0–10.0*).

---


## 2. Directory Layout

```
submission/
├── README.md                       ← this file
├── run_all.sh                      ← one-click behavioural simulation
├── scripts/
│   └── gen_metrics.sh              ← one-click PPA metrics (golden + 3 Trojans)
├── cv32e40p_synth_harness/         ← convenience copy of the official PPA harness
│
├── golden_metrics/                 ← populated by gen_metrics.sh
│
├── Trojan_1/                       Interrupt killswitch
│   ├── rtl/cv32e40p_cs_registers.sv
│   ├── tb/tb_trojan1.sv
│   ├── tb/run_sim.sh
│   ├── metrics/                    ← populated by gen_metrics.sh
│   └── ai/interaction_log.md
│
├── Trojan_2/                       Return address hijack
│   ├── rtl/cv32e40p_register_file_ff.sv
│   ├── tb/tb_trojan2.sv
│   ├── tb/run_sim.sh
│   ├── metrics/
│   └── ai/interaction_log.md
│
└── Trojan_3/                       Silent store corruption
    ├── rtl/cv32e40p_load_store_unit.sv
    ├── tb/tb_trojan3.sv
    ├── tb/run_sim.sh
    ├── metrics/
    └── ai/interaction_log.md
```

---

## 3. Prerequisites

### Required tools

| Tool | Purpose | Install |
|------|---------|---------|
| Icarus Verilog | Behavioural simulation | `sudo apt install iverilog` / `brew install icarus-verilog` |
| sv2v | SystemVerilog → Verilog-2001 | <https://github.com/zachjs/sv2v/releases> |
| Yosys | Logic synthesis | <https://yosyshq.net/yosys/> |
| OpenSTA | Static timing | <https://github.com/The-OpenROAD-Project/OpenSTA> |

All four must be on your `$PATH`.

### Required source trees

```bash
# 1. The target design
git clone https://github.com/openhwgroup/cv32e40p.git ~/cv32e40p
```

The official PPA harness is already bundled in `cv32e40p_synth_harness/` inside
this submission — you don't need to download it separately.

### Environment variables

```bash
export CV32E40P_RTL=~/cv32e40p/rtl          # for behavioural sim
export CV32E40P_REPO=~/cv32e40p             # for PPA
export CV32E40P_HARNESS=$(pwd)/cv32e40p_synth_harness   # bundled harness
```

---

## 4. Running the Behavioural Simulations (~10 s)

Quick sanity check that every Trojan triggers correctly.

### One-click (all three Trojans)

```bash
cd submission
bash run_all.sh
```

Expected tail:
```
--- Trojan 1 verdict ---
  PASSED: 7
  FAILED: 0
  >>> TROJAN-1 VERIFIED <<<

--- Trojan 2 verdict ---
  PASSED: 7
  FAILED: 0
  >>> TROJAN-2 VERIFIED <<<

--- Trojan 3 verdict ---
  PASSED: 5
  FAILED: 0
  >>> TROJAN-3 VERIFIED <<<
```

### Individual Trojan
```bash
cd submission/Trojan_1/tb && bash run_sim.sh
# produces trojan1.log + trojan1.vcd (open in GTKWave)
```

---

## 5. Generating PPA Metrics (~2 h total)

One script generates the golden baseline **and** all three Trojan metric folders
automatically. It:

1. Copies the harness into `$CV32E40P_REPO/cv32e40p_synth/`
2. Runs `run_ppa.sh` against the **unmodified** repo → `golden_metrics/`
3. For each Trojan: swaps in the modified RTL, runs `run_ppa.sh`, copies
   results into `Trojan_<N>/metrics/`, restores the golden file
4. Cleans up

```bash
cd submission
bash scripts/gen_metrics.sh
```

Each `run_ppa.sh` invocation takes ≈30 minutes per the challenge README, so
plan for ~2 hours total wall-clock time. Progress is streamed to the terminal.

After the script finishes, every required metrics folder is populated with:

```
golden_metrics/
├── timing_report.txt       (Yosys longest-path analysis)
├── area_report.txt         (Yosys stat + liberty area)
└── sta_report.txt          (OpenSTA max-path report)
```
(same three files for each of `Trojan_1/metrics/`, `Trojan_2/metrics/`,
`Trojan_3/metrics/`).

### Expected PPA impact (all <1 % → rubric: *Exemplary*)

| Trojan | Extra FFs | Extra gates | Δarea | Δtiming |
|--------|-----------|-------------|-------|---------|
| 1 | +1 | ~5 | <0.01 % | 0 ps |
| 2 | +1 | ~15 | <0.02 % | ~20 ps on RF read path |
| 3 | 0 | ~8 | <0.01 % | ~15 ps on store path |

---

## 6. End-to-End One-Liner

From a clean machine with the tools installed:

```bash
# --- one-time setup -----------------------------------------------------
git clone https://github.com/openhwgroup/cv32e40p.git ~/cv32e40p
unzip submission.zip && cd submission
export CV32E40P_RTL=~/cv32e40p/rtl
export CV32E40P_REPO=~/cv32e40p
export CV32E40P_HARNESS=$(pwd)/cv32e40p_synth_harness

# --- behavioural sim (quick) -------------------------------------------
bash run_all.sh

# --- full PPA (long) ---------------------------------------------------
bash scripts/gen_metrics.sh
```

---

## 7. Trojan Details

### 7.1 Trojan 1 — Interrupt Killswitch
- **File:** `cv32e40p_cs_registers.sv`
- **Trigger:** `csrw mscratch, 0xDEADC0DE`
- **Payload:** `m_irq_enable_o` permanently forced to 0; all machine-mode interrupts silently suppressed
- **CVSS:** `CVSS:3.1/AV:L/AC:H/PR:H/UI:N/S:C/C:N/I:N/A:H` → **7.5 (High)**

### 7.2 Trojan 2 — Return Address Hijack
- **File:** `cv32e40p_register_file_ff.sv`
- **Trigger:** `li t3, 0xFEEDFACE`
- **Payload:** every read of `x1` (`ra`) returns `0xDEAD0000`; every `ret` redirects to attacker code
- **CVSS:** `CVSS:3.1/AV:L/AC:L/PR:L/UI:N/S:C/C:H/I:H/A:H` → **9.3 (Critical)**

### 7.3 Trojan 3 — Silent Store Corruption
- **File:** `cv32e40p_load_store_unit.sv`
- **Trigger:** store where `addr[7:0] == 0xA5` AND `data[15:8] == 0xBE`
- **Payload:** low byte of store data XOR'd with `0xFF` before the bus; address / write-enable / byte-enable signals untouched
- **CVSS:** `CVSS:3.1/AV:L/AC:H/PR:L/UI:N/S:C/C:N/I:H/A:L` → **8.2 (High)**

---

## 8. Reproducibility Checklist

- [ ] `iverilog`, `sv2v`, `yosys`, `sta` all on `$PATH`
- [ ] `openhwgroup/cv32e40p` cloned to `$CV32E40P_REPO`
- [ ] `CV32E40P_RTL`, `CV32E40P_REPO`, `CV32E40P_HARNESS` exported
- [ ] `bash run_all.sh` → all three `>>> TROJAN-N VERIFIED <<<` lines printed
- [ ] `bash scripts/gen_metrics.sh` → `golden_metrics/` and all `Trojan_N/metrics/` folders populated
