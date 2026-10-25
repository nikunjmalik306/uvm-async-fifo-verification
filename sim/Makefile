# ==============================================================================
# File: Makefile
# Description: Multi-Tool build, simulation, and verification Makefile
# Supported Tools:
#   - Icarus Verilog + VVP (Open-source, local macOS verification)
#   - Synopsys VCS (Commercial UVM 1.2 simulation)
#   - Siemens QuestaSim / ModelSim (Commercial UVM 1.2 simulation)
#   - Cadence Xcelium (Commercial UVM 1.2 simulation)
#   - Yosys (Synthesis & Gate-level netlist generation)
#   - GTKWave (Waveform visualization)
# ==============================================================================

SHELL := /bin/bash
export PATH := /opt/homebrew/bin:$(PATH)

IVERILOG ?= $(shell which iverilog 2>/dev/null || echo /opt/homebrew/bin/iverilog)
VVP      ?= $(shell which vvp 2>/dev/null || echo /opt/homebrew/bin/vvp)
YOSYS    ?= $(shell which yosys 2>/dev/null || echo /opt/homebrew/bin/yosys)
GTKWAVE  ?= $(shell which gtkwave 2>/dev/null || echo /opt/homebrew/bin/gtkwave)

RTL_DIR    = ../rtl
TB_SIM_DIR = ../tb/sim
TB_UVM_DIR = ../tb/uvm
SYN_DIR    = ../syn

RTL_SRCS = \
	$(RTL_DIR)/sync_2ff.sv \
	$(RTL_DIR)/gray_counter.sv \
	$(RTL_DIR)/async_fifo.sv \
	$(RTL_DIR)/fifo_sva.sv

TB_SRCS = $(TB_SIM_DIR)/tb_async_fifo_selfcheck.sv

UVM_SRCS = \
	$(RTL_SRCS) \
	$(TB_UVM_DIR)/tb_top_uvm.sv

SIM_BIN  = sim_async_fifo.vvp
VCD_FILE = async_fifo_trace.vcd
TESTNAME ?= fifo_concurrent_stress_test

.PHONY: all sim wave synth uvm_vcs uvm_questa uvm_xcelium clean help

all: sim

help:
	@echo "Available Targets:"
	@echo "  make sim          : Run standalone dual-clock CDC selfchecking testbench (Icarus Verilog)"
	@echo "  make synth        : Synthesize RTL with Yosys and generate gate statistics"
	@echo "  make wave         : View VCD simulation waveforms in GTKWave"
	@echo "  make uvm_questa   : Run UVM environment on Siemens QuestaSim (TESTNAME=$(TESTNAME))"
	@echo "  make uvm_vcs      : Run UVM environment on Synopsys VCS (TESTNAME=$(TESTNAME))"
	@echo "  make uvm_xcelium  : Run UVM environment on Cadence Xcelium (TESTNAME=$(TESTNAME))"
	@echo "  make clean        : Remove simulation artifacts and logs"

sim:
	@echo "==> Compiling RTL and SVA with Icarus Verilog..."
	$(IVERILOG) -g2012 -o $(SIM_BIN) $(RTL_SRCS) $(TB_SRCS)
	@echo "==> Running Dual-Clock Skew CDC Simulation..."
	$(VVP) $(SIM_BIN)

wave:
	@if [ -f "$(VCD_FILE)" ]; then \
		echo "==> Opening $(VCD_FILE) in GTKWave..."; \
		$(GTKWAVE) $(VCD_FILE) & \
	else \
		echo "ERROR: Run 'make sim' first to generate $(VCD_FILE)."; \
	fi

synth:
	@echo "==> Synthesizing Async FIFO with Yosys..."
	cd $(SYN_DIR) && $(YOSYS) -s synth.ys > yosys_synth.log 2>&1
	@echo "==> Synthesis Complete. Log saved to syn/yosys_synth.log"
	@grep -A 28 "=== design hierarchy ===" $(SYN_DIR)/yosys_synth.log || tail -n 35 $(SYN_DIR)/yosys_synth.log

# ------------------------------------------------------------------------------
# Commercial UVM Simulators
# ------------------------------------------------------------------------------
uvm_vcs:
	@echo "==> Running UVM 1.2 regression on Synopsys VCS..."
	vcs -sverilog -ntb_opts uvm-1.2 -timescale=1ns/1ps \
		+incdir+$(RTL_DIR)+$(TB_UVM_DIR) \
		$(UVM_SRCS) -l vcs_uvm.log -R +UVM_TESTNAME=$(TESTNAME) +UVM_VERBOSITY=UVM_MEDIUM

uvm_questa:
	@echo "==> Running UVM 1.2 regression on Siemens QuestaSim..."
	vlib work
	vlog -sv +incdir+$(RTL_DIR)+$(TB_UVM_DIR) $(UVM_SRCS)
	vsim -c -do "run -all; exit" tb_top_uvm +UVM_TESTNAME=$(TESTNAME) +UVM_VERBOSITY=UVM_MEDIUM -l questa_uvm.log

uvm_xcelium:
	@echo "==> Running UVM 1.2 regression on Cadence Xcelium..."
	xrun -uvm -sv +incdir+$(RTL_DIR)+$(TB_UVM_DIR) $(UVM_SRCS) \
		+UVM_TESTNAME=$(TESTNAME) +UVM_VERBOSITY=UVM_MEDIUM -l xcelium_uvm.log

clean:
	rm -f $(SIM_BIN) $(VCD_FILE) uvm_async_fifo.vcd vcs_uvm.log questa_uvm.log xcelium_uvm.log
	rm -rf work transcript vsim.wlf INCA_libs simv* csrc *.key
