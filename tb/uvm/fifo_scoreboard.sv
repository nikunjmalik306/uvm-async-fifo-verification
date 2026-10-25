// ==============================================================================
// File: fifo_scoreboard_coverage.sv
// Description: UVM Scoreboard with reference model queue & Functional Coverage.
// ==============================================================================

`timescale 1ns / 1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

`uvm_analysis_imp_decl(_wr)
`uvm_analysis_imp_decl(_rd)

class fifo_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(fifo_scoreboard)

  uvm_analysis_imp_wr #(fifo_seq_item, fifo_scoreboard) wr_export;
  uvm_analysis_imp_rd #(fifo_seq_item, fifo_scoreboard) rd_export;

  // Golden Reference Queue
  logic [31:0] expected_queue [$];

  int unsigned match_count    = 0;
  int unsigned mismatch_count = 0;
  int unsigned total_pushed   = 0;
  int unsigned total_popped   = 0;

  function new(string name = "fifo_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    wr_export = new("wr_export", this);
    rd_export = new("rd_export", this);
  endfunction

  virtual function void write_wr(fifo_seq_item item);
    expected_queue.push_back(item.data);
    total_pushed++;
    `uvm_info("SCB_PUSH", $sformatf("Pushed 0x%08h | Queue Depth: %0d", item.data, expected_queue.size()), UVM_HIGH)
  endfunction

  virtual function void write_rd(fifo_seq_item item);
    logic [31:0] exp_data;
    total_popped++;

    if (expected_queue.size() == 0) begin
      `uvm_error("SCB_UNDERFLOW", "DUT emitted read data but Expected Reference Queue is EMPTY!")
      mismatch_count++;
      return;
    end

    exp_data = expected_queue.pop_front();
    if (item.data === exp_data) begin
      match_count++;
      `uvm_info("SCB_MATCH", $sformatf("MATCH [0x%08h] | Matches: %0d", item.data, match_count), UVM_HIGH)
    end else begin
      mismatch_count++;
      `uvm_error("SCB_MISMATCH", $sformatf("DATA MISMATCH! Actual: 0x%08h != Expected: 0x%08h", item.data, exp_data))
    end
  endfunction

  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SCB_REPORT", "==========================================================", UVM_NONE)
    `uvm_info("SCB_REPORT", "             FIFO SCOREBOARD SUMMARY REPORT                ", UVM_NONE)
    `uvm_info("SCB_REPORT", "==========================================================", UVM_NONE)
    `uvm_info("SCB_REPORT", $sformatf("  Total Pushed:      %0d", total_pushed), UVM_NONE)
    `uvm_info("SCB_REPORT", $sformatf("  Total Popped:      %0d", total_popped), UVM_NONE)
    `uvm_info("SCB_REPORT", $sformatf("  Total Matches:     %0d", match_count), UVM_NONE)
    `uvm_info("SCB_REPORT", $sformatf("  Total Mismatches:  %0d", mismatch_count), UVM_NONE)
    `uvm_info("SCB_REPORT", $sformatf("  Items in Queue:    %0d", expected_queue.size()), UVM_NONE)
    `uvm_info("SCB_REPORT", "==========================================================", UVM_NONE)

    if (mismatch_count == 0 && total_popped > 0) begin
      `uvm_info("SCB_REPORT", "### STATUS: VERIFICATION TEST PASSED! ###", UVM_NONE)
    end else begin
      `uvm_error("SCB_REPORT", "### STATUS: VERIFICATION TEST FAILED! ###")
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
      bins all_zeros   = {32'h0000_0000};
      bins all_ones    = {32'hFFFF_FFFF};
      bins alt_0101    = {32'h5555_5555};
      bins alt_1010    = {32'hAAAA_AAAA};
      bins walking_ones[32] = { [32'h1 : 32'h8000_0000] };
      bins other       = default;
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
