# Directories
TB_DIR := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
RTL_DIR := $(TB_DIR)/../rtl
OUTPUT_DIR := obj_dir
TOP_MODULE := tb_pulser_core
TESTCONFIG ?= 0  # Default test config

# Verilator
VERILATOR := oseda -2025.01 verilator
VERILATOR_ARGS := --binary -j 0 -Wno-fatal
VERILATOR_ARGS += -Wno-style -Wno-WIDTHEXPAND
VERILATOR_ARGS += --timing --autoflush --trace --trace-structs
VERILATOR_ARGS += --unroll-count 1 --unroll-stmts 1
VERILATOR_ARGS += -I$(TB_DIR)/../../../../../rtl/common_cells/include

# Source files
VERILOG_SOURCES := \
	$(RTL_DIR)/pulser_core.sv \
	$(TB_DIR)/tb_pulser_core.sv \
	$(TB_DIR)/../../../../../rtl/common_cells/counter.sv \
	$(TB_DIR)/../../../../../rtl/common_cells/delta_counter.sv

# Target binary
OUTPUT_BIN := $(OUTPUT_DIR)/V$(TOP_MODULE)

# Default target: Compile only
compile: $(OUTPUT_BIN)

$(OUTPUT_BIN): $(VERILOG_SOURCES)
	$(VERILATOR) $(VERILATOR_ARGS) --top $(TOP_MODULE) $(VERILOG_SOURCES)

# Generate simulation data using Python script
generate_simdata:
	python3 gen_pulser_golden.py

# Compile and run all test configs
all: generate_simdata compile run_all

# Run a specific test config (use `make run TESTCONFIG=X`)
run: $(OUTPUT_BIN)
	@if [ -z "$(TESTCONFIG)" ]; then \
		echo "Error: TESTCONFIG variable not set! Use 'make run TESTCONFIG=X'"; \
		exit 1; \
	fi
	@echo "Running testconfig $(TESTCONFIG)..."
	oseda -2025.01 ./obj_dir/Vtb_pulser_core +testconfig=$(TESTCONFIG)

# Run all test configs sequentially
run_all: $(OUTPUT_BIN)
	@for i in $(shell seq 0 11); do \
		if [ ! -f "golden_pulser/config_$${i}.txt" ]; then \
			echo "Skipping testconfig $${i} (file missing)..."; \
			continue; \
		fi; \
		echo "Running testconfig $${i}..."; \
		oseda -2025.01 ./obj_dir/Vtb_pulser +testconfig=$${i}; \
	done

# Clean simulation output
clean:
	rm -rf obj_dir logs *.vcd golden_pulser_core

.PHONY: compile all run run_all clean generate_simdata
