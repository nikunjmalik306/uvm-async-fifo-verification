# UVM 1.2 Verification of Dual-Clock Asynchronous FIFO with SVA & CDC Analysis

An industrial-grade Universal Verification Methodology (UVM 1.2) testbench and synthesizable SystemVerilog implementation of a multi-clock domain Asynchronous FIFO. Features dual-frequency Clock Domain Crossing (CDC), Gray-code pointer synchronization with 2-FF metastability protection, formal SystemVerilog Assertions (SVA), and a complete UVM class hierarchy.

Engineered to meet Qualcomm / Tier-1 semiconductor design verification (DV) standards.

---

## Architectural Block Diagram

```
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

## Verification & UVM Architecture

```
+===================================================================================================================+
|                                        UVM 1.2 TESTBENCH CLASS HIERARCHY                                         |
+===================================================================================================================+
|                                                                                                                   |
|                                              [ fifo_base_test ]                                                   |
|                                                      |                                                            |
|                                              [   fifo_env   ]                                                     |
|                                                      |                                                            |
|              +---------------------------------------+---------------------------------------+                    |
|              |                                       |                                       |                    |
|      [  fifo_wr_agent  ]                     [  fifo_rd_agent  ]                    [ fifo_scoreboard ]           |
|      |                 |                     |                 |                    |                 |           |
|  +-------+         +-------+             +-------+         +-------+                | Golden Queue    |           |
|  |  SQR  |         |  MON  |             |  SQR  |         |  MON  |                | Reference Model |           |
|  +-------+         +-------+             +-------+         +-------+                +-----------------+           |
|      | (seq_item)      | (ap)                | (seq_item)      | (ap)                        ^                    |
|      v                 |                     v                 |                             |                    |
|  +-------+             +---------------------+-----------------+-----------------------------+                    |
|  |  DRV  |                                   | (Analysis Port Broadcasting)                                       |
|  +-------+                                   v                                                                    |
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

### Key Verification Features
1. **Clock Domain Crossing (CDC) Integrity**:
   - Validates multi-clock asynchronous behavior under clock frequency skew ($wclk = 100\text{ MHz}$, $rclk = 66.6\text{ MHz}$).
   - `sync_2ff.sv` prevents metastability with `(* ASYNC_REG = "TRUE" *)`.
   - Gray-code pointer encoding ensures single-bit transitions per clock tick.
2. **SystemVerilog Formal Assertions (SVA)**:
   - **No Overflow (`p_no_overflow`)**: Flags an assertion error if a write is issued when `wfull` is asserted.
   - **No Underflow (`p_no_underflow`)**: Flags an assertion error if a read is issued when `rempty` is asserted.
   - **Single-bit Gray Transition (`p_gray_single_bit`)**: Formally verifies that pointers never transition by more than 1 bit between clock edges.
3. **UVM Scoreboard & Golden Reference Model**:
   - Employs TLM `uvm_analysis_imp` broadcasting from write and read monitors into an internal expected FIFO queue.
   - Self-checking transaction evaluation guarantees zero dropped packets and strict in-order arrival.
4. **Functional Coverage**:
   - Bins for critical data patterns: All-Zeros, All-Ones, Alternating `0x5555_5555`, Alternating `0xAAAA_AAAA`, and random values.
   - Cross-coverage between transaction types and full/empty flag transitions.

---

## Directory Structure

```text
uvm-async-fifo-verification/
├── rtl/
│   ├── sync_2ff.sv                 # 2-FF Metastability CDC Synchronizer
│   ├── gray_counter.sv             # Binary-to-Gray and Gray-to-Binary converters
│   ├── async_fifo.sv               # Dual-Clock Asynchronous FIFO RTL
│   └── fifo_sva.sv                 # SystemVerilog Formal Assertions (SVA)
├── tb/
│   ├── uvm/                        # Full UVM 1.2 Testbench (VCS/Questa/EDA Playground)
│   │   ├── fifo_if.sv              # Dual-clock SystemVerilog interface
│   │   ├── fifo_seq_item.sv        # UVM Sequence Item with distribution constraints
│   │   ├── fifo_agent.sv           # Write & Read Drivers, Monitors, and Agents
│   │   ├── fifo_scoreboard.sv     # TLM Scoreboard & Functional Coverage subscriber
│   │   ├── fifo_env.sv             # UVM Environment & Sequence library
│   │   └── tb_top_uvm.sv           # Top UVM module with `run_test()`
│   └── sim/
│       └── tb_async_fifo_selfcheck.sv # Standalone self-checking testbench for macOS
├── syn/
│   └── synth.ys                    # Open-source Yosys synthesis script
└── sim/
    └── Makefile                    # macOS build Makefile (Icarus Verilog + GTKWave)
```

---

## Simulation & Verification Results

Executed on macOS with asynchronous clock skew ($100\text{ MHz} \leftrightarrow 66.6\text{ MHz}$) and randomized packet delays:

```text
----------------------------------------------------------------
[TB] STARTING ASYNCHRONOUS DUAL-CLOCK FIFO VERIFICATION
[TB] wclk = 100 MHz (10ns) | rclk = 66.6 MHz (15ns) | Depth = 16
----------------------------------------------------------------

[TEST 1] Performing Burst Writes until FIFO is FULL...
[PASSED] FIFO successfully asserted wfull flag after 16 writes.

[TEST 2] Performing Burst Reads until FIFO is EMPTY...
[PASSED] FIFO successfully asserted rempty flag after 16 reads.

[TEST 3] Running Concurrent Asynchronous Push & Pop (Stress Testing CDC)...

================================================================
          ASYNCHRONOUS FIFO SCOREBOARD SUMMARY REPORT           
================================================================
Total Packets Pushed:       66
Total Packets Popped:       66
Total Data Matches:         66
Total Data Mismatches:      0
Remaining Items in Queue:   0
================================================================

################################################################
###                 ALL FIFO TESTS PASSED!                   ###
###      CDC Synchronization & Data Integrity 100% Verified  ###
################################################################
```

---

## Quick Start on macOS

```bash
# 1. Run simulation with Icarus Verilog
cd sim
make sim

# 2. View waveforms in GTKWave
make wave

# 3. Run Yosys synthesis
make synth
```
