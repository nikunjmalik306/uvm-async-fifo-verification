// ==============================================================================
// File: fifo_agent.sv
// Description: UVM Drivers, Monitors, and Agents for dual-clock asynchronous FIFO.
// ==============================================================================

`timescale 1ns / 1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

// ----------------------------------------------------------------------------
// Write Driver (Operates in wclk domain)
// ----------------------------------------------------------------------------
class fifo_wr_driver extends uvm_driver #(fifo_seq_item);
  `uvm_component_utils(fifo_wr_driver)

  virtual fifo_if vif;

  function new(string name = "fifo_wr_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual fifo_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NO_VIF", "Virtual interface not found in fifo_wr_driver")
    end
  endfunction

  virtual task run_phase(uvm_phase phase);
    vif.wr_cb.winc  <= 1'b0;
    vif.wr_cb.wdata <= '0;

    @(posedge vif.wrst_n);
    @(vif.wr_cb);

    forever begin
      seq_item_port.get_next_item(req);

      repeat (req.delay) @(vif.wr_cb);

      // Wait if FIFO is full
      while (vif.wr_cb.wfull) @(vif.wr_cb);

      vif.wr_cb.winc  <= 1'b1;
      vif.wr_cb.wdata <= req.data;
      @(vif.wr_cb);
      vif.wr_cb.winc  <= 1'b0;

      seq_item_port.item_done();
    end
  endtask
endclass: fifo_wr_driver

// ----------------------------------------------------------------------------
// Read Driver (Operates in rclk domain)
// ----------------------------------------------------------------------------
class fifo_rd_driver extends uvm_driver #(fifo_seq_item);
  `uvm_component_utils(fifo_rd_driver)

  virtual fifo_if vif;

  function new(string name = "fifo_rd_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual fifo_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NO_VIF", "Virtual interface not found in fifo_rd_driver")
    end
  endfunction

  virtual task run_phase(uvm_phase phase);
    vif.rd_cb.rinc <= 1'b0;

    @(posedge vif.rrst_n);
    @(vif.rd_cb);

    forever begin
      seq_item_port.get_next_item(req);

      repeat (req.delay) @(vif.rd_cb);

      // Wait if FIFO is empty
      while (vif.rd_cb.rempty) @(vif.rd_cb);

      vif.rd_cb.rinc <= 1'b1;
      @(vif.rd_cb);
      vif.rd_cb.rinc <= 1'b0;

      seq_item_port.item_done();
    end
  endtask
endclass: fifo_rd_driver

// ----------------------------------------------------------------------------
// Write Monitor (Passively captures pushed data on wclk)
// ----------------------------------------------------------------------------
class fifo_wr_monitor extends uvm_monitor;
  `uvm_component_utils(fifo_wr_monitor)

  virtual fifo_if vif;
  uvm_analysis_port #(fifo_seq_item) ap;

  function new(string name = "fifo_wr_monitor", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual fifo_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NO_VIF", "Virtual interface not found in fifo_wr_monitor")
    end
  endfunction

  virtual task run_phase(uvm_phase phase);
    fifo_seq_item item;
    @(posedge vif.wrst_n);

    forever begin
      @(posedge vif.wclk);
      if (vif.winc && !vif.wfull) begin
        item = fifo_seq_item::type_id::create("item");
        item.op   = fifo_seq_item::WRITE;
        item.data = vif.wdata;
        ap.write(item);
      end
    end
  endtask
endclass: fifo_wr_monitor

// ----------------------------------------------------------------------------
// Read Monitor (Pipelined non-blocking sampling: handles back-to-back reads)
// ----------------------------------------------------------------------------
class fifo_rd_monitor extends uvm_monitor;
  `uvm_component_utils(fifo_rd_monitor)

  virtual fifo_if vif;
  uvm_analysis_port #(fifo_seq_item) ap;

  function new(string name = "fifo_rd_monitor", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual fifo_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NO_VIF", "Virtual interface not found in fifo_rd_monitor")
    end
  endfunction

  virtual task run_phase(uvm_phase phase);
    fifo_seq_item item;
    bit pending_rd = 0;
    @(posedge vif.rrst_n);

    forever begin
      @(posedge vif.rclk);
      // Sample data on cycle following active rinc & !rempty
      if (pending_rd) begin
        item = fifo_seq_item::type_id::create("item");
        item.op   = fifo_seq_item::READ;
        item.data = vif.rdata;
        ap.write(item);
      end
      // Track read request for subsequent clock edge
      pending_rd = (vif.rinc && !vif.rempty);
    end
  endtask
endclass: fifo_rd_monitor

// ----------------------------------------------------------------------------
// Write & Read UVM Agents
// ----------------------------------------------------------------------------
class fifo_wr_agent extends uvm_agent;
  `uvm_component_utils(fifo_wr_agent)

  fifo_sequencer   sqr;
  fifo_wr_driver   drv;
  fifo_wr_monitor  mon;

  function new(string name = "fifo_wr_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon = fifo_wr_monitor::type_id::create("mon", this);
    if (get_is_active() == UVM_ACTIVE) begin
      sqr = fifo_sequencer::type_id::create("sqr", this);
      drv = fifo_wr_driver::type_id::create("drv", this);
    end
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (get_is_active() == UVM_ACTIVE) begin
      drv.seq_item_port.connect(sqr.seq_item_export);
    end
  endfunction
endclass: fifo_wr_agent

class fifo_rd_agent extends uvm_agent;
  `uvm_component_utils(fifo_rd_agent)

  fifo_sequencer   sqr;
  fifo_rd_driver   drv;
  fifo_rd_monitor  mon;

  function new(string name = "fifo_rd_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon = fifo_rd_monitor::type_id::create("mon", this);
    if (get_is_active() == UVM_ACTIVE) begin
      sqr = fifo_sequencer::type_id::create("sqr", this);
      drv = fifo_rd_driver::type_id::create("drv", this);
    end
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (get_is_active() == UVM_ACTIVE) begin
      drv.seq_item_port.connect(sqr.seq_item_export);
    end
  endfunction
endclass: fifo_rd_agent
