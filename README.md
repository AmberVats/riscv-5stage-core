# 5-Stage Pipelined RV32IM RISC-V Processor Core

[![SystemVerilog](https://img.shields.io/badge/Language-SystemVerilog-blue.svg)](https://en.wikipedia.org/wiki/SystemVerilog)
[![ISA](https://img.shields.io/badge/ISA-RV32IM-green.svg)](https://riscv.org/)
[![Target FPGA](https://img.shields.io/badge/FPGA-Xilinx%20Artix--7-orange.svg)](https://www.xilinx.com/)
[![Timing](https://img.shields.io/badge/Frequency-125%20MHz-brightgreen.svg)]()
[![Status](https://img.shields.io/badge/Status-Completed%20(All%20Phases)-brightgreen.svg)]()
[![License](https://img.shields.io/badge/License-MIT-purple.svg)](LICENSE)

---

## 📖 Executive Summary & Project Description

The open-standard RISC-V Instruction Set Architecture (ISA) has revolutionized modern compute design. This project implements a synthesizable, high-performance **5-Stage Pipelined RV32IM RISC-V Processor Core** in SystemVerilog, engineered for high clock frequencies and optimal IPC across embedded and SoC application workloads.

The core implements the full unprivileged **RV32I Base Integer ISA** alongside the **RV32M Standard Extension** for hardware multiplication and division. To maximize execution efficiency, the core incorporates a comprehensive **RAW data forwarding network** (EX-to-EX and MEM-to-EX bypasses) eliminating data hazard stalls, an **interlocking hazard detection unit** for load-use dependencies, and a **dynamic Gshare branch predictor with a 64-entry Branch Target Buffer (BTB)** minimizing branch penalty bubbles. Memory connectivity is provided via standard **dual AXI4-Lite master interfaces** (Instruction and Data ports), verified for timing closure at **125 MHz on Xilinx Artix-7 FPGAs**.

---

## 🌟 Key Architectural Highlights

- **5-Stage In-Order Pipeline:**
  - **Fetch (IF):** PC generation, dynamic Gshare branch prediction, instruction memory request.
  - **Decode (ID):** RV32IM instruction decoding, 32x32-bit register file read with internal write-bypass, immediate generation.
  - **Execute (EX):** 32-bit integer ALU, RV32M multiplier/divider, branch resolution, RAW forwarding multiplexers.
  - **Memory (MEM):** Byte/halfword/word alignment, sign/zero extension, AXI4-Lite load/store master.
  - **Write-Back (WB):** Register file commit for ALU, Memory, or Link results.

- **Full RAW Hazard Forwarding & Interlocks:**
  - **Zero-Bubble Arithmetic:** EX $\to$ EX and MEM $\to$ EX forwarding paths allow back-to-back dependent arithmetic instructions to execute without stalls.
  - **1-Cycle Load-Use Interlock:** Automatic pipeline stall when a load instruction is immediately followed by a dependent arithmetic instruction.
  - **Misprediction Recovery:** Single-cycle pipeline flush redirecting PC to correct resolved target address upon branch mispredictions.

- **RV32M Hardware Math Unit:**
  - Full support for `MUL`, `MULH`, `MULHSU`, `MULHU`, `DIV`, `DIVU`, `REM`, `REMU`.
  - Complete compliance with RISC-V ISA corner cases (e.g., division by zero and signed overflow handling).

- **Dynamic Gshare Branch Predictor:**
  - 2-bit Saturating Counters indexed by PC hash XOR Global History Register (GHR).
  - 64-entry Branch Target Buffer (BTB) for single-cycle branch redirection.

- **Industry-Standard Bus Protocols & Timing:**
  - Dual AXI4-Lite Master ports for clean decoupling of instruction and data memories.
  - SDC / XDC timing constraints targeting **125 MHz** on Xilinx Artix-7 (XC7A100T) with zero setup/hold timing violations.

---

## 🏗️ Processor Pipeline Block Diagram

```
 +-----------------------------------------------------------------------------------+
 |                              5-STAGE RV32IM PIPELINE                              |
 |                                                                                   |
 |  [ FETCH ]   ===>   [ DECODE ]   ===>   [ EXECUTE ]   ===>   [ MEMORY ]   ===> [ WB ]
 |     |                   |                    |                    |              |
 |     v                   v                    v                    v              v
 | [ PC Gen & ]       [ 32x32 Reg ]        [ ALU & M-Ext ]      [ AXI4-Lite ]  [ RegFile ]
 | [ Gshare   ]       [ Immediate ]        [ Forward Mux ]      [ Load/Store]  [ Write   ]
 | [ Predict  ]       [ Decode    ]        [ Branch Eval ]      [ Alignment ]  [ Commit  ]
 |                                                                                   |
 |        ^                   ^                    ^                    |            |
 |        |                   |                    |                    |            |
 |        +--- Hazard Unit <--+--------------------+--------------------+------------+
 |             (Stalls & Flushes)                  |                    |
 |                                                 +-- Forwarding Unit -+
 +-----------------------------------------------------------------------------------+
```

---

## 📁 Repository Structure

```
riscv-5stage-core/
├── docs/
│   └── riscv_core_spec.md       # Microarchitecture specification & timing budget
├── rtl/
│   ├── rv32_pkg.sv              # Opcodes, types, and pipeline structures
│   ├── regfile.sv               # 32x32-bit dual-read single-write register file
│   ├── alu.sv                   # Integer ALU & branch comparator
│   ├── mul_div.sv               # RV32M hardware multiplier & divider unit
│   ├── gshare_predictor.sv      # Dynamic Gshare branch predictor + BTB
│   ├── hazard_unit.sv           # Load-use stall and branch flush hazard unit
│   ├── forwarding_unit.sv       # EX-to-EX & MEM-to-EX RAW forwarding unit
│   ├── axi_lite_master.sv       # AXI4-Lite master bus engine
│   └── riscv_core_top.sv        # Integrated 5-stage RV32IM processor core top
├── tb/
│   └── tb_riscv_core.sv         # Comprehensive self-checking verification testbench
├── synth/
│   └── artix7_constraints.xdc   # SDC / XDC timing constraints for Artix-7 @ 125 MHz
└── README.md
```

---

## 🚦 Implementation & Verification Status

- [x] **Phase 3.1: 5-Stage RV32I Datapath**
  - [x] Instruction Fetch, Decode, Execute, Memory, Write-back pipeline
  - [x] 32x32-bit Register file with x0 hardwired to zero (`regfile.sv`)
  - [x] Integer ALU supporting all RV32I arithmetic/logic operations (`alu.sv`)
- [x] **Phase 3.2: Hazard Detection & Data Forwarding**
  - [x] Load-Use hazard 1-cycle pipeline interlock (`hazard_unit.sv`)
  - [x] Full bypass RAW forwarding network (`forwarding_unit.sv`)
- [x] **Phase 3.3: RV32M Extension (Multiply/Divide)**
  - [x] Hardware 32x32 multiplier (MUL, MULH, MULHSU, MULHU) (`mul_div.sv`)
  - [x] Hardware integer divider & remainder unit (DIV, DIVU, REM, REMU)
- [x] **Phase 3.4: Dynamic Gshare Branch Prediction**
  - [x] 2-bit Saturating Counters with Global History Register (`gshare_predictor.sv`)
  - [x] 64-entry Branch Target Buffer (BTB) for single-cycle branch redirection
- [x] **Phase 3.5: Memory Interface & Timing Closure**
  - [x] Dual AXI4-Lite master ports for Instruction and Data memory (`axi_lite_master.sv`)
  - [x] Comprehensive self-checking verification suite (`tb_riscv_core.sv`)
  - [x] XDC timing constraints targeting 125 MHz on Xilinx Artix-7 (`artix7_constraints.xdc`)

---

## 🔬 Running Simulations

Run the complete self-checking testbench (executes RV32I arithmetic, RV32M multiply/divide, load-use stalls, forwarding validation, and memory operations):
```bash
cd tb
iverilog -g2012 -o sim_riscv_core ../rtl/*.sv tb_riscv_core.sv
vvp sim_riscv_core
```