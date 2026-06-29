@echo off
setlocal EnableExtensions

REM Full run flow: program FPGA bitstream, initialize PS, probe BRAM/GPIO, download ELF, run.
REM Optional environment variables before running this script:
REM   set AD7606_BIT_FILE=D:\path\to\system_top.bit
REM   set AD7606_PS7_INIT=D:\path\to\ps7_init.tcl
REM   set AD7606_ELF_FILE=D:\path\to\hello_world.elf

echo ============================================================
echo AD7606 full XSCT run
echo ============================================================

set VITIS_SETTINGS=C:\Xilinx\Vitis\2024.2\settings64.bat

if exist "%VITIS_SETTINGS%" (
    echo Loading Vitis environment: %VITIS_SETTINGS%
    call "%VITIS_SETTINGS%"
) else (
    echo WARNING: %VITIS_SETTINGS% not found.
    echo Assuming xsct is already available in PATH.
)

where xsct >nul 2>nul
if errorlevel 1 (
    echo ERROR: xsct was not found in PATH.
    echo Open "Vitis 2024.2 Command Prompt" and run this script again,
    echo or fix VITIS_SETTINGS in this .bat file.
    goto end
)

cd /d "%~dp0\.."
echo Working directory: %CD%
echo.

REM Use CALL because xsct may resolve to a .bat/.cmd wrapper on Windows.
REM Without CALL, this wrapper can terminate before reaching PAUSE.
call xsct scripts\run_full.tcl

set XSCT_EXIT=%ERRORLEVEL%
echo.
echo XSCT exit code: %XSCT_EXIT%

:end
echo.
echo Press any key to close this window...
pause >nul
endlocal
