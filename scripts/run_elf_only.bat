@echo off
setlocal

REM Fast run flow: initialize PS, download ELF, run.
REM Use this only when the FPGA bitstream is already programmed and unchanged.
REM Optional environment variables before running this script:
REM   set AD7606_PS7_INIT=D:\path\to\ps7_init.tcl
REM   set AD7606_ELF_FILE=D:\path\to\hello_world.elf

set VITIS_SETTINGS=C:\Xilinx\Vitis\2024.2\settings64.bat

if exist "%VITIS_SETTINGS%" (
    call "%VITIS_SETTINGS%"
) else (
    echo WARNING: %VITIS_SETTINGS% not found.
    echo Assuming xsct is already available in PATH.
)

cd /d "%~dp0\.."
xsct scripts\run_elf_only.tcl

pause
