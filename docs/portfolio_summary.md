# Portfolio Summary: UVM Dual-Clock Asynchronous FIFO Verification

**Target Roles at Qualcomm:**  
- Design Verification Engineer (UVM / SVA / Constrained-Random Verification)  
- Digital ASIC Design Engineer (SoC Interconnect / CDC Specialist)  
- SoC Emulation & Validation Engineer  

---

## 1. Resume-Ready Engineering Bullets (STAR Format)

- **Architected and verified a dual-clock asynchronous FIFO in SystemVerilog**, implementing Clifford Cummings' Gray-code CDC pointer synchronization, 2-flip-flop synchronizers with `ASYNC_REG` attributes, and lookahead full/empty flag generation.
- **Constructed a complete UVM 1.2 verification environment**, including parameterized sequence items, driver, pipelined read monitor, TLM analysis FIFOs, functional coverage collector, and a timing-independent scoreboard with zero-time delta-cycle settlement and causal underflow detection.
- **Implemented a strict Two-Tier verification methodology**: Tier 1 executes automated GitHub Actions CI running dual-clock skew reversal regressions (816 vectors), concurrent SVA assertions, Verilator `-Wall` linting, and dynamic regression artifact logging; Tier 2 provides a fully reproducible commercial UVM 1.2 suite with checked-in unabridged raw logs.
- **Verified clock-domain crossing robustness across reversed frequency ratios** ($100\text{ MHz} \to 66.7\text{ MHz}$ and $40\text{ MHz} \to 125\text{ MHz}$), confirming zero data corruption, zero lost items, and complete queue drainage upon test termination.
- **Synthesized design with Yosys (232 standard cells, 0 latches)** and achieved 100% clean Verilator lint checks, ensuring production-grade digital ASIC readiness.

---

## 2. Key Verification Metrics & Evidence

| Verification Metric | Result / Status | Evidence / Artifact |
| :--- | :--- | :--- |
| **Total Test Transactions** | 816 transactions verified | `sim/uvm_questa_regression.log` & `sim/simulation.log` |
| **Data Mismatches** | 0 mismatches | Self-checking scoreboard audit |
| **Golden Queue Remainder** | 0 items (100% drained) | Terminal scoreboard drain assertion |
| **Clock Ratios Tested** | Fast W / Slow R (1.5:1) & Slow W / Fast R (1:3.125) | Standalone Tests 5 and 6 |
| **SVA Assertions Active** | Overflow, Underflow, Reset checks | `rtl/fifo_sva.sv` bound to interface |
| **Verilator Lint Checks** | 0 warnings, 0 errors | `-Wall` linting passing in GitHub Actions CI |
| **Live CI Artifact Logging** | Dynamic simulation log uploaded | GitHub Actions `actions/upload-artifact@v4` |
| **Gate Count (Yosys)** | 232 cells, 0 inferred latches | `syn/yosys_synth.log` netlist report |

---

## 3. Key Engineering Tradeoffs & Design Decisions

1. **Gray Code vs. Binary Pointers for CDC:**
   - *Tradeoff:* Converting binary pointers to Gray code and back introduces XOR gate logic into the pointer datapath.
   - *Design Choice:* In an asynchronous interface, binary pointers are catastrophic because multi-bit transitions sampled during setup/hold windows can cause metastability and corrupted addresses. Gray code changes only 1 bit per step, guaranteeing that any sampled pointer is either the current or previous valid value.

2. **Pessimistic Flag Generation:**
   - *Tradeoff:* Waiting 2 clock cycles to synchronize the pointer means the FIFO signals `wfull` or `rempty` slightly earlier than reality.
   - *Design Choice:* Pessimism is universally preferred in mission-critical ASIC design because it is strictly safe—it prevents data loss (overflow) and reading stale memory (underflow). Throughput drops negligibly, while functional correctness is absolute.

3. **Two-Tier Verification Strategy:**
   - *Tradeoff:* Commercial UVM simulators (Questa, VCS, Xcelium) require expensive proprietary licenses not available on public GitHub Actions runners.
   - *Design Choice:* Deployed an industry-standard two-tier strategy. Tier 1 runs open-source automated CI with SystemVerilog SVA assertions, dual-clock skew testing, and dynamic artifact publishing. Tier 2 provides full UVM 1.2 class hierarchy with complete, unabridged Questa simulation logs and scripts for commercial EDA environments.

---

## 4. Technical Interview Talking Points

- **Q: Why does the write full condition compare the MSB, 2nd MSB, and lower bits differently in Gray code?**  
  *Answer:* In Gray code of width $N$, when the binary counter wraps around from $2^{N-1}-1$ to $2^{N-1}$, the MSB flips, and the next $(N-1)$ bits are symmetric reflections of the first half. Therefore, for the write pointer to catch up to the read pointer after wrapping around (full condition), the two most significant bits must be inverted (`wgray[N:N-1] == ~rgray[N:N-1]`), while the remaining lower bits must match exactly (`wgray[N-2:0] == rgray[N-2:0]`).

- **Q: What is the purpose of `(* ASYNC_REG = "TRUE" *)` in your 2-FF synchronizer?**  
  *Answer:* This synthesis attribute instructs the EDA place-and-route tool to place the two synchronizer flip-flops in physical proximity in the same slice/tile on silicon. This minimizes interconnect RC delay, maximizing the settling time available for metastable resolution and drastically increasing the Mean Time Between Failures (MTBF).

- **Q: How did you fix the scoreboard race condition between asynchronous write and read monitors?**  
  *Answer:* Previously, testbenches used arbitrary `#100ns;` delays to wait for scoreboard comparison. I removed all timing delays and implemented a delta-cycle settlement architecture (`#0`). When the read monitor captures a popped transaction, it settles all delta cycles, immediately checks queue depth, and flags an immediate causal underflow error if the golden queue is empty.
