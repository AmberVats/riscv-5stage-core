# 5-Stage Pipelined RV32IM RISC-V Processor Core Specification

## 1. Architectural Overview
The **RV32IM Processor Core** is a synthesizable, high-frequency 5-stage classic RISC pipeline implementing the unprivileged RISC-V RV32I Base Integer Instruction Set and RV32M Standard Extension for Integer Multiplication and Division.

---

## 2. 5-Stage Pipeline Architecture

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

## 3. Microarchitectural Features

### 3.1 5 Pipeline Stages:
1. **Fetch (IF):** PC calculation, Gshare branch prediction & BTB target lookup, Instruction memory request.
2. **Decode (ID):** Instruction decoding, immediate field extension (I, S, B, U, J types), Dual-port register file read.
3. **Execute (EX):** ALU operations, RV32M hardware multiplier/divider, branch target & condition evaluation, RAW operand forwarding multiplexing.
4. **Memory (MEM):** Data memory load/store via AXI4-Lite, byte/halfword/word alignment, sign/zero extension.
5. **Write-Back (WB):** Register file commit for ALU, Memory Load, or Jump link results.

### 3.2 Hazard Mitigation:
- **RAW Data Hazards:** Full bypass forwarding network (EX $\to$ EX, MEM $\to$ EX) allowing zero-bubble execution of back-to-back arithmetic instructions.
- **Load-Use Hazards:** Automatic 1-cycle pipeline interlock (stalls IF and ID stages, injects NOP bubble into EX stage).
- **Control Hazards:** Branch condition evaluated in EX stage; on misprediction, pipeline flushes IF/ID and ID/EX registers and redirects PC to the resolved target.

### 3.3 Dynamic Gshare Branch Predictor:
- Combines PC address bits with an $N$-bit Global History Register (GHR) via XOR to index a table of 2-bit Saturating Counters:
  - `2'b00`: Strongly Not Taken
  - `2'b01`: Weakly Not Taken
  - `2'b10`: Weakly Taken
  - `2'b11`: Strongly Taken
- 64-entry Branch Target Buffer (BTB) for single-cycle target address generation.

---

## 4. Target Synthesis & Timing Constraints
- **Target Technology:** Xilinx Artix-7 (XC7A100T-1CSG324C)
- **Target Clock Frequency:** $125 \text{ MHz}$ ($T_{\text{clk}} = 8.0 \text{ ns}$)
- **Constraint Strategy:** SDC / XDC timing constraints with zero setup/hold timing violations.
