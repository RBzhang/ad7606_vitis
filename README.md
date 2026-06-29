# AD7606 Zynq/Vitis Software Project

Vitis 2024.2 embedded software workspace for the AD7606 data-acquisition system
running on a Xilinx Zynq-7000 (7z020) SoC.

The Vivado hardware project is **not** included in this repository. The hardware
platform is defined by the `.xsa` file exported from Vivado and stored at the
workspace root.

## Hardware Design Summary

- **SoC**: Xilinx Zynq-7000 (7z020)
- **Memory**: PS7 DDR, OCM (RAM), AXI BRAM controller at `0x40000000`
- **Peripherals**: PS7 UART 0 (serial), GEM 0 (Ethernet), GPIO
- **UART**: 115200 bps, 8 data bits, no parity, 1 stop bit, no flow control
- **Status**: Hello World serial print has been verified on hardware

## Repository Structure

```
.
├── system_top.xsa              # Hardware platform (XSA) from Vivado
├── design_1_wrapper.xsa        # Alternative XSA export
├── platform_hello/             # Vitis platform component
│   ├── vitis-comp.json         # Platform descriptor
│   ├── hw/                     # Hardware artefacts (XSA copy, device-tree)
│   ├── resources/              # QEMU arguments
│   ├── zynq_fsbl/              # First Stage Bootloader (FSBL)
│   └── ps7_cortexa9_0/        # BSP for standalone domain (Cortex-A9 #0)
└── hello_world/                # Application component
    ├── vitis-comp.json         # Application descriptor
    └── src/                    # Application source
        ├── helloworld.c        # Hello World test
        ├── platform.c / .h     # Platform init / cleanup
        ├── lscript.ld          # Linker script
        ├── CMakeLists.txt
        └── UserConfig.cmake
```

## Required Development Environment

- **Vivado / Vitis 2024.2** (or later 2024.x)
- Windows or Linux host

## How to Rebuild

### 1. Create the Vitis platform from the XSA

1. Launch Vitis 2024.2 and select this directory as the workspace.
2. If the platform component does not appear automatically:
   - **File → New Component → Platform**
   - Give it the name `platform_hello`.
   - Browse to `system_top.xsa` (at workspace root) as the hardware design.
   - Select the **standalone** OS for `ps7_cortexa9_0`.
   - Enable FSBL generation for `zynq_fsbl`.
3. Build the platform:
   - Right-click `platform_hello` → **Build Platform**

This generates the `platform_hello/export/` directory (git-ignored) and
compiles the FSBL + standalone BSP libraries.

### 2. Build the Hello World application

1. If the application component does not appear automatically:
   - **File → New Component → Application**
   - Name it `hello_world`.
   - Select the `platform_hello` platform.
   - Choose the `standalone_ps7_cortexa9_0` domain.
   - Select the `hello_world` template.
2. Build the application:
   - Right-click `hello_world` → **Build**

### 3. Run on hardware

1. Connect the Zynq board via JTAG and serial (UART 0, 115200 8N1).
2. Right-click `hello_world` → **Run As → Launch on Hardware**.
3. The serial terminal should print:

```
Hello World
Successfully ran Hello World application
```

## BRAM Test Entry Point

The AXI BRAM controller is mapped at base address `0x40000000` with a size of
`0x10000` (64 KB). A BRAM test can be added in `hello_world/src/helloworld.c`
by including the `xbram` driver from the BSP.

Example skeleton:
```c
#include "xbram.h"
// XBram_Config *cfg = XBram_LookupConfig(XPAR_AXI_BRAM_CTRL_0_S_AXI_BASEADDR);
```

## Notes

- The `app.yaml` files under `hello_world/src/` and `platform_hello/zynq_fsbl/`
  contain a reference to the Vitis installation path
  (`C:\Xilinx\Vitis\2024.2\data\...`). These paths reflect the original
  development machine and do not affect the build. Vitis will update them
  automatically when the workspace is opened on a different machine.
- Build, export and IDE metadata directories (`build/`, `export/`, `_ide/`,
  `.cache/`) are excluded from version control by `.gitignore`.
- The XSA files are tracked by plain Git (each < 1 MB). No Git LFS is required.
