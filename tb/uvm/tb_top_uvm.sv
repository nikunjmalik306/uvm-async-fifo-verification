// ==============================================================================
// File: tb_top_uvm.sv
// Description: Top-level UVM Testbench module with dual asynchronous clocks,
//              virtual interface registration, and SVA instantiation.
// ==============================================================================

`timescale 1ns / 1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "fifo_if.sv"
`include "fifo_seq_item.sv"
`include "fifo_agent.sv"
`include "fifo_scoreboard.sv"
`include "fifo_env.sv"

module tb_top_uvm;

  localparam int DATA_WIDTH = 32;
  localparam int ADDR_WIDTH = 4;

  // Asynchronous Clock Generators:
  // Write clock: 100 MHz (period 10ns)
  // Read clock:  66.6 MHz (period 15ns) - deliberately skewed to stress CDC
  logic wclk = 0;
  logic rclk = 0;

  always #5ns  wclk = ~wclk;
  always #7.5ns rclk = ~rclk;

  // Interface Instance
  fifo_if #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) intf(wclk, rclk);

  // DUT Instance
  async_fifo #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
  ) dut (
    .wclk         (wclk),
    .wrst_n       (intf.wrst_n),
    .winc         (intf.winc),
    .wdata        (intf.wdata),
    .wfull        (intf.wfull),
    .walmost_full (intf.walmost_full),
    .rclk         (rclk),
    .rrst_n       (intf.rrst_n),
    .rinc         (intf.rinc),
    .rdata        (intf.rdata),
    .rempty       (intf.rempty),
    .ralmost_empty(intf.ralmost_empty)
  );

  // Bind SVA Formal Assertions
  fifo_sva #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
  ) u_sva (
    .wclk   (wclk),
    .wrst_n (intf.wrst_n),
    .winc   (intf.winc),
    .wdata  (intf.wdata),
    .wfull  (intf.wfull),
    .wgray  (dut.wgray),
    .rclk   (rclk),
    .rrst_n (intf.rrst_n),
    .rinc   (intf.rinc),
    .rdata  (intf.rdata),
    .rempty (intf.rempty),
    .rgray  (dut.rgray)
  );

  // UVM Configuration & Simulation Start
  initial begin
    uvm_config_db#(virtual fifo_if)::set(null, "*", "vif", intf);

    // Apply asynchronous resets
    intf.wrst_n = 1'b0;
    intf.rrst_n = 1'b0;
    #25ns;
    intf.wrst_n = 1'b1;
    intf.rrst_n = 1'b1;

    run_test("fifo_base_test");
  end

  // Dump VCD
  initial begin
    $dumpfile("uvm_async_fifo.vcd");
    $dumpvars(0, tb_top_uvm);
  end

endmodule
