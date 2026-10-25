// ==============================================================================
// File: fifo_env_and_tests.sv
// Description: UVM Environment, Test Sequences, and Test Cases.
// ==============================================================================

`timescale 1ns / 1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

// ----------------------------------------------------------------------------
// UVM Environment
// ----------------------------------------------------------------------------
class fifo_env extends uvm_env;
  `uvm_component_utils(fifo_env)

  fifo_wr_agent   wr_agent;
  fifo_rd_agent   rd_agent;
  fifo_scoreboard scb;
  fifo_coverage   cov;

  function new(string name = "fifo_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    wr_agent = fifo_wr_agent::type_id::create("wr_agent", this);
    rd_agent = fifo_rd_agent::type_id::create("rd_agent", this);
    scb      = fifo_scoreboard::type_id::create("scb", this);
    cov      = fifo_coverage::type_id::create("cov", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    wr_agent.mon.ap.connect(scb.wr_export);
    rd_agent.mon.ap.connect(scb.rd_export);
    wr_agent.mon.ap.connect(cov.analysis_export);
    rd_agent.mon.ap.connect(cov.analysis_export);
  endfunction
endclass: fifo_env

// ----------------------------------------------------------------------------
// Sequence Library
// ----------------------------------------------------------------------------
class fifo_burst_write_seq extends uvm_sequence #(fifo_seq_item);
  `uvm_object_utils(fifo_burst_write_seq)

  int unsigned num_tx = 30;

  function new(string name = "fifo_burst_write_seq");
    super.new(name);
  endfunction

  virtual task body();
    repeat (num_tx) begin
      req = fifo_seq_item::type_id::create("req");
      start_item(req);
      assert(req.randomize() with { op == fifo_seq_item::WRITE; delay == 0; });
      finish_item(req);
    end
  endtask
endclass: fifo_burst_write_seq

class fifo_burst_read_seq extends uvm_sequence #(fifo_seq_item);
  `uvm_object_utils(fifo_burst_read_seq)

  int unsigned num_tx = 30;

  function new(string name = "fifo_burst_read_seq");
    super.new(name);
  endfunction

  virtual task body();
    repeat (num_tx) begin
      req = fifo_seq_item::type_id::create("req");
      start_item(req);
      assert(req.randomize() with { op == fifo_seq_item::READ; delay == 0; });
      finish_item(req);
    end
  endtask
endclass: fifo_burst_read_seq

// ----------------------------------------------------------------------------
// Base Test & Specialized Tests
// ----------------------------------------------------------------------------
class fifo_base_test extends uvm_test;
  `uvm_component_utils(fifo_base_test)

  fifo_env env;

  function new(string name = "fifo_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = fifo_env::type_id::create("env", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    fifo_burst_write_seq wr_seq;
    fifo_burst_read_seq  rd_seq;

    phase.raise_objection(this);

    wr_seq = fifo_burst_write_seq::type_id::create("wr_seq");
    rd_seq = fifo_burst_read_seq::type_id::create("rd_seq");

    // Write burst followed by read burst
    wr_seq.num_tx = 25;
    rd_seq.num_tx = 25;

    fork
      wr_seq.start(env.wr_agent.sqr);
      #50ns rd_seq.start(env.rd_agent.sqr);
    join

    #200ns;
    phase.drop_objection(this);
  endtask
endclass: fifo_base_test
