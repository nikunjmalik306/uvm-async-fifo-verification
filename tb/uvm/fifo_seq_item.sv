// ==============================================================================
// File: fifo_seq_item.sv
// Description: UVM Sequence Item for FIFO operations with randomized delays and data.
// ==============================================================================

`timescale 1ns / 1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

class fifo_seq_item extends uvm_sequence_item;

  typedef enum { WRITE, READ, SIMULTANEOUS } op_type_e;

  rand op_type_e           op;
  rand logic [31:0]        data;
  rand int unsigned        delay;

  // Constraints
  constraint c_delay {
    delay dist { 0 := 60, [1:3] := 30, [4:10] := 10 };
  }

  constraint c_data_patterns {
    data dist {
      32'h0000_0000 := 5,
      32'hFFFF_FFFF := 5,
      32'h5555_5555 := 5,
      32'hAAAA_AAAA := 5,
      [32'h0000_0001 : 32'hFFFF_FFFE] := 80
    };
  }

  `uvm_object_utils_begin(fifo_seq_item)
    `uvm_field_enum(op_type_e, op, UVM_ALL_ON)
    `uvm_field_int(data, UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(delay, UVM_ALL_ON | UVM_DEC)
  `uvm_object_utils_end

  function new(string name = "fifo_seq_item");
    super.new(name);
  endfunction

endclass: fifo_seq_item

class fifo_sequencer extends uvm_sequencer #(fifo_seq_item);
  `uvm_component_utils(fifo_sequencer)

  function new(string name = "fifo_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass: fifo_sequencer
