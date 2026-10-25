// ==============================================================================
// File: fifo_env.sv
// Description: UVM Environment, Sequences, and Test Suites for Async FIFO.
// Features:
//   - Connection of TLM analysis FIFOs to scoreboard
//   - Burst sequences with randomized delays
//   - Concurrent stress sequence interleaving reads and writes across clock domains
//   - Specialized tests: base_test, concurrent_stress_test, burst_test
// Standard: SystemVerilog IEEE 1800-2012 / UVM 1.2
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
    // Connect agent monitors to scoreboard TLM analysis FIFOs
    wr_agent.mon.ap.connect(scb.wr_fifo.analysis_export);
    rd_agent.mon.ap.connect(scb.rd_fifo.analysis_export);

    // Connect to coverage subscriber
    wr_agent.mon.ap.connect(cov.analysis_export);
    rd_agent.mon.ap.connect(cov.analysis_export);
  endfunction
endclass: fifo_env

// ----------------------------------------------------------------------------
// Sequences
// ----------------------------------------------------------------------------

// 1. Burst Write Sequence with Optional Random Delay
class fifo_burst_write_seq extends uvm_sequence #(fifo_seq_item);
  `uvm_object_utils(fifo_burst_write_seq)

  int unsigned num_tx = 32;
  bit          zero_delay = 1;

  function new(string name = "fifo_burst_write_seq");
    super.new(name);
  endfunction

  virtual task body();
    repeat (num_tx) begin
      req = fifo_seq_item::type_id::create("req");
      start_item(req);
      if (zero_delay) begin
        assert(req.randomize() with { op == fifo_seq_item::WRITE; delay == 0; });
      end else begin
        assert(req.randomize() with { op == fifo_seq_item::WRITE; delay inside {[0:4]}; });
      end
      finish_item(req);
    end
  endtask
endclass: fifo_burst_write_seq

// 2. Burst Read Sequence with Optional Random Delay
class fifo_burst_read_seq extends uvm_sequence #(fifo_seq_item);
  `uvm_object_utils(fifo_burst_read_seq)

  int unsigned num_tx = 32;
  bit          zero_delay = 1;

  function new(string name = "fifo_burst_read_seq");
    super.new(name);
  endfunction

  virtual task body();
    repeat (num_tx) begin
      req = fifo_seq_item::type_id::create("req");
      start_item(req);
      if (zero_delay) begin
        assert(req.randomize() with { op == fifo_seq_item::READ; delay == 0; });
      end else begin
        assert(req.randomize() with { op == fifo_seq_item::READ; delay inside {[0:4]}; });
      end
      finish_item(req);
    end
  endtask
endclass: fifo_burst_read_seq

// 3. Randomized Stress Write Sequence
class fifo_stress_write_seq extends uvm_sequence #(fifo_seq_item);
  `uvm_object_utils(fifo_stress_write_seq)

  int unsigned num_tx = 150;

  function new(string name = "fifo_stress_write_seq");
    super.new(name);
  endfunction

  virtual task body();
    repeat (num_tx) begin
      req = fifo_seq_item::type_id::create("req");
      start_item(req);
      assert(req.randomize() with { 
        op == fifo_seq_item::WRITE; 
        delay dist { 0 := 50, [1:3] := 35, [4:8] := 15 };
      });
      finish_item(req);
    end
  endtask
endclass: fifo_stress_write_seq

// 4. Randomized Stress Read Sequence
class fifo_stress_read_seq extends uvm_sequence #(fifo_seq_item);
  `uvm_object_utils(fifo_stress_read_seq)

  int unsigned num_tx = 150;

  function new(string name = "fifo_stress_read_seq");
    super.new(name);
  endfunction

  virtual task body();
    repeat (num_tx) begin
      req = fifo_seq_item::type_id::create("req");
      start_item(req);
      assert(req.randomize() with { 
        op == fifo_seq_item::READ; 
        delay dist { 0 := 50, [1:3] := 35, [4:8] := 15 };
      });
      finish_item(req);
    end
  endtask
endclass: fifo_stress_read_seq

// ----------------------------------------------------------------------------
// Tests
// ----------------------------------------------------------------------------

// Test 1: Base Test (Burst Fill followed by Burst Drain)
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

    wr_seq.num_tx = 32;
    rd_seq.num_tx = 32;

    fork
      wr_seq.start(env.wr_agent.sqr);
      begin
        #60ns;
        rd_seq.start(env.rd_agent.sqr);
      end
    join

    #200ns;
    phase.drop_objection(this);
  endtask
endclass: fifo_base_test

// Test 2: Concurrent Randomized Stress Test (Realistic CDC Multi-Clock Stalling)
class fifo_concurrent_stress_test extends uvm_test;
  `uvm_component_utils(fifo_concurrent_stress_test)

  fifo_env env;

  function new(string name = "fifo_concurrent_stress_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = fifo_env::type_id::create("env", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    fifo_stress_write_seq wr_seq;
    fifo_stress_read_seq  rd_seq;
    fifo_burst_read_seq   drain_seq;

    phase.raise_objection(this);

    wr_seq = fifo_stress_write_seq::type_id::create("wr_seq");
    rd_seq = fifo_stress_read_seq::type_id::create("rd_seq");

    wr_seq.num_tx = 200;
    rd_seq.num_tx = 200;

    fork
      wr_seq.start(env.wr_agent.sqr);
      begin
        #40ns;
        rd_seq.start(env.rd_agent.sqr);
      end
    join

    // Ensure all items are fully drained at completion
    #100ns;
    if (env.scb.expected_queue.size() > 0) begin
      drain_seq = fifo_burst_read_seq::type_id::create("drain_seq");
      drain_seq.num_tx = env.scb.expected_queue.size();
      drain_seq.zero_delay = 1;
      drain_seq.start(env.rd_agent.sqr);
    end

    #300ns;
    phase.drop_objection(this);
  endtask
endclass: fifo_concurrent_stress_test
