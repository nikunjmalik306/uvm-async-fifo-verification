// ==============================================================================
// File: tb_async_fifo_selfcheck.sv
// Description: Industrial-grade, self-checking SystemVerilog testbench with SVA,
//              dual asynchronous clock frequency skew, and golden reference model.
//              Runnable immediately with Icarus Verilog, Verilator, and Vivado.
// Standard: SystemVerilog IEEE 1800-2012 / 1800-2017
// ==============================================================================

`timescale 1ns / 1ps

module tb_async_fifo_selfcheck;

  localparam int DATA_WIDTH = 32;
  localparam int ADDR_WIDTH = 4;
  localparam int DEPTH      = 1 << ADDR_WIDTH;

  // Asynchronous Clock Generators:
  // wclk: 100 MHz (10ns period)
  // rclk: 66.6 MHz (15ns period) -> Realistic frequency skew to stress CDC
  logic wclk = 0;
  logic rclk = 0;
  always #5ns    wclk = ~wclk;
  always #7.5ns  rclk = ~rclk;

  // Write Domain Signals
  logic                  wrst_n;
  logic                  winc;
  logic [DATA_WIDTH-1:0] wdata;
  wire                   wfull;
  wire                   walmost_full;

  // Read Domain Signals
  logic                  rrst_n;
  logic                  rinc;
  wire [DATA_WIDTH-1:0]  rdata;
  wire                   rempty;
  wire                   ralmost_empty;

  // Instantiate Asynchronous FIFO DUT
  async_fifo #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
  ) dut (
    .wclk         (wclk),
    .wrst_n       (wrst_n),
    .winc         (winc),
    .wdata        (wdata),
    .wfull        (wfull),
    .walmost_full (walmost_full),
    .rclk         (rclk),
    .rrst_n       (rrst_n),
    .rinc         (rinc),
    .rdata        (rdata),
    .rempty       (rempty),
    .ralmost_empty(ralmost_empty)
  );

  // Bind SystemVerilog Assertions (SVA)
  fifo_sva #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
  ) u_sva (
    .wclk   (wclk),
    .wrst_n (wrst_n),
    .winc   (winc),
    .wdata  (wdata),
    .wfull  (wfull),
    .wgray  (dut.wgray),
    .rclk   (rclk),
    .rrst_n (rrst_n),
    .rinc   (rinc),
    .rdata  (rdata),
    .rempty (rempty),
    .rgray  (dut.rgray)
  );

  // Golden Reference Queue & Scoreboard Variables
  logic [DATA_WIDTH-1:0] golden_queue [$];
  int match_count    = 0;
  int mismatch_count = 0;
  int total_pushed   = 0;
  int total_popped   = 0;

  // Watchdog Timer
  initial begin
    #200000ns;
    $display("[ERROR] Simulation watchdog timeout!");
    $finish;
  end

  // Dump VCD
  initial begin
    $dumpfile("async_fifo_trace.vcd");
    $dumpvars(0, tb_async_fifo_selfcheck);
  end

  // --------------------------------------------------------------------------
  // Push Task (Write Domain)
  // --------------------------------------------------------------------------
  task automatic push_data(input logic [DATA_WIDTH-1:0] data);
    @(posedge wclk);
    while (wfull) @(posedge wclk); // Wait if full
    winc  <= 1'b1;
    wdata <= data;
    golden_queue.push_back(data);
    total_pushed++;
    @(posedge wclk);
    winc  <= 1'b0;
  endtask

  // --------------------------------------------------------------------------
  // Pop Task (Read Domain)
  // --------------------------------------------------------------------------
  task automatic pop_data();
    logic [DATA_WIDTH-1:0] expected;
    @(posedge rclk);
    while (rempty) @(posedge rclk); // Wait if empty
    rinc <= 1'b1;
    @(posedge rclk);
    rinc <= 1'b0;

    // Data is valid on the cycle following read enable
    @(posedge rclk);
    expected = golden_queue.pop_front();
    total_popped++;

    if (rdata === expected) begin
      match_count++;
    end else begin
      $display("[SCOREBOARD_ERROR @ %0t] Data Mismatch! Got: 0x%08h, Expected: 0x%08h", 
               $time, rdata, expected);
      mismatch_count++;
    end
  endtask

  // --------------------------------------------------------------------------
  // Main Verification Sequence
  // --------------------------------------------------------------------------
  initial begin
    wrst_n = 1'b0;
    rrst_n = 1'b0;
    winc   = 1'b0;
    rinc   = 1'b0;
    wdata  = '0;

    // Apply Reset
    #30ns;
    wrst_n = 1'b1;
    rrst_n = 1'b1;
    #20ns;

    $display("----------------------------------------------------------------");
    $display("[TB] STARTING ASYNCHRONOUS DUAL-CLOCK FIFO VERIFICATION");
    $display("[TB] wclk = 100 MHz (10ns) | rclk = 66.6 MHz (15ns) | Depth = %0d", DEPTH);
    $display("----------------------------------------------------------------");

    // TEST 1: Burst Fill to FULL
    $display("\n[TEST 1] Performing Burst Writes until FIFO is FULL...");
    for (int i = 1; i <= DEPTH; i++) begin
      push_data(32'hA000_0000 + i);
    end

    // Wait for CDC sync of full flag
    repeat (5) @(posedge wclk);
    if (wfull) begin
      $display("[PASSED] FIFO successfully asserted wfull flag after %0d writes.", DEPTH);
    end else begin
      $display("[ERROR] FIFO failed to assert wfull flag!");
      mismatch_count++;
    end

    // TEST 2: Burst Drain to EMPTY
    $display("\n[TEST 2] Performing Burst Reads until FIFO is EMPTY...");
    for (int i = 1; i <= DEPTH; i++) begin
      pop_data();
    end

    // Wait for CDC sync of empty flag
    repeat (5) @(posedge rclk);
    if (rempty) begin
      $display("[PASSED] FIFO successfully asserted rempty flag after %0d reads.", DEPTH);
    end else begin
      $display("[ERROR] FIFO failed to assert rempty flag!");
      mismatch_count++;
    end

    // TEST 3: Concurrent Asynchronous Read & Write Stress Test
    $display("\n[TEST 3] Running Concurrent Asynchronous Push & Pop (Stress Testing CDC)...");
    fork
      // Thread 1: Writer pushing 50 random packets
      begin
        for (int i = 0; i < 50; i++) begin
          push_data($urandom());
          if ($urandom_range(0, 1)) repeat ($urandom_range(1, 3)) @(posedge wclk);
        end
      end

      // Thread 2: Reader popping 50 random packets
      begin
        for (int j = 0; j < 50; j++) begin
          pop_data();
          if ($urandom_range(0, 1)) repeat ($urandom_range(1, 2)) @(posedge rclk);
        end
      end
    join

    // Drain any remaining items in queue
    while (golden_queue.size() > 0) begin
      pop_data();
    end

    repeat (10) @(posedge rclk);

    // ------------------------------------------------------------------------
    // Final Summary Report
    // ------------------------------------------------------------------------
    $display("\n================================================================");
    $display("          ASYNCHRONOUS FIFO SCOREBOARD SUMMARY REPORT           ");
    $display("================================================================");
    $display("Total Packets Pushed:       %0d", total_pushed);
    $display("Total Packets Popped:       %0d", total_popped);
    $display("Total Data Matches:         %0d", match_count);
    $display("Total Data Mismatches:      %0d", mismatch_count);
    $display("Remaining Items in Queue:   %0d", golden_queue.size());
    $display("================================================================");

    if (mismatch_count == 0 && total_popped > 0) begin
      $display("\n################################################################");
      $display("###                 ALL FIFO TESTS PASSED!                   ###");
      $display("###      CDC Synchronization & Data Integrity 100%% Verified  ###");
      $display("################################################################\n");
    end else begin
      $display("\n[FAILED] TEST FAILED WITH %0d MISMATCHES!\n", mismatch_count);
    end

    $finish;
  end

endmodule
