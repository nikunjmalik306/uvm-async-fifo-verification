// ==============================================================================
// File: gray_counter.sv
// Description: Parameterized Binary-to-Gray and Gray-to-Binary converters.
// Standard: SystemVerilog IEEE 1800-2012 / 1800-2017
// ==============================================================================

`timescale 1ns / 1ps

module bin_to_gray #(
  parameter int WIDTH = 4
)(
  input  logic [WIDTH-1:0] bin,
  output logic [WIDTH-1:0] gray
);

  assign gray = (bin >> 1) ^ bin;

endmodule

module gray_to_bin #(
  parameter int WIDTH = 4
)(
  input  logic [WIDTH-1:0] gray,
  output logic [WIDTH-1:0] bin
);

  always_comb begin
    bin[WIDTH-1] = gray[WIDTH-1];
    for (int i = WIDTH-2; i >= 0; i--) begin
      bin[i] = bin[i+1] ^ gray[i];
    end
  end

endmodule
