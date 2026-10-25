# ==============================================================================
# File: Makefile
# Description: Multi-Tool build and simulation Makefile for macOS
# Tools: Icarus Verilog, GTKWave, Yosys
# ==============================================================================

export PATH := /opt/homebrew/bin:$(PATH)

RTL_DIR = ../rtl
TB_SIM_DIR = ../tb/sim
SYN_DIR = ../syn

RTL_SRCS = \
	$(RTL_DIR)/sync_2ff.sv \
	$(RTL_DIR)/gray_counter.sv \
	$(RTL_DIR)/async_fifo.sv \
	$(RTL_DIR)/fifo_sva.sv

TB_SRCS = $(TB_SIM_DIR)/tb_async_fifo_selfcheck.sv

SIM_BIN = sim_async_fifo.vvp
VCD_FILE = async_fifo_trace.vcd

.PHONY: all sim wave synth clean

all: sim

sim:
	@echo "==> Compiling RTL and SVA with Icarus Verilog..."
	iverilog -g2012 -o $(SIM_BIN) $(RTL_SRCS) $(TB_SRCS)
	@echo "==> Running Simulation with skewed clock domains..."
	vvp $(SIM_BIN)

wave:
	@if [ -f "$(VCD_FILE)" ]; then \
		echo "==> Opening $(VCD_FILE) in GTKWave..."; \
		gtkwave $(VCD_FILE) & \
	else \
		echo "ERROR: Run 'make sim' first."; \
	fi

synth:
	@echo "==> Synthesizing Async FIFO with Yosys..."
	cd $(SYN_DIR) && yosys -s synth.ys > yosys_synth.log 2>&1
	@echo "==> Synthesis Complete. Log saved to syn/yosys_synth.log"
	@grep -A 30 "=== async_fifo ===" $(SYN_DIR)/yosys_synth.log || tail -n 35 $(SYN_DIR)/yosys_synth.log

clean:
	rm -f $(SIM_BIN) $(VCD_FILE)
	rm -f $(SYN_DIR)/async_fifo_synth.v $(SYN_DIR)/yosys_synth.log
