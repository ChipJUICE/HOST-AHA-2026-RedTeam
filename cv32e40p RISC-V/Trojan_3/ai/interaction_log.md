# AI Interaction Log — Trojan 3 (Silent Store Corruption)

**Model:** Claude Sonnet 4.6 (Anthropic)
**Interface:** claude.ai web chat (claude.ai)
**Session date:** April 20, 2026

---

## Overview

The team member identified the Trojan concept independently by analysing the
cv32e40p memory write pipeline and the OBI bus interface. The AI was then
used to locate the exact injection point, implement the Trojan, and generate
the testbench.

---

## Human Decision Making

### Target identification (human)
After studying `cv32e40p_load_store_unit.sv` and the OBI bus interface, the
team identified the `trans_wdata` signal as the target. The reasoning:

- `trans_wdata` is the single choke-point carrying all outgoing store data
  to the memory bus — intercepting it corrupts any store silently
- A purely combinational override adds zero flip-flops, giving the smallest
  possible PPA footprint
- Corrupting only the data (not address, WE, or BE signals) means the bus
  looks structurally correct — no protocol violation occurs
- Using a two-condition trigger (address byte AND data byte) makes accidental
  triggering statistically improbable while remaining easy to engineer
- XOR with 0xFF looks like a random bit-flip fault, not an intentional attack

The team decided on the following Trojan design before prompting the AI:
- **Trigger:** Store where `addr[7:0] == 0xA0` AND `data[15:8] == 0xBE`
- **Payload:** XOR low byte of store data with `0xFF` on the bus
- **Mechanism:** Purely combinational — zero flip-flops

The team specifically chose `0xA0` (not `0xA5`) because `0xA0[1:0] = 00`,
ensuring word alignment so the LSU does not byte-rotate the data before
the Trojan logic sees it.

---

## AI Interaction Transcript

### Prompt 1
> I have uploaded cv32e40p_load_store_unit.sv. I want to insert a hardware
> Trojan with zero added flip-flops. The Trojan should intercept the
> trans_wdata signal. When addr[7:0] == 0xA0 AND data[15:8] == 0xBE during
> a store (data_we_ex_i == 1), XOR the low byte of trans_wdata with 0xFF
> before it reaches the OBI interface. All other bus signals must be
> untouched. Make a single-line change only.

**AI response:** Claude located `assign trans_wdata = data_wdata;` at line 364
and replaced it with the conditional XOR expression, adding a comment. Total
change: 1 line replaced with 3 lines (comment + 2-line assign).

### Prompt 2
> Verify the diff and confirm address/WE/BE signals are untouched.

**AI response:** Claude confirmed the diff shows only lines 364-366 changed.
Grepped for `data_addr_o`, `data_we_o`, `data_be_o` assignments and confirmed
all are unmodified.

### Prompt 3
> Generate a testbench proving:
> 1. Stores with only one condition met do NOT trigger corruption
> 2. Stores with both conditions met DO corrupt the low byte
> 3. addr, we, and be signals on the bus are unmodified during triggered stores

**AI response:** Claude generated `tb_trojan3.sv` with three structured phases.

### Prompt 4 (debug — byte position)
> The testbench fails. The test data 0xBEEF_1234 has byte1=0x12, not 0xBE.
> Fix the test data to actually have 0xBE in byte 1 (bits 15:8).

**AI response:** Claude identified the byte-numbering error — `0xBEEF_1234`
has `0xBE` in byte 3 (bits 31:24), not byte 1 (bits 15:8). Updated test
values to `0xDEAD_BEEF` (byte1=`0xBE`) and `0xCAFE_BE42` (byte1=`0xBE`),
with correct expected outputs `0xDEAD_BE10` and `0xCAFE_BEBD` respectively.

### Prompt 5 (debug — alignment)
> The trigger byte was originally 0xA5 but addr[7:0]=0xA5 has bits[1:0]=01
> which is not word-aligned. The LSU rotates byte data for misaligned accesses
> before trans_wdata is computed. Fix the trigger to use 0xA0 instead.

**AI response:** Claude updated the trigger byte from `8'hA5` to `8'hA0`
in both the RTL and testbench. `0xA0[1:0] = 00` guarantees word alignment,
so no byte rotation occurs and the Trojan sees the unmodified data.

---

## CVSS 3.1 Score: 6.4

Vector: `AV:L/AC:H/PR:L/UI:N/S:C/C:N/I:H/A:L`

Verified using the FIRST.org CVSS 3.1 calculator at
https://www.first.org/cvss/calculator/3.1

| Metric | Value | Justification |
|--------|-------|---------------|
| Attack Vector | Local | Attacker controls what is stored and where |
| Attack Complexity | High | Must control both addr[7:0] and data[15:8] simultaneously |
| Privileges Required | Low | Any store instruction — no privilege needed |
| User Interaction | None | No user action needed |
| Scope | Changed | Corruption propagates to system memory beyond the LSU |
| Confidentiality | None | No data is leaked |
| Integrity | High | Silent memory corruption — keys, configs, page tables |
| Availability | Low | Eventual corruption may cause crashes |

---

## Division of Labour

| Task | Human | AI |
|------|-------|----|
| Identifying trans_wdata as injection point | ✅ | |
| Deciding on zero-FF combinational design | ✅ | |
| Choosing dual-condition trigger | ✅ | |
| Choosing 0xA0 (word-aligned) as addr trigger byte | ✅ | |
| Choosing XOR 0xFF as corruption payload | ✅ | |
| RTL implementation (single assign override) | | ✅ |
| Testbench generation | | ✅ |
| Debug of byte-position error in test data | | ✅ |
| Debug of alignment issue (0xA5 → 0xA0) | | ✅ |
| CVSS scoring | ✅ (verified on calculator) | ✅ (initial estimate) |
