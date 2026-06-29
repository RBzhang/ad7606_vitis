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
├── hello_world/                # Application component
│   ├── vitis-comp.json         # Application descriptor
│   └── src/                    # Application source
│       ├── helloworld.c        # Hello World / BRAM test entry point
│       ├── platform.c / .h     # Platform init / cleanup
│       ├── lscript.ld          # Linker script
│       ├── CMakeLists.txt
│       └── UserConfig.cmake
└── scripts/                    # XSCT one-click helper scripts
    ├── run_full.tcl            # Program bitstream + ps7_init + probe + ELF run
    ├── run_full.bat            # Windows wrapper for run_full.tcl
    ├── run_elf_only.tcl        # ps7_init + ELF run, no bitstream program
    └── run_elf_only.bat        # Windows wrapper for run_elf_only.tcl
```

## Required Development Environment

- **Vivado / Vitis 2024.2** (or later 2024.x)
- Windows or Linux host
- Zynq board connected through JTAG and UART
- Serial terminal set to `115200 8N1`, no flow control

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

### 3. Basic UART run on hardware

1. Connect the Zynq board via JTAG and serial (UART 0, 115200 8N1).
2. Right-click `hello_world` → **Run As → Launch on Hardware**.
3. The serial terminal should print:

```
Hello World
Successfully ran Hello World application
```

This proves that the PS UART, serial terminal, JTAG download flow, and Vitis
application build are correct. It does **not** by itself prove that the PL-side
AXI BRAM is already programmed and accessible.

## One-Click Scripted Runs

The `scripts/` directory contains helper scripts so the XSCT commands do not
need to be typed manually every time.

### Full run: program bitstream + initialize PS + run ELF

Use this when:

- the board was power-cycled;
- the Vivado bitstream changed;
- the PL status is uncertain;
- you want to re-check AXI BRAM/GPIO before running the ELF.

On Windows, run:

```bat
scripts\run_full.bat
```

Or run the Tcl script directly in XSCT:

```tcl
xsct scripts/run_full.tcl
```

The full script performs:

```text
connect
→ select xc7z020
→ fpga -file system_top.bit
→ select ARM Cortex-A9 MPCore #0
→ ps7_init / ps7_post_config
→ mwr -force 0x40000000 0x12345678
→ mrd -force 0x40000000
→ mrd -force 0x41200000
→ dow hello_world.elf
→ con
```

Expected BRAM probe result:

```text
40000000:   12345678
```

### Fast run: initialize PS + run ELF only

Use this when only Vitis C code changed and the FPGA bitstream is already
programmed.

On Windows, run:

```bat
scripts\run_elf_only.bat
```

Or run the Tcl script directly in XSCT:

```tcl
xsct scripts/run_elf_only.tcl
```

This script does **not** program the FPGA bitstream. If the board was reset or
power-cycled, use `run_full.bat` instead.

### Script path configuration

The scripts try to find the common local paths automatically:

- `platform_hello/export/platform_hello/hw/ps7_init.tcl`
- `hello_world/build/hello_world.elf`
- nearby Vivado bitstream paths such as `../sample_7606/.../system_top.bit`

If the bitstream or ELF is in another location, set environment variables before
running the script.

Windows example:

```bat
set AD7606_BIT_FILE=D:\BaiduNetdiskDownload\hellovitis\hello.runs\impl_1\system_top.bit
set AD7606_ELF_FILE=D:\BaiduNetdiskDownload\hellovitis\hello_world\build\hello_world.elf
set AD7606_PS7_INIT=D:\BaiduNetdiskDownload\hellovitis\platform_hello\export\platform_hello\hw\ps7_init.tcl
scripts\run_full.bat
```

Linux/macOS shell example:

```sh
export AD7606_BIT_FILE=/path/to/system_top.bit
export AD7606_ELF_FILE=/path/to/hello_world.elf
export AD7606_PS7_INIT=/path/to/ps7_init.tcl
xsct scripts/run_full.tcl
```

## Recommended XSCT Hardware Bring-Up Flow

For BRAM and GPIO testing, use XSCT first. This makes the order explicit:

1. Program the FPGA bitstream into PL.
2. Switch back to the ARM target.
3. Run `ps7_init` and `ps7_post_config`.
4. Verify AXI BRAM and AXI GPIO by direct memory access.
5. Download the Vitis ELF and run it.

The manual command sequence is shown below for reference. In normal daily use,
prefer the scripts in `scripts/`.

```tcl
connect

# 1. Select the FPGA device and program the latest bitstream.
targets
targets -set -filter {name =~ "xc7z020"}
fpga -file {D:/BaiduNetdiskDownload/hellovitis/hello.runs/impl_1/system_top.bit}

# 2. Switch back to Cortex-A9 #0 before running PS init commands.
targets
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}

# 3. Initialize PS clocks, MIO, DDR, UART, and related PS settings.
source {D:/BaiduNetdiskDownload/hellovitis/platform_hello/export/platform_hello/hw/ps7_init.tcl}
ps7_init
ps7_post_config

# 4. Stop the processor before direct XSCT memory access.
stop

# 5. Verify AXI BRAM at 0x40000000.
#    -force is used because XSCT may block PL AXI addresses unless forced.
mwr -force 0x40000000 0x12345678
mrd -force 0x40000000

# 6. Optionally verify AXI GPIO at 0x41200000.
mrd -force 0x41200000

# 7. Download and run the application ELF.
dow {D:/BaiduNetdiskDownload/hellovitis/hello_world/build/hello_world.elf}
con
```

Expected BRAM result:

```text
40000000:   12345678
```

If this result appears, the following hardware path has been verified:

```text
PS Cortex-A9 → M_AXI_GP0 → AXI interconnect/SmartConnect → AXI BRAM Controller → BRAM
```

If `mrd -force 0x41200000` returns a value such as `00000000`, the AXI GPIO
slave is also reachable from the PS.

### Important Target-Selection Rule

`fpga -file` must be executed while the current target is the FPGA device:

```tcl
targets -set -filter {name =~ "xc7z020"}
fpga -file {path/to/system_top.bit}
```

`ps7_init`, `ps7_post_config`, `dow`, and `con` must be executed after switching
back to the ARM processor target:

```tcl
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
source {path/to/ps7_init.tcl}
ps7_init
ps7_post_config
dow {path/to/hello_world.elf}
con
```

If `ps7_init` is executed while the target is still `xc7z020`, XSCT may report:

```text
Context does not support memory read. Unsupported command
```

That means the target is wrong. Switch to `ARM Cortex-A9 MPCore #0` and run
`ps7_init` again.

## BRAM Test Entry Point

The AXI BRAM controller is mapped at base address `0x40000000` with a size of
`0x10000` (64 KB). AXI GPIO is expected at `0x41200000`.

A minimal PS-side BRAM/GPIO access test can be placed in
`hello_world/src/helloworld.c`:

```c
#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "xil_io.h"
#include "xil_cache.h"
#include "xil_mmu.h"

#define BRAM_BASE 0x40000000U
#define GPIO_BASE 0x41200000U

int main()
{
    u32 v;

    init_platform();

    print("\r\nBRAM TEST VERSION 02\r\n");

    Xil_DCacheDisable();
    Xil_ICacheDisable();

    Xil_SetTlbAttributes(BRAM_BASE, 0x14de2U);
    Xil_SetTlbAttributes(GPIO_BASE, 0x14de2U);

    xil_printf("BRAM_BASE = 0x%08x\r\n", BRAM_BASE);

    print("before BRAM write\r\n");
    Xil_Out32(BRAM_BASE + 0x00, 0x12345678U);
    print("after BRAM write\r\n");

    print("before BRAM read\r\n");
    v = Xil_In32(BRAM_BASE + 0x00);
    print("after BRAM read\r\n");

    xil_printf("BRAM[0] = 0x%08x\r\n", v);

    print("before GPIO read\r\n");
    v = Xil_In32(GPIO_BASE + 0x00);
    print("after GPIO read\r\n");

    xil_printf("GPIO[0] = 0x%08x\r\n", v);

    print("BRAM/GPIO test done\r\n");

    while (1) {
    }

    cleanup_platform();
    return 0;
}
```

Expected serial output after running the ELF:

```text
BRAM TEST VERSION 02
BRAM_BASE = 0x40000000
before BRAM write
after BRAM write
before BRAM read
after BRAM read
BRAM[0] = 0x12345678
before GPIO read
after GPIO read
GPIO[0] = 0x00000000
BRAM/GPIO test done
```

## Troubleshooting

### `Cannot access FPGA: Bitstream is not programmed`

The PL bitstream has not been downloaded. Run:

```tcl
targets -set -filter {name =~ "xc7z020"}
fpga -file {path/to/system_top.bit}
```

Then switch back to the ARM target and rerun `ps7_init`.

### `PL AXI slave ports access is not allowed. This address has not been added to the memory map`

Use forced XSCT memory access:

```tcl
mwr -force 0x40000000 0x12345678
mrd -force 0x40000000
```

This is an XSCT access-protection issue. It does not necessarily mean the AXI
BRAM is broken.

### `Context does not support memory read. Unsupported command`

`ps7_init` was likely run while the current target was `xc7z020`. Switch to the
ARM target first:

```tcl
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
source {path/to/ps7_init.tcl}
ps7_init
ps7_post_config
```

### Program stops after `before BRAM write`

The CPU is probably stuck on the first AXI access:

```c
Xil_Out32(0x40000000, 0x12345678U);
```

Check the following items:

- The latest bitstream has actually been programmed into the FPGA.
- The Vitis platform was rebuilt from the latest XSA.
- `M_AXI_GP0_ACLK` is connected to `FCLK_CLK0`.
- The AXI interconnect/SmartConnect clocks are connected.
- `axi_bram_ctrl_0/s_axi_aclk` is connected.
- `axi_bram_ctrl_0/s_axi_aresetn` is driven by a released active-low reset.
- Address Editor maps AXI BRAM to `0x40000000` with range `0x10000`.
- AXI BRAM Controller is connected to Block Memory Generator.

### `BRAM_BASE` prints as a strange large value

Use `%08x` for 32-bit addresses with `xil_printf`:

```c
xil_printf("BRAM_BASE = 0x%08x\r\n", BRAM_BASE);
```

Avoid `%lx` and pointer-style formats in early bare-metal tests.

## Recommended Next Bring-Up Steps

After the PS-side BRAM/GPIO test passes:

1. Keep using the explicit XSCT order: `fpga -file` → `ps7_init` → `dow` → `con`.
2. Test PL-generated dummy samples before connecting real AD7606 data.
3. Use GPIO control bits to reset the BRAM writer, clear ready flags, and enable capture.
4. Poll `bank0_ready` / `bank1_ready` from the PS.
5. Dump the first 16 samples from BRAM over UART.
6. After BRAM is stable, move to lwIP/Ethernet testing.

Suggested staged path:

```text
UART print
  ↓
XSCT BRAM mwr/mrd
  ↓
C program BRAM self write/read
  ↓
C program GPIO read/write
  ↓
PL dummy data → BRAM → PS UART dump
  ↓
AD7606 data → BRAM → PS UART dump
  ↓
AD7606 data → BRAM → Ethernet
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
