# Pulser
[![SHL-0.51 License](https://img.shields.io/badge/license-SHL--0.51-green)](LICENSE)

**Pulser** is a SystemVerilog-based project that generates precisely timed output pulses with fully configurable parameters. It includes:
- A complete RTL implementation (`pulser.sv` & `pulser_core.sv`)
- A simulation environment and testbench
- Auto-generated register files (via HJSON + `regtool.py`)
- Auto-generated C-header for software control (not included, can be generated)
- A top-level bus interface (OBI) for easy integration

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Pulser Configuration](#pulser-configuration)
3. [Features](#features)
4. [Overview](#overview)
5. [Block Diagrams](#block-diagrams)
   - [Simplified Architecture](#simplified-architecture)
   - [Full System Architecture](#full-system-architecture)
6. [Register Generation](#register-generation)
   - [Generate Register Files](#generate-register-files)
7. [License](#license)

---

## Quick Start

1. **Clone the repository**
   ```bash
   git clone <your-repo-URL>
   cd pulser
   ```

2. **Generate Register Files**
   ```bash
   # Generate SystemVerilog register banks under rtl/
   regtool.py -r -t rtl/ data/pulser_core.hjson
   regtool.py -r -t rtl/ data/pulser_general.hjson

   # Generate C headers under sw/
   regtool.py -D data/pulser_core.hjson -o sw/pulser_core_reg_defs.h
   regtool.py -D data/pulser_general.hjson -o sw/pulser_general_reg_defs.h
   ```

3. **Simulate pulser_core**
   - Testbench: `sim/tb_pulser_core.sv`
   - Run your simulator (e.g., VCS, Questa, or Verilator) on `tb_pulser_core.sv`.

4. **Integrate into SoC**
   - Connect the top-level `pulser` module’s OBI interface to your interconnect.
   - Use the auto-generated C header (`sw/pulser_core_reg_defs.h`) to read/write registers.

---

## Features

- **Parameterizable Pulse Generator**
  - Supports multiple independent pulse instances (`N_PULSER_INST`).
  - Configurable durations, duty-cycles, and stop behavior.

- **Register-Mapped Interface**
  - Exposes all control/configuration registers via OBI (Open Bus Interface).
  - Auto-generated register definitions (HJSON → SV/C).

- **Software-Controllable**
  - Start/Stop mechanisms for each pulser instance.
  - Shared “general” register to enable/disable clocks and synchronusly start / stop pulsers.

- **Clock Gating**
  - Per-instance clock gating to minimize power when idle.

- **Simulation Environment**
  - `pulser_core` testbench with waveform dumping.
  - Golden Model, written in python.
  - Example sequences demonstrating F1, F2, and stop pulses.

---

## Overview

Two primary modules form the Pulser design:

1. **`pulser` (Top-Level Wrapper)**
   - Instantiates multiple `pulser_core` units (one per pulse channel).
   - Demultiplexes OBI register requests to each core’s register bank.
   - Provides a “general” register set for clock enable, global start/stop.

2. **`pulser_core` (Pulse Generation Logic)**
   - Implements a finite-state machine (FSM) to generate precise pulses.
   - Supports two frequencies (F1 & F2), plus a final inverted “stop” pulse.
   - Outputs a single-bit `pulse_o` per instance.
   - returns current FSM-state.

All register files are generated from two HJSON files:
- `data/pulser_core.hjson`
- `data/pulser_general.hjson`

---

## Block Diagrams

### Simplified Architecture

The diagram below shows a conceptual single-`pulser_core` setup with its register interface (not an actual instantiation in RTL). It illustrates how the core, register file, and clock gating fit together.

![Single Pulser Block Diagram](./doc/bd_single_pulser.svg)

- **`periph_to_reg`**: Bridges OBI-style bus to internal `reg_req`/`reg_rsp`.
- **`pulser_core_reg_top`**: Register bank housing control (start/stop) and config (F1, F2) fields.
- **`pulser_core`**: FSM-driven pulse generator.
- **`tc_clk_gating`**: Cell to disable `pulser_core`'s clock.

### Full System Architecture

In a real instantiation (e.g. `N_PULSER_INST = 2`), a multiplexer/demultiplexer routes register accesses to the correct core. A “general” register bank controls clock enables and global settings. Components in blue are replicated for each instance.

![Full System Architecture](./doc/bd_pulser.svg)

1. **`periph_to_reg`** (shared)
2. **`pulser_core_reg_top`** (one per instance)
3. **`pulser_general_reg_top`** (shared)
4. **`pulser_core`** (one per instance)
5. **`tc_clk_gating`** (one per instance)

---

## Pulser Configuration

For detailed instructions on configuring and operating the Pulser, see the [Pulser Configuration Guide](doc/pulser_usage.md).

---

## Register Generation

All registers are defined in HJSON under `data/` and converted via `regtool.py`:
- Core registers: `pulser_core.hjson`
- General registers: `pulser_general.hjson`

### Generate Register Files

#### SystemVerilog

```bash
# Core register bank (rtl/pulser_core_reg_pkg.sv etc.)
regtool.py -r -t rtl/ data/pulser_core.hjson

# General register bank (rtl/pulser_general_reg_pkg.sv etc.)
regtool.py -r -t rtl/ data/pulser_general.hjson
```

#### C Headers

```bash
# Core C definitions (sw/pulser_core_reg_defs.h)
regtool.py -D data/pulser_core.hjson -o sw/pulser_core_reg_defs.h

# General C definitions (sw/pulser_general.hjson)
regtool.py -D data/pulser_general.hjson -o sw/pulser_general_reg_defs.h
```

The version of `regtool.py` used is from the [pulp-platform/carfield](https://github.com/pulp-platform/carfield) repository, commit `0136ff9`.

---

## License

Pulser is open-source under the **Solderpad Hardware License v0.51** (SHL-0.51).
See [LICENSE](LICENSE) for full details.
