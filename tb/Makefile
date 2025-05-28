# Directories
TB_DIR := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
RTL_DIR := $(TB_DIR)/../rtl
OUTPUT_DIR := obj_dir
TOP_MODULE := tb_pulser_core
TESTCONFIG ?= 0  # Default test config
TEMPFILE := golden_pulser/merged_stimuli.txt

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

STIMULI_COUNT := $(shell ls golden_pulser/stimuli_*.txt 2>/dev/null | wc -l)


# Compile and run all test configs
all: generate_simdata merge_stimuli compile run

compile: $(OUTPUT_BIN)

$(OUTPUT_BIN): $(VERILOG_SOURCES)
	$(VERILATOR) $(VERILATOR_ARGS) --top $(TOP_MODULE) $(VERILOG_SOURCES)

merge_stimuli:
	@echo "Merging stimuli files into $(TEMPFILE)..."
	@rm -f $(TEMPFILE)
	@head -n 1 golden_pulser/stimuli_0.txt > $(TEMPFILE) # Write header
	@for file in $$(ls golden_pulser/stimuli_*.txt | sed -E 's/.*stimuli_([0-9]+)\.txt/\1 &/' | sort -n | cut -d' ' -f2); do \
		if [ "$$file" != "golden_pulser/stimuli_0.txt" ]; then \
			tail -n +2 "$$file" >> $(TEMPFILE); \
		fi \
	done

# Generate simulation data using Python script
generate_simdata:
	python3 gen_pulser_golden.py

# Run a specific test config (use `make run TESTCONFIG=X`)
run_config: $(OUTPUT_BIN)
	@echo "Running testconfig $(TESTCONFIG)..."
	oseda -2025.01 ./obj_dir/Vtb_pulser_core +stimuli=golden_pulser/stimuli_$(TESTCONFIG).txt

# Run all test configs sequentially
run: $(OUTPUT_BIN)
	@echo "Running simulation with merged stimuli file..."
	oseda -2025.01 ./obj_dir/Vtb_pulser_core +stimuli=$(TEMPFILE)

# Clean simulation output
clean:
	rm -rf obj_dir logs *.vcd golden_pulser

.PHONY: compile all run run_config clean generate_simdata
