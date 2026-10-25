// ==============================================================================
// File: fifo_scoreboard.sv
// Description: Industrial UVM Scoreboard with decoupled TLM analysis FIFOs for 
//              CDC domain crossing, golden reference model, and functional coverage.
// Features:
//   - Asynchronous clock domain decoupling using uvm_tlm_analysis_fifo
//   - Strict drain validation: expected_queue must be empty at end of test
//   - Strict transaction balance: total_pushed == total_popped
//   - Non-zero simulation exit via `uvm_fatal on any verification failure
// Standard: SystemVerilog IEEE 1800-2012 / UVM 1.2
// ==============================================================================

`timescale 1ns / 1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

class fifo_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(fifo_scoreboard)

  // TLM Analysis FIFOs decouple asynchronous monitor threads
  uvm_tlm_analysis_fifo #(fifo_seq_item) wr_fifo;
  uvm_tlm_analysis_fifo #(fifo_seq_item) rd_fifo;

  // Golden Reference Model Queue
  logic [31:0] expected_queue [$];

  // Tracking Statistics
  int unsigned match_count    = 0;
  int unsigned mismatch_count = 0;
  int unsigned total_pushed   = 0;
  int unsigned total_popped   = 0;

  function new(string name = "fifo_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    wr_fifo = new("wr_fifo", this);
    rd_fifo = new("rd_fifo", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    fifo_seq_item wr_item;
    fifo_seq_item rd_item;
    logic [31:0]  exp_data;

    fork
      // Write Domain Listener Thread (wclk domain)
      forever begin
        wr_fifo.get(wr_item);
        expected_queue.push_back(wr_item.data);
        total_pushed++;
        `uvm_info("SCB_PUSH", $sformatf("Captured PUSH [0x%08h] | Total Pushed: %0d | In-Flight: %0d", 
                  wr_item.data, total_pushed, expected_queue.size()), UVM_HIGH)
      end

      // Read Domain Listener Thread (rclk domain)
      forever begin
        rd_fifo.get(rd_item);
        total_popped++;

        // In case of delta-cycle race between monitors, wait briefly for expected_queue
        if (expected_queue.size() == 0) begin
          fork
            wait(expected_queue.size() > 0);
            #50ns;
          join_any
        end

        if (expected_queue.size() == 0) begin
          `uvm_error("SCB_UNDERFLOW", $sformatf("Read item 0x%08h captured, but Expected Reference Queue is EMPTY!", rd_item.data))
          mismatch_count++;
        end else begin
          exp_data = expected_queue.pop_front();
          if (rd_item.data === exp_data) begin
            match_count++;
            `uvm_info("SCB_MATCH", $sformatf("MATCH [0x%08h] | Total Matches: %0d", rd_item.data, match_count), UVM_HIGH)
          end else begin
            mismatch_count++;
            `uvm_error("SCB_MISMATCH", $sformatf("DATA MISMATCH! Got: 0x%08h != Expected: 0x%08h", rd_item.data, exp_data))
          end
        end
      end
    join
  endtask

  virtual function void check_phase(uvm_phase phase);
    super.check_phase(phase);

    if (mismatch_count > 0) begin
      `uvm_error("SCB_CHECK", $sformatf("Scoreboard recorded %0d data mismatches!", mismatch_count))
    end

    if (total_pushed != total_popped) begin
      `uvm_error("SCB_CHECK", $sformatf("Transaction count mismatch: total_pushed (%0d) != total_popped (%0d)", 
                 total_pushed, total_popped))
    end

    if (expected_queue.size() > 0) begin
      `uvm_error("SCB_CHECK", $sformatf("Queue leakage: %0d undrained items remain in reference queue at simulation end!", 
                 expected_queue.size()))
    end

    if (total_popped == 0) begin
      `uvm_error("SCB_CHECK", "Zero transactions were verified during simulation!")
    end
  endfunction

  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SCB_REPORT", "==========================================================", UVM_NONE)
    `uvm_info("SCB_REPORT", "             FIFO SCOREBOARD AUDIT REPORT                 ", UVM_NONE)
    `uvm_info("SCB_REPORT", "==========================================================", UVM_NONE)
    `uvm_info("SCB_REPORT", $sformatf("  Total Items Pushed:      %0d", total_pushed), UVM_NONE)
    `uvm_info("SCB_REPORT", $sformatf("  Total Items Popped:      %0d", total_popped), UVM_NONE)
    `uvm_info("SCB_REPORT", $sformatf("  Total Verified Matches:  %0d", match_count), UVM_NONE)
    `uvm_info("SCB_REPORT", $sformatf("  Total Data Mismatches:   %0d", mismatch_count), UVM_NONE)
    `uvm_info("SCB_REPORT", $sformatf("  Undrained Queue Items:   %0d", expected_queue.size()), UVM_NONE)
    `uvm_info("SCB_REPORT", "==========================================================", UVM_NONE)

    if (mismatch_count == 0 && total_pushed == total_popped && total_popped > 0 && expected_queue.size() == 0) begin
      `uvm_info("SCB_REPORT", "### [PASSED] ALL FIFO UVM VERIFICATION CRITERIA MET! ###", UVM_NONE)
    end else begin
      `uvm_fatal("SCB_REPORT", "### [FAILED] FIFO SCOREBOARD INTEGRITY CHECKS FAILED! ###")
    end
  endfunction
endclass: fifo_scoreboard

// ----------------------------------------------------------------------------
// Functional Coverage Subscriber
// ----------------------------------------------------------------------------
class fifo_coverage extends uvm_subscriber #(fifo_seq_item);
  `uvm_component_utils(fifo_coverage)

  fifo_seq_item cov_item;

  covergroup cg_fifo;
    option.per_instance = 1;
    option.name = "fifo_functional_coverage";

    cp_op: coverpoint cov_item.op {
      bins write_op = {fifo_seq_item::WRITE};
      bins read_op  = {fifo_seq_item::READ};
    }

    cp_data: coverpoint cov_item.data {
      bins all_zeros        = {32'h0000_0000};
      bins all_ones         = {32'hFFFF_FFFF};
      bins alt_0101         = {32'h5555_5555};
      bins alt_1010         = {32'hAAAA_AAAA};
      bins corner_patterns  = {32'hDEAD_BEEF, 32'hCAFE_BABE, 32'hA000_0001};
      bins others           = default;
    }

    cross_op_data: cross cp_op, cp_data;
  endgroup

  function new(string name = "fifo_coverage", uvm_component parent = null);
    super.new(name, parent);
    cg_fifo = new();
  endfunction

  virtual function void write(fifo_seq_item t);
    cov_item = t;
    cg_fifo.sample();
  endfunction
endclass: fifo_coverage
