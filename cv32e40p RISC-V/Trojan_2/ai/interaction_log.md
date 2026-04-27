# AI Interaction Log — Trojan 2 (Return Address Hijack)

**Model:** Claude Sonnet 4.6 (Anthropic)
**Interface:** claude.ai web chat (claude.ai)
**Session date:** April 20, 2026

---

## Overview

The team member identified the Trojan concept independently by analysing the
RISC-V calling convention and the cv32e40p register file architecture. The AI
was then used to implement the identified Trojan and generate the testbench.

---

## Human Decision Making

### Target identification (human)
After studying the RISC-V ABI and cv32e40p_register_file_ff.sv, the team
identified the register file read path as the target. The reasoning:

- In the RISC-V calling convention, `x1` (ra) always holds the return address
- Every `ret` instruction reads `x1` — hijacking reads of `x1` redirects all
  function returns without touching any instruction or PC logic
- Intercepting the **read path** (not the write path) means the stored value
  is never modified — a debugger dumping registers would also see the poisoned
  value, making it look like x1 genuinely contains the hijack address
- `x28` (t3) is a caller-saved temporary — compilers write to it constantly,
  making a write-triggered Trojan hard to distinguish from normal code

The team decided on the following Trojan design before prompting the AI:
- **Trigger:** Write `0xFEEDFACE` to register `x28` (t3)
- **Payload:** All reads of `x1` (ra) return `0xDEAD0000`
- **Mechanism:** A 1-bit poison latch on the read mux, not the write path

---

## AI Interaction Transcript

### Prompt 1
> I have uploaded cv32e40p_register_file_ff.sv. I want to insert a hardware
> Trojan that works as follows: when the value 0xFEEDFACE is written to
> register x28 (index 28), a hidden 1-bit latch gets permanently set. Once
> set, any read of register x1 (ra) from any read port should return
> 0xDEAD0000 instead of the real stored value. The actual stored value in x1
> should not be changed — only the read output should be overridden. Make
> minimal changes to the file.

**AI response:** Claude read `cv32e40p_register_file_ff.sv`, located the three
read assign statements at lines 89-91, then replaced them with a block that:
- Declared `logic trojan_ra_poison_q`
- Added an `always_ff` block monitoring `we_a_dec[28]` and `we_b_dec[28]`
  for the magic value
- Inserted a ternary override on each read port for `raddr[4:0] == 5'd1`

### Prompt 2
> Verify the diff and confirm no existing write logic was changed.

**AI response:** Claude ran `diff` and confirmed only 15 lines were added
replacing the 3 original read assigns. No write logic was touched.

### Prompt 3
> Generate a testbench proving:
> 1. x1 reads correctly before the trigger
> 2. Benign writes to x28 do NOT trigger the Trojan
> 3. Writing 0xFEEDFACE to x28 fires the trigger
> 4. Only x1 is affected — other registers still read correctly
> 5. Overwriting x1 does not restore the real value

**AI response:** Claude generated `tb_trojan2.sv` with five structured phases.

### Prompt 4 (debug — ADDR_WIDTH)
> The testbench fails — we_a_dec[28] is out of bounds.

**AI response:** Claude identified that `ADDR_WIDTH` was set to 5 in the
testbench (giving only 16 register slots) but the real core uses `ADDR_WIDTH=6`
(bit 5 = FP/integer selector, bits 4:0 = index). Updated testbench to use
`ADDR_WIDTH=6` and 6-bit address literals throughout.

---

## CVSS 3.1 Score: 8.8

Vector: `AV:L/AC:L/PR:L/UI:N/S:C/C:H/I:H/A:H`

Verified using the FIRST.org CVSS 3.1 calculator at
https://www.first.org/cvss/calculator/3.1

| Metric | Value | Justification |
|--------|-------|---------------|
| Attack Vector | Local | Attacker executes code on the processor |
| Attack Complexity | Low | Only requires writing a known constant to t3 |
| Privileges Required | Low | Any unprivileged code can write t3 |
| User Interaction | None | No user action needed after trigger |
| Scope | Changed | Control flow escapes the normal program boundary |
| Confidentiality | High | Attacker code at 0xDEAD0000 can read all memory |
| Integrity | High | Arbitrary code execution |
| Availability | High | Normal program control flow is permanently broken |

---

## Division of Labour

| Task | Human | AI |
|------|-------|----|
| Identifying target module (register file) | ✅ | |
| Choosing x1 (ra) as the hijack target | ✅ | |
| Deciding to intercept reads not writes | ✅ | |
| Choosing x28 (t3) as trigger register | ✅ | |
| Choosing trigger value 0xFEEDFACE | ✅ | |
| RTL implementation | | ✅ |
| Testbench generation | | ✅ |
| Debug of ADDR_WIDTH issue | | ✅ |
| CVSS scoring | ✅ (verified on calculator) | ✅ (initial estimate) |
