# Copyright 2025 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
# 
# Nico Canzani <ncanzani@student.ethz.ch>

# ------------------------------------------------------------
# Tools and Binaries
# ------------------------------------------------------------
PYTHON         := python3
SIMUL_COMMAND  := oseda -2025.01
VERILATOR      := $(SIMUL_COMMAND) verilator

# ------------------------------------------------------------
# Directories
# ------------------------------------------------------------
TB_DIR         := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
RTL_DIR        := $(TB_DIR)/../rtl
COMMON_CELLS   := $(TB_DIR)/../../../../../rtl/common_cells
OUTPUT_DIR     := obj_dir
STIMULI_DIR    := golden_pulser
TEMPFILE       := $(STIMULI_DIR)/merged_stimuli.txt
STIMULI_PATTERN := $(STIMULI_DIR)/stimuli_0.txt

# ------------------------------------------------------------
# Verilator Configuration
# ------------------------------------------------------------
TOP_MODULE     := tb_pulser_core
VERILATOR_ARGS := --binary -j 0 -Wno-fatal \
                  -Wno-style -Wno-WIDTHEXPAND \
                  --timing --autoflush --trace --trace-structs \
                  --unroll-count 1 --unroll-stmts 1 \
                  -I$(COMMON_CELLS)/include

VERILOG_SOURCES := \
	$(RTL_DIR)/pulser_core.sv \
	$(TB_DIR)/tb_pulser_core.sv \
	$(COMMON_CELLS)/counter.sv \
	$(COMMON_CELLS)/delta_counter.sv

OUTPUT_BIN := $(OUTPUT_DIR)/V$(TOP_MODULE)

# ------------------------------------------------------------
# Targets
# ------------------------------------------------------------

all: $(OUTPUT_BIN) merge_stimuli
	@echo "Simulation build complete. Use 'make run' to simulate with merged stimuli."

compile: $(OUTPUT_BIN)

$(OUTPUT_BIN): $(VERILOG_SOURCES)
	$(VERILATOR) $(VERILATOR_ARGS) --top $(TOP_MODULE) $(VERILOG_SOURCES)

$(STIMULI_PATTERN): gen_pulser_golden.py
	@echo "Generating stimuli..."
	@mkdir -p $(STIMULI_DIR)
	$(PYTHON) gen_pulser_golden.py

# Rule to merge all stimuli into one
$(TEMPFILE): $(STIMULI_PATTERN)
	@echo "Merging stimuli files into $(TEMPFILE)..."
	@rm -f $(TEMPFILE)
	@head -n 1 $(STIMULI_DIR)/stimuli_0.txt > $(TEMPFILE)
	@for file in $$(ls $(STIMULI_DIR)/stimuli_*.txt | sed -E 's/.*stimuli_([0-9]+)\.txt/\1 &/' | sort -n | cut -d' ' -f2); do \
		if [ "$$file" != "$(STIMULI_DIR)/stimuli_0.txt" ]; then \
			tail -n +2 "$$file" >> $(TEMPFILE); \
		fi \
	done


# Merge all stimuli files into one
merge_stimuli: $(STIMULI_PATTERN)
	@echo "Merging stimuli files into $(TEMPFILE)..."
	@rm -f $(TEMPFILE)
	@head -n 1 $(STIMULI_DIR)/stimuli_0.txt > $(TEMPFILE)
	@for file in $$(ls $(STIMULI_DIR)/stimuli_*.txt | sed -E 's/.*stimuli_([0-9]+)\.txt/\1 &/' | sort -n | cut -d' ' -f2); do \
		if [ "$$file" != "$(STIMULI_DIR)/stimuli_0.txt" ]; then \
			tail -n +2 "$$file" >> $(TEMPFILE); \
		fi \
	done

# Run simulation with a specific test configuration
TESTCONFIG ?= 0
test_cfg: $(OUTPUT_BIN)
	@echo "Running testconfig $(TESTCONFIG)..."
	$(SIMUL_COMMAND) ./$(OUTPUT_BIN) +stimuli=$(STIMULI_DIR)/stimuli_$(TESTCONFIG).txt

# Run simulation using merged stimuli
run: $(OUTPUT_BIN) $(TEMPFILE)
	@echo "Running simulation with merged stimuli file..."
	@$(SIMUL_COMMAND) ./$(OUTPUT_BIN) +stimuli=$(TEMPFILE)

# Cleanup
clean:
	rm -rf $(OUTPUT_DIR) logs *.vcd $(STIMULI_DIR)

# Display available commands
help:
	@echo "Available targets:"
	@echo "  all              - Generate stimuli, merge them, compile, and prepare for simulation"
	@echo "  compile          - Compile Verilog sources using Verilator"
	@echo "  run              - Run simulation with merged stimuli"
	@echo "  test_cfg         - Run simulation with specific stimuli file (use TESTCONFIG=<n>)"
	@echo "  clean            - Remove build output and temporary files"
	@echo "  help             - Show this help message"

.PHONY: compile all run test_cfg clean merge_stimuli help
