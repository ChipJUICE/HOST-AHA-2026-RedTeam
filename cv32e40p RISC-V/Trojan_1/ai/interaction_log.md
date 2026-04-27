# AI Interaction Log — Trojan 1 (Interrupt Killswitch)

**Model:** Claude Sonnet 4.6 (Anthropic)
**Interface:** claude.ai web chat (claude.ai)
**Session date:** April 20, 2026

---

## Overview

The team member identified the Trojan concept and target module independently
by reading the cv32e40p architecture documentation and RTL. The AI was then
used to implement the identified Trojan in hardware and generate the testbench.

---

## Human Decision Making

### Target identification (human)
After reviewing the cv32e40p pipeline architecture, the team identified
`cv32e40p_cs_registers.sv` as the target. The reasoning:

- The CSR module controls machine-mode interrupt enable (`m_irq_enable_o`)
- Permanently disabling interrupts would break OS scheduling and all
  interrupt-driven subsystems without crashing the processor
- `mscratch` is a general-purpose scratch register — writing a magic value
  to it is a realistic and stealthy trigger mechanism that would not look
  suspicious in normal firmware

The team decided on the following Trojan design before prompting the AI:
- **Trigger:** Write `0xDEADC0DE` to `mscratch` CSR
- **Payload:** Force `m_irq_enable_o` permanently to 0
- **Mechanism:** A 1-bit sticky latch that cannot be cleared by software

---

## AI Interaction Transcript

### Prompt 1
> I have uploaded all 27 RTL files for the cv32e40p RISC-V processor. I want
> to insert a hardware Trojan into cv32e40p_cs_registers.sv. The Trojan should
> work as follows: when the value 0xDEADC0DE is written to the mscratch CSR
> (address 0x340), a hidden 1-bit latch gets permanently set. Once set, the
> output m_irq_enable_o should be forced to 0 regardless of what mstatus.MIE
> is set to. The latch should reset to 0 on reset but cannot be cleared by any
> CSR write. Please implement this by making minimal changes to the file.

**AI response:** Claude read `cv32e40p_cs_registers.sv` using the bash tool,
located the `m_irq_enable_o` assign statement at line 1104 and the mscratch
write path, then applied four targeted `str_replace` edits:

1. Declared `logic trojan_irq_lock_q` at line 146
2. Modified the `m_irq_enable_o` assign to AND in `!trojan_irq_lock_q`
3. Added `trojan_irq_lock_q <= 1'b0` in the reset block
4. Added the trigger condition in the sequential block

### Prompt 2
> Now verify the diff is minimal and no existing logic was accidentally changed.

**AI response:** Claude ran `diff` between the original and modified file,
confirmed only 8 lines were added and no existing lines were removed or altered.

### Prompt 3
> Generate a SystemVerilog testbench that proves:
> 1. Normal operation — interrupts work correctly before the trigger
> 2. That benign writes to mscratch (0xDEADBEEF, 0x12345678) do NOT fire the Trojan
> 3. The trigger fires when 0xDEADC0DE is written
> 4. The latch persists through subsequent CSR writes

**AI response:** Claude generated `tb_trojan1.sv` with four structured phases
and pass/fail assertions for each check.

### Prompt 4 (debug)
> The testbench fails to compile with iverilog — there are struct literal syntax
> errors. Fix the compile flow.

**AI response:** Claude identified that `cv32e40p_cs_registers.sv` uses
SystemVerilog struct literals (`'{field: value}`) unsupported by Icarus Verilog,
updated `run_sim.sh` to use `sv2v` to flatten the design first, and rewrote
the testbench to use plain `logic` types without package imports.

---

## CVSS 3.1 Score: 5.3

Vector: `AV:L/AC:H/PR:H/UI:N/S:C/C:N/I:N/A:H`

Verified using the FIRST.org CVSS 3.1 calculator at
https://www.first.org/cvss/calculator/3.1

| Metric | Value | Justification |
|--------|-------|---------------|
| Attack Vector | Local | Requires executing a privileged CSR write instruction |
| Attack Complexity | High | Attacker must know the exact 32-bit magic constant |
| Privileges Required | High | `csrw mscratch` requires M-mode privilege |
| User Interaction | None | No user action needed after trigger |
| Scope | Changed | Effect propagates beyond CSR to entire interrupt subsystem |
| Confidentiality | None | No data is leaked |
| Integrity | None | No data is modified |
| Availability | High | All interrupt-driven operation permanently broken |

---

## Division of Labour

| Task | Human | AI |
|------|-------|----|
| Identifying target module | ✅ | |
| Designing Trojan concept (trigger + payload) | ✅ | |
| Choosing trigger value and mechanism | ✅ | |
| RTL implementation (str_replace edits) | | ✅ |
| Diff verification | | ✅ |
| Testbench generation | | ✅ |
| Debug of sv2v/iverilog compile issues | | ✅ |
| CVSS scoring | ✅ (verified on calculator) | ✅ (initial estimate) |
