// ==============================================================================
// File: async_fifo.sv
// Description: Dual-Clock Asynchronous FIFO with Gray-Code CDC Synchronization,
//              Pipelined Memory Array, and Lookahead Full/Empty Flag Generation.
// Standard: SystemVerilog IEEE 1800-2012 / 1800-2017
// ==============================================================================

`timescale 1ns / 1ps

module async_fifo #(
  parameter int DATA_WIDTH = 32,
  parameter int ADDR_WIDTH = 4,   // Depth = 2^ADDR_WIDTH (16 entries)
  parameter int ALMOST_FULL_THRESH  = 14,
  parameter int ALMOST_EMPTY_THRESH = 2
)(
  // Write Clock Domain
  input  logic                  wclk,
  input  logic                  wrst_n,
  input  logic                  winc,
  input  logic [DATA_WIDTH-1:0] wdata,
  output logic                  wfull,
  output logic                  walmost_full,

  // Read Clock Domain
  input  logic                  rclk,
  input  logic                  rrst_n,
  input  logic                  rinc,
  output logic [DATA_WIDTH-1:0] rdata,
  output logic                  rempty,
  output logic                  ralmost_empty
);

  localparam int DEPTH = 1 << ADDR_WIDTH;

  // Dual-Port RAM Array
  logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

  // Binary & Gray Pointers (WIDTH = ADDR_WIDTH + 1 to detect wrap-around)
  logic [ADDR_WIDTH:0] wbin, wgray;
  logic [ADDR_WIDTH:0] rbin, rgray;

  // Synchronized Gray Pointers across CDC boundaries
  logic [ADDR_WIDTH:0] rptr_synced_to_wclk;
  logic [ADDR_WIDTH:0] wptr_synced_to_rclk;

  // Next Pointer Values
  logic [ADDR_WIDTH:0] wbin_next, wgray_next;
  logic [ADDR_WIDTH:0] rbin_next, rgray_next;

  // --------------------------------------------------------------------------
  // Write Clock Domain Logic
  // --------------------------------------------------------------------------
  assign wbin_next  = wbin + {{(ADDR_WIDTH){1'b0}}, (winc & ~wfull)};
  assign wgray_next = (wbin_next >> 1) ^ wbin_next;

  always_ff @(posedge wclk or negedge wrst_n) begin
    if (!wrst_n) begin
      wbin  <= '0;
      wgray <= '0;
    end else begin
      wbin  <= wbin_next;
      wgray <= wgray_next;
    end
  end

  // Memory Write
  always_ff @(posedge wclk) begin
    if (winc && !wfull) begin
      mem[wbin[ADDR_WIDTH-1:0]] <= wdata;
    end
  end

  // Synchronize Read Pointer into Write Clock Domain (2-FF Synchronizer)
  sync_2ff #(.WIDTH(ADDR_WIDTH + 1)) u_sync_r2w (
    .clk  (wclk),
    .rst_n(wrst_n),
    .din  (rgray),
    .dout (rptr_synced_to_wclk)
  );

  // Full Flag Generation:
  // Write full occurs when MSB differs, 2nd MSB differs, and lower LSBs match
  logic wfull_val;
  assign wfull_val = (wgray_next == {~rptr_synced_to_wclk[ADDR_WIDTH:ADDR_WIDTH-1],
                                      rptr_synced_to_wclk[ADDR_WIDTH-2:0]});

  // Convert synchronized read Gray pointer to binary to calculate fill level
  logic [ADDR_WIDTH:0] rbin_in_wclk;
  gray_to_bin #(.WIDTH(ADDR_WIDTH + 1)) u_g2b_r (
    .gray(rptr_synced_to_wclk),
    .bin (rbin_in_wclk)
  );

  logic [ADDR_WIDTH:0] wlevel;
  assign wlevel = wbin - rbin_in_wclk;

  always_ff @(posedge wclk or negedge wrst_n) begin
    if (!wrst_n) begin
      wfull        <= 1'b0;
      walmost_full <= 1'b0;
    end else begin
      wfull        <= wfull_val;
      walmost_full <= (wlevel >= (ADDR_WIDTH+1)'(ALMOST_FULL_THRESH));
    end
  end

  // --------------------------------------------------------------------------
  // Read Clock Domain Logic
  // --------------------------------------------------------------------------
  assign rbin_next  = rbin + {{(ADDR_WIDTH){1'b0}}, (rinc & ~rempty)};
  assign rgray_next = (rbin_next >> 1) ^ rbin_next;

  always_ff @(posedge rclk or negedge rrst_n) begin
    if (!rrst_n) begin
      rbin  <= '0;
      rgray <= '0;
    end else begin
      rbin  <= rbin_next;
      rgray <= rgray_next;
    end
  end

  // Memory Read (Registered output for clean timing)
  always_ff @(posedge rclk) begin
    if (rinc && !rempty) begin
      rdata <= mem[rbin[ADDR_WIDTH-1:0]];
    end
  end

  // Synchronize Write Pointer into Read Clock Domain (2-FF Synchronizer)
  sync_2ff #(.WIDTH(ADDR_WIDTH + 1)) u_sync_w2r (
    .clk  (rclk),
    .rst_n(rrst_n),
    .din  (wgray),
    .dout (wptr_synced_to_rclk)
  );

  // Empty Flag Generation:
  // Read empty occurs when read Gray pointer equals synchronized write Gray pointer
  logic rempty_val;
  assign rempty_val = (rgray_next == wptr_synced_to_rclk);

  // Convert synchronized write Gray pointer to binary to calculate fill level
  logic [ADDR_WIDTH:0] wbin_in_rclk;
  gray_to_bin #(.WIDTH(ADDR_WIDTH + 1)) u_g2b_w (
    .gray(wptr_synced_to_rclk),
    .bin (wbin_in_rclk)
  );

  logic [ADDR_WIDTH:0] rlevel;
  assign rlevel = wbin_in_rclk - rbin;

  always_ff @(posedge rclk or negedge rrst_n) begin
    if (!rrst_n) begin
      rempty        <= 1'b1;
      ralmost_empty <= 1'b1;
    end else begin
      rempty        <= rempty_val;
      ralmost_empty <= (rlevel <= (ADDR_WIDTH+1)'(ALMOST_EMPTY_THRESH));
    end
  end

endmodule
