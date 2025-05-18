# pulser

## Reggen

### Source

To generate the rtl/pulser_reg_top.sv and pulser_reg_pkg.sv files, the regtool from the [`lowRISC/opentitan`](https://github.com/lowRISC/opentitan) repository is used. The used version corresponds to commit [`3864a6b`](https://github.com/lowRISC/opentitan/tree/3864a6b70c0dc2a0b0494cc596eb2fa5dce5f608).
The tool can be found under util/regtool.py in the opentitan repository.

### How to use

From the repository root, run `../opentitan/util/regtool.py -r -t rtl/ data/pulser.hjson`, or wherever the optentitan repository is located.

better: ../pulpissimo/hw/vendored_ips/gpio/util/reggen/regtool.py -r -t rtl/ data/pulser.hjson