# AES-128 Hardware Security Module (HSM)

> **SystemVerilog · Xilinx Vivado · Zybo Z7 (Zynq-7000)**

A fully pipelined, NIST FIPS-197-compliant AES-128 encryption engine implemented in SystemVerilog and deployed on the Digilent Zybo Z7 FPGA development board. The design achieves **125 MHz / 55-cycle / 440 ns** end-to-end latency and includes an interactive hardware demo with avalanche and diffusion attack visualization.

---

## 📺 Demonstration Video

https://drive.google.com/file/d/14TzsQ2vNZT7IWTipUjWXzBr3f810-JpY/view?usp=drive_link


---

## ✨ Features

- **AES-128 Encryption** — Full FIPS-197-compliant pipeline: SubBytes (S-Box LUT), ShiftRows, MixColumns (GF(2⁸) xtime()), AddRoundKey
- **Sequential Key Scheduler FSM** — 3-state FSM (IDLE → EXPAND → DONE) expanding W[0..43] in 40 sequential cycles, resolving a −23.6 ns timing violation
- **125 MHz Timing Closure** — WNS improved from −23.6 ns → −0.004 ns using `phys_opt_design` / `route_design` TCL directives
- **PMOD KYPD Input** — 16-key hex keypad matrix scanner for live key and plaintext entry
- **LED Ciphertext Display** — 128-bit ciphertext browsed nibble-by-nibble on 4 LEDs
- **Avalanche & Diffusion Attack Demo** — BTN1/BTN2 trigger 1-bit key/plaintext tamper and display the differing ciphertext live
- **NIST Self-Checking Testbench** — 4-case testbench covering known-answer, avalanche, diffusion, and all-zeros edge case

---

## 🗂️ Repository Structure

```
├── src/
│   ├── aes_fsm.sv            # Master AES controller FSM (IDLE→LOAD_KEY→WAIT_KEY→INIT→ROUND→DONE)
│   ├── aes_key_scheduler.sv  # Sequential key expansion (3-state FSM, 40 cycles)
│   ├── aes_round.sv          # Single combinatorial AES round (SubBytes/ShiftRows/MixColumns/AddRoundKey)
│   ├── aes_sbox.sv           # Synchronous AES S-Box ROM (256×8 LUT)
│   ├── hsm_top.sv            # Top-level: button FSM, KYPD, AES, LED display
│   ├── pmod_kypd.sv          # PMOD KYPD 4×4 matrix keypad scanner
│   └── pmod_oled.sv          # PMOD OLED SPI controller (bypassed in v3 demo)
├── tb/
│   └── tb_aes_fsm.sv         # Self-checking 4-case simulation testbench
├── constraints/
│   └── hsm_top.xdc           # Zybo Z7 pin assignments + 125 MHz clock constraint
└── README.md
```

---

## 🏗️ Architecture

```
          ┌─────────────────────────────────────────────────┐
          │                   hsm_top                        │
          │                                                   │
  BTN ───►│  Button FSM  ──► aes_fsm ◄─── aes_key_scheduler │
  KYPD ──►│  pmod_kypd        │                              │
          │                   ▼                              │
  LED ◄───│           aes_round (×10)                        │
          │        (combinatorial engine)                     │
          └─────────────────────────────────────────────────┘
```

### AES FSM State Machine

```
IDLE ──(start)──► LOAD_KEY ──► WAIT_KEY ──(ready)──► INIT
                                                        │
                                                  Round 0: PT ⊕ K[0]
                                                        │
                                                    S_ROUND ◄──┐
                                                        │       │ round_cnt < 10
                                              latch rnd_out     │
                                                        └───────┘
                                                        │ round_cnt == 10
                                                     S_DONE ──► IDLE
```

### Key Scheduler FSM (Timing Fix)

The original 40-stage combinatorial key expansion loop caused a **WNS of −23.6 ns** at 125 MHz. The fix was redesigning it as a 3-state sequential FSM — one word per clock cycle — reducing the critical path to register-to-register.

```
KS_IDLE ──(load)──► KS_EXPAND ──(word_idx==43)──► KS_DONE ──► KS_IDLE
                    (one W[] word                   (assert
                     per cycle)                    key_ready)
```

### MixColumns — GF(2⁸) Optimization

Instead of a generalized `gf_mult()` loop (8 LUT levels deep), MixColumns uses only two primitive operations:

| Operation | Expression | LUT Depth |
|-----------|------------|-----------|
| ×2 | `xtime(b) = {b[6:0],1'b0} ^ (b[7] ? 8'h1B : 8'h00)` | ~2 |
| ×3 | `xtime(b) ^ b` | ~3 |

This reduces the round critical path from **~32 ns → ~10 ns**.

---

## 📐 Performance

| Metric | Value |
|--------|-------|
| Target Clock | 125 MHz (8 ns period) |
| WNS (before fix) | −23.6 ns |
| WNS (after fix) | −0.004 ns |
| Encryption Latency | 55 clock cycles |
| End-to-End Latency | ~440 ns |
| Key Expansion Cycles | 40 (sequential FSM) |

---

## 🎮 Hardware Demo — Zybo Z7

### Button Map

| Button | Function |
|--------|----------|
| **BTN0** | Full reset |
| **BTN1** | Attack Demo A — 1-bit KEY tamper (avalanche) |
| **BTN2** | Attack Demo B — 1-bit PT tamper (diffusion) / Return to normal |
| **BTN3** | Cycle ciphertext nibble display (0–31) |

### LED Map

| LED Pattern | Phase |
|-------------|-------|
| `0001` | Collecting key (32 nibbles via KYPD) |
| `0011` | Collecting plaintext (32 nibbles via KYPD) |
| `0110` | AES encryption running |
| `[nibble]` | Displaying current ciphertext nibble (4 bits) |

### Demo Procedure

1. **Enter Key** — Type 32 hex digits on the KYPD keypad (LEDs = `0001`)
   - NIST test key: `2B7E151628AED2A6ABF7158809CF4F3C`
2. **Enter Plaintext** — Type 32 hex digits (LEDs = `0011`)
   - NIST test plaintext: `3243F6A8885A308D313198A2E0370734`
3. **Auto-Encrypt** — LEDs flash `0110` while AES runs (~440 ns)
4. **Browse Ciphertext** — LEDs show nibble 0 of CT; press **BTN3** to advance
   - NIST expected nibble 0 = `3` → LEDs `0011`
5. **Key Attack (BTN1)** — Flips bit 0 of key → re-encrypts → shows tampered CT
6. **PT Attack (BTN2)** — Flips bit 0 of plaintext → re-encrypts → shows tampered CT
7. **Return (BTN2 in attack display)** — Returns to original ciphertext view

### NIST FIPS-197 Appendix B Test Vector

| Field | Value |
|-------|-------|
| Key | `2B 7E 15 16 28 AE D2 A6 AB F7 15 88 09 CF 4F 3C` |
| Plaintext | `32 43 F6 A8 88 5A 30 8D 31 31 98 A2 E0 37 07 34` |
| **Ciphertext** | **`39 25 84 1D 02 DC 09 FB DC 11 85 97 19 6A 0B 32`** |

---

## 🔬 Simulation & Verification

The testbench `tb/tb_aes_fsm.sv` runs 4 self-checking test cases:

| Test | Description | Pass Criterion |
|------|-------------|----------------|
| 1 | NIST FIPS-197 Appendix B known-answer | `ciphertext === 128'h3925...0B32` |
| 2 | 1-bit key tamper (avalanche) | ≥ 4 of 16 bytes differ |
| 3 | 1-bit plaintext tamper (diffusion) | ≥ 4 of 16 bytes differ |
| 4 | All-zero key + all-zero plaintext | Ciphertext ≠ 0 |

Run in Vivado Simulator:

```tcl
# In Vivado Tcl console
launch_simulation
run all
```

Or with any IEEE SystemVerilog-compliant simulator:

```bash
# Verilator example
verilator --lint-only -sv src/aes_sbox.sv src/aes_key_scheduler.sv \
          src/aes_round.sv src/aes_fsm.sv tb/tb_aes_fsm.sv
```

---

## 🛠️ Building in Xilinx Vivado

### 1. Create Project

```tcl
create_project hsm_aes128 ./hsm_aes128 -part xc7z010clg400-1
set_property simulator_language Mixed [current_project]
```

### 2. Add Sources

```tcl
add_files -norecurse {
    src/aes_sbox.sv
    src/aes_key_scheduler.sv
    src/aes_round.sv
    src/aes_fsm.sv
    src/pmod_kypd.sv
    src/pmod_oled.sv
    src/hsm_top.sv
}
add_files -fileset sim_1 tb/tb_aes_fsm.sv
add_files -fileset constrs_1 constraints/hsm_top.xdc
set_property top hsm_top [current_fileset]
```

### 3. Synthesize & Implement

```tcl
launch_runs synth_1 -jobs 4
wait_on_run synth_1
launch_runs impl_1 -jobs 4
wait_on_run impl_1
```

### 4. Post-Route Optimization (Timing Fix)

If WNS is still negative after implementation, apply these directives:

```tcl
open_run impl_1
phys_opt_design
route_design -directive AggressiveExplore
report_timing_summary -file timing_summary.rpt
```

### 5. Generate Bitstream & Program

```tcl
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
open_hw_manager
connect_hw_server
open_hw_target
program_hw_devices [get_hw_devices xc7z0*]
```

---

## 📋 Requirements

| Tool / Component | Version / Part |
|-----------------|---------------|
| Xilinx Vivado | 2022.x or later (ML Edition) |
| Target FPGA | Zybo Z7-10: `xc7z010clg400-1` / Z7-20: `xc7z020clg400-1` |
| PMOD KYPD | Digilent 410-195 (connected to JA) |
| SystemVerilog | IEEE 1800-2012 or later |

---

## 📚 References

- [NIST FIPS-197 — Advanced Encryption Standard (AES)](https://csrc.nist.gov/publications/detail/fips/197/final)
- [Digilent Zybo Z7 Reference Manual](https://digilent.com/reference/programmable-logic/zybo-z7/reference-manual)
- [Digilent PMOD KYPD Reference Manual](https://digilent.com/reference/pmod/pmodkypd/reference-manual)
- [Xilinx UG901 — Vivado Design Suite User Guide: Synthesis](https://docs.xilinx.com/r/en-US/ug901-vivado-synthesis)

---

## 👤 Author

**Sudeep Babasaheb Kakade**  
Zybo Z7 (Zynq-7000)
