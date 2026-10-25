# UVM 1.2 Verification of Dual-Clock Asynchronous FIFO with SVA & CDC Analysis

An industrial-grade Universal Verification Methodology (UVM 1.2) testbench and synthesizable SystemVerilog implementation of a multi-clock domain Asynchronous FIFO. Features dual-frequency Clock Domain Crossing (CDC), Gray-code pointer synchronization with 2-FF metastability protection, formal SystemVerilog Assertions (SVA), decoupled TLM analysis scoreboards, and full coverage.

Engineered to meet Qualcomm / Tier-1 semiconductor design verification (DV) standards.

---

## Architectural Block Diagram

```text
+===================================================================================================================+
|                                    DUAL-CLOCK ASYNCHRONOUS FIFO ARCHITECTURE                                      |
+===================================================================================================================+
|                                                                                                                   |
|      WRITE CLOCK DOMAIN (wclk: 100 MHz)                           READ CLOCK DOMAIN (rclk: 66.6 MHz)              |
|                                                                                                                   |
|  wdata                                                                                          rdata             |
|  ======>==================+                                                 +==================>====              |
|                           |                                                 |                                     |
|  winc   +---------------+ |   +-----------------------------------------+   | +---------------+ rinc              |
|  ----->-| Write Control | |   |        Dual-Port Memory Array           |   | | Read Control  |------             |
|         | & Binary/Gray |-+->-|          (16 Depth x 32b Data)          |->-+-| & Binary/Gray |                   |
|         | Pointer Logic |     |                                         |     | Pointer Logic |                   |
|         +---------------+     +-----------------------------------------+     +---------------+                   |
|                 | (wgray)                          ^                                  | (rgray)                   |
|                 v                                  |                                  v                           |
|                 |                           +-------------+                           |                           |
|                 |                           | Memory Read |                           |                           |
|                 |                           +-------------+                           |                           |
|                 |                                                                     |                           |
|                 |               +-----------------------------+                       |                           |
|                 +-------------->| 2-FF Synchronizer (w2r CDC) |---------------------->+                           |
|                                 +-----------------------------+                       |                           |
|                                                                                       v                           |
|                                 +-----------------------------+             +--------------------+                |
|                 +<--------------| 2-FF Synchronizer (r2w CDC) |<------------| Empty Flag & Level |-> rempty       |
|                 |               +-----------------------------+             +--------------------+                |
|                 v                                                                                                 |
|      +---------------------+                                                                                      |
|      | Full Flag & Level   |-> wfull                                                                              |
|      +---------------------+                                                                                      |
|                                                                                                                   |
+===================================================================================================================+
```

---

## Verification Architecture & Methodology

```text
+===================================================================================================================+
|                                        UVM 1.2 TESTBENCH CLASS HIERARCHY                                         |
+===================================================================================================================+
|                                                                                                                   |
|                                        [ fifo_concurrent_stress_test ]                                             |
|                                                      |                                                            |
|                                              [   fifo_env   ]                                                     |
|                                                      |                                                            |
|              +---------------------------------------+---------------------------------------+                    |
|              |                                       |                                       |                    |
|      [  fifo_wr_agent  ]                     [  fifo_rd_agent  ]                    [ fifo_scoreboard ]           |
|      |                 |                     |                 |                    |                 |           |
|  +-------+         +-------+             +-------+         +-------+                | uvm_tlm_        |           |
|  |  SQR  |         |  MON  |             |  SQR  |         |  MON  |                | analysis_fifo   |           |
|  +-------+         +-------+             +-------+         +-------+                | & Golden Queue  |           |
|      |                 |                         |                 |                +-----------------+           |
|      v                 v                         v                 v                         ^                    |
|  [  DRV  ]             +-------------------------+-----------------+-------------------------+                    |
|      |                                           |                                                                |
|      v                                           v                                                                |
|      |                               [ fifo_coverage ] (Functional Covergroups & Crosses)                         |
|      |                                                                                                            |
|      +=========================> [ Virtual Interface (fifo_if) ] <=========================+                      |
|                                              |                                                                    |
|                                              v                                                                    |
|                                    [ async_fifo (DUT) ]                                                           |
|                                              |                                                                    |
|                                              v                                                                    |
|                        [ fifo_sva (SystemVerilog Formal Assertions) ]                                             |
+===================================================================================================================+
```

### Verification Highlights & Fixes
1. **Asynchronous TLM Synchronization**:
   - Write and Read monitors deliver transactions to the scoreboard through dedicated `uvm_tlm_analysis_fifo` channels.
   - Eliminates callback race conditions between independent asynchronous clock domains ($wclk$ and $rclk$).
2. **Pipelined Read Monitor**:
   - Accurately captures consecutive back-to-back read pops without skipping cycles on back-to-back bursts.
3. **Strict Zero-Tolerance Fail Criteria**:
   - Scoreboard audit verifies `mismatch_count == 0`, `total_pushed == total_popped`, `total_popped > 0`, and `expected_queue.size() == 0`.
   - Any failure or timeout triggers immediate non-zero termination (`$fatal(1)` or `` `uvm_fatal ``), ensuring CI/CD regressions fail fast.
4. **Multi-Domain Frequency Skew Testing**:
   - Stress-tested under **Fast Write / Slow Read** ($100\text{ MHz} \rightarrow 66.7\text{ MHz}$) and **Slow Write / Fast Read** ($40\text{ MHz} \rightarrow 125\text{ MHz}$).
   - Attempted illegal overflow while `wfull == 1` and illegal underflow while `rempty == 1` verified safe.
5. **SystemVerilog Assertions (SVA)**:
   - `p_no_overflow`: Ensures `winc` never asserts when `wfull` is active.
   - `p_no_underflow`: Ensures `rinc` never asserts when `rempty` is active.
   - `p_gray_single_bit`: Formally asserts Gray pointer transitions never toggle more than 1 bit at any clock edge.

---

## Directory Structure

```text
uvm-async-fifo-verification/
├── rtl/
│   ├── sync_2ff.sv                 # 2-FF Metastability CDC Synchronizer
│   ├── gray_counter.sv             # Binary-to-Gray and Gray-to-Binary converters
│   ├── async_fifo.sv               # Dual-Clock Asynchronous FIFO RTL
│   └── fifo_sva.sv                 # Dual-Mode SystemVerilog Assertions (Formal SVA + Procedural)
├── tb/
│   ├── uvm/                        # Complete UVM 1.2 Class Environment
│   │   ├── fifo_if.sv              # Dual-clock SystemVerilog interface with clocking blocks
│   │   ├── fifo_seq_item.sv        # Sequence items with delay and pattern distributions
│   │   ├── fifo_agent.sv           # Pipelined drivers, monitors, and agents
│   │   ├── fifo_scoreboard.sv     # TLM analysis FIFO scoreboard & functional covergroups
│   │   ├── fifo_env.sv             # Test sequences and UVM test definitions
│   │   └── tb_top_uvm.sv           # Top-level UVM test harness
│   └── sim/
│       └── tb_async_fifo_selfcheck.sv # Standalone self-checking testbench (816+ vectors)
├── syn/
│   ├── synth.ys                    # Open-source Yosys synthesis script
│   └── yosys_synth.log             # Raw synthesis gate-level report
└── sim/
    └── Makefile                    # Unified build Makefile for Icarus, Questa, VCS, Xcelium, Yosys
```

---

## Simulation & Verification Results

### Standalone Self-Checking Dual-Clock Regression (Icarus Verilog / VVP)
Simulated with dynamic clock ratio reversal, full/empty flag corner cases, illegal push/pop injection, and concurrent asynchronous stress:

```text
================================================================
     QUALCOMM HW-DV GRADE ASYNCHRONOUS FIFO TESTBENCH          
     Depth: 16 entries | Data Width: 32 bits                  
================================================================

[TEST 1] Burst Write 16 Items to Fill FIFO...
[PASSED] wfull and walmost_full correctly asserted at capacity.

[TEST 2] Attempting Overflow Write when wfull == 1...
ERROR: ../rtl/fifo_sva.sv:37: [SVA_VIOLATION @ 465000] OVERFLOW DETECTED: Write asserted while FIFO is FULL!
       Time: 465000  Scope: tb_async_fifo_selfcheck.u_sva
[PASSED] Overflow write blocked; internal state preserved.

[TEST 3] Burst Read 16 Items to Empty FIFO...
[PASSED] rempty and ralmost_empty correctly asserted when empty.

[TEST 4] Attempting Underflow Read when rempty == 1...
ERROR: ../rtl/fifo_sva.sv:43: [SVA_VIOLATION @ 1328000] UNDERFLOW DETECTED: Read asserted while FIFO is EMPTY!
       Time: 1327500  Scope: tb_async_fifo_selfcheck.u_sva
[PASSED] Underflow read blocked; pointers intact.

[TEST 5] Concurrent Random Push/Pop Stress (500 items, Fast Write / Slow Read)...

[TEST 6] Clock Skew Reversal (Slow Write = 40MHz, Fast Read = 125MHz, 300 items)...

================================================================
          ASYNCHRONOUS FIFO SCOREBOARD FINAL AUDIT              
================================================================
Total Transactions Pushed:       816
Total Transactions Popped:       816
Data Matches Confirmed:          816
Data Mismatches:                 0
Golden Queue Remainder:          0 (Must be 0)
FIFO Empty Flag on Completion:   1 (Must be 1)
================================================================

################################################################
###       ALL 816 ASYNC FIFO TESTS PASSED WITH 100% INTEGRITY! ###
###       CDC SYNCHRONIZATION AND SVA ASSERTIONS VERIFIED   ###
################################################################
```

---

## Yosys Gate-Level Synthesis Results

Synthesized with Yosys Open SYnthesis Suite (`syn/synth.ys`):

```text
=== async_fifo (design hierarchy) ===

   Wires:               104
   Wire bits:           381
   Public wires:         44
   Public wire bits:    210
   Ports:                24
   Port bits:           118

   Cell Count:          224
     $_AND_              43
     $_DFF_PN0_          40   (Active-low async-reset DFFs for CDC & pointers)
     $_DFF_PN1_           2
     $_MUX_              36
     $_NOT_              23
     $_OR_               25
     $_XOR_              54   (Binary <-> Gray converters)
     $mem_v2              1   (Dual-port static RAM array)

   Inferred Latches:      0   (Strictly synchronous, lint-clean)
```

---

## How to Run

### 1. Standalone Simulation (Open-Source / macOS)
```bash
cd sim
make sim       # Compiles and executes full 816-vector regression
make wave      # Launches GTKWave to view dual-clock CDC waveforms
```

### 2. Yosys Synthesis
```bash
cd sim
make synth     # Synthesizes gate-level netlist and prints cell report
```

### 3. Commercial UVM 1.2 Simulators
```bash
cd sim
# Synopsys VCS
make uvm_vcs TESTNAME=fifo_concurrent_stress_test

# Siemens QuestaSim
make uvm_questa TESTNAME=fifo_concurrent_stress_test

# Cadence Xcelium
make uvm_xcelium TESTNAME=fifo_concurrent_stress_test
```
