// ==============================================================================
// File: fifo_if.sv
// Description: SystemVerilog Dual-Clock FIFO Interface with modports & clocking blocks.
// ==============================================================================

`timescale 1ns / 1ps

interface fifo_if #(
  parameter int DATA_WIDTH = 32,
  parameter int ADDR_WIDTH = 4
)(
  input logic wclk,
  input logic rclk
);

  // Write Domain
  logic                  wrst_n;
  logic                  winc;
  logic [DATA_WIDTH-1:0] wdata;
  logic                  wfull;
  logic                  walmost_full;

  // Read Domain
  logic                  rrst_n;
  logic                  rinc;
  logic [DATA_WIDTH-1:0] rdata;
  logic                  rempty;
  logic                  ralmost_empty;

  // Write Clocking Block
  clocking wr_cb @(posedge wclk);
    default input #1ns output #1ns;
    output winc, wdata;
    input  wfull, walmost_full;
  endclocking

  // Read Clocking Block
  clocking rd_cb @(posedge rclk);
    default input #1ns output #1ns;
    output rinc;
    input  rdata, rempty, ralmost_empty;
  endclocking

  modport WR_DRIVER  (clocking wr_cb, output wrst_n);
  modport RD_DRIVER  (clocking rd_cb, output rrst_n);
  modport WR_MONITOR (input wclk, wrst_n, winc, wdata, wfull, walmost_full);
  modport RD_MONITOR (input rclk, rrst_n, rinc, rdata, rempty, ralmost_empty);

endinterface: fifo_if
