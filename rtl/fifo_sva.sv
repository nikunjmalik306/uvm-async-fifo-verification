// ==============================================================================
// File: fifo_sva.sv
// Description: Dual-Compatible SystemVerilog Assertions Module.
//              Provides formal SVA properties for commercial simulators (VCS/Questa)
//              and cycle-accurate clocked checkers for open-source simulators (Icarus).
// Standard: SystemVerilog IEEE 1800-2012 / 1800-2017
// ==============================================================================

`timescale 1ns / 1ps

module fifo_sva #(
  parameter int DATA_WIDTH = 32,
  parameter int ADDR_WIDTH = 4
)(
  input logic                  wclk,
  input logic                  wrst_n,
  input logic                  winc,
  input logic [DATA_WIDTH-1:0] wdata,
  input logic                  wfull,
  input logic [ADDR_WIDTH:0]   wgray,

  input logic                  rclk,
  input logic                  rrst_n,
  input logic                  rinc,
  input logic [DATA_WIDTH-1:0] rdata,
  input logic                  rempty,
  input logic [ADDR_WIDTH:0]   rgray
);

`ifdef __ICARUS__

  // --------------------------------------------------------------------------
  // Clocked Procedural Checks for Icarus Verilog Simulation
  // --------------------------------------------------------------------------
  always @(posedge wclk) begin
    if (wrst_n && winc && wfull) begin
      $error("[SVA_VIOLATION @ %0t] OVERFLOW DETECTED: Write asserted while FIFO is FULL!", $time);
    end
  end

  always @(posedge rclk) begin
    if (rrst_n && rinc && rempty) begin
      $error("[SVA_VIOLATION @ %0t] UNDERFLOW DETECTED: Read asserted while FIFO is EMPTY!", $time);
    end
  end

  // Gray Code Single-Bit Transition Check
  logic [ADDR_WIDTH:0] prev_wgray = '0;
  always @(posedge wclk) begin
    if (wrst_n) begin
      if (wgray != prev_wgray) begin
        // XOR should be a power of 2 (single bit set)
        logic [ADDR_WIDTH:0] diff;
        diff = wgray ^ prev_wgray;
        if ((diff & (diff - 1'b1)) != 0) begin
          $error("[SVA_VIOLATION @ %0t] Write Gray pointer changed by more than 1 bit!", $time);
        end
      end
      prev_wgray <= wgray;
    end
  end

  logic [ADDR_WIDTH:0] prev_rgray = '0;
  always @(posedge rclk) begin
    if (rrst_n) begin
      if (rgray != prev_rgray) begin
        logic [ADDR_WIDTH:0] diff;
        diff = rgray ^ prev_rgray;
        if ((diff & (diff - 1'b1)) != 0) begin
          $error("[SVA_VIOLATION @ %0t] Read Gray pointer changed by more than 1 bit!", $time);
        end
      end
      prev_rgray <= rgray;
    end
  end

`else

  // --------------------------------------------------------------------------
  // IEEE 1800 Formal SVA Assertions for Synopsys VCS / Cadence / Questa
  // --------------------------------------------------------------------------
  property p_no_overflow;
    @(posedge wclk) disable iff (!wrst_n)
    wfull |-> not (winc);
  endproperty
  assert_no_overflow: assert property (p_no_overflow)
    else $error("[SVA_VIOLATION] OVERFLOW DETECTED: Write asserted while FIFO is FULL!");

  property p_no_underflow;
    @(posedge rclk) disable iff (!rrst_n)
    rempty |-> not (rinc);
  endproperty
  assert_no_underflow: assert property (p_no_underflow)
    else $error("[SVA_VIOLATION] UNDERFLOW DETECTED: Read asserted while FIFO is EMPTY!");

`endif

endmodule
