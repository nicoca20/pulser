# Pulser Core Testbench

This directory contains the testbench setup for simulating the `pulser_core` SystemVerilog module using Verilator with the `oseda` tools.

## Structure Overview

- **Makefile** – Automates the full simulation flow: generating stimuli, compiling RTL, and running simulations.
- **gen_pulser_golden.py** – Python script for generating configuration and stimuli files.
- **tb_pulser_core.sv** – SystemVerilog testbench module.

## Simulation Workflow

### Step 1: Build and Prepare Stimuli

Run the setup to generate all files:

```bash
make
```

This will:
- Generate stimuli using `gen_pulser_golden.py`
- Merge individual stimuli files into a single file
- Compile the Verilog sources using Verilator

### Step 2: Run the Simulation

To run the simulation with the merged stimuli file:

```bash
make run
```

Output is shown in the terminal, and waveform data is dumped to `waveform.vcd`.

## Additional Targets

You can invoke these Makefile targets manually:

| Target            | Description                                                                 |
|-------------------|-----------------------------------------------------------------------------|
| `make`            | Runs all required steps: generate, merge, compile                         |
| `make run`        | Runs simulation using the merged stimuli file                              |
| `make compile`    | Only compiles the Verilog sources                                          |
| `make generate_simdata` | Regenerates all individual stimuli files via the Python script       |
| `make merge_stimuli` | Merges all `stimuli_*.txt` files into `merged_stimuli.txt`              |
| `make test_cfg TESTCONFIG=N` | Runs simulation with `stimuli_N.txt` instead of the merged file |
| `make clean`      | Removes build artifacts and generated files                                |
| `make help`       | Shows usage information                                                     |

## Notes

- The simulation uses the `oseda` tool with Verilator as the backend.
- Stimuli files are located in `golden_pulser/` and are generated programmatically.
- The simulation executable is built into `obj_dir/`.
