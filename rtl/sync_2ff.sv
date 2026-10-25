// ==============================================================================
// File: sync_2ff.sv
// Description: Multi-bit 2-Flip-Flop Clock Domain Crossing (CDC) Synchronizer.
//              Applies synthesis attributes to prevent logic optimization across
//              metastability resolution stages.
// Standard: SystemVerilog IEEE 1800-2012 / 1800-2017
// ==============================================================================

`timescale 1ns / 1ps

module sync_2ff #(
  parameter int WIDTH = 4
)(
  input  logic             clk,
  input  logic             rst_n,
  input  logic [WIDTH-1:0] din,
  output logic [WIDTH-1:0] dout
);

  // Synthesis keep attributes to protect synchronizer registers from merging
  (* ASYNC_REG = "TRUE" *) logic [WIDTH-1:0] sync_stage1;
  (* ASYNC_REG = "TRUE" *) logic [WIDTH-1:0] sync_stage2;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sync_stage1 <= '0;
      sync_stage2 <= '0;
    end else begin
      sync_stage1 <= din;
      sync_stage2 <= sync_stage1;
    end
  end

  assign dout = sync_stage2;

endmodule
