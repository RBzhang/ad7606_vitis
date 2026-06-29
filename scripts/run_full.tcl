# scripts/run_full.tcl
# Full AD7606 Zynq/Vitis hardware run flow:
#   1. Program FPGA bitstream into PL
#   2. Switch to ARM Cortex-A9 #0
#   3. Reset and stop processor, then run ps7_init / ps7_post_config
#   4. Probe AXI BRAM and AXI GPIO
#   5. Download ELF and run
#
# Path configuration priority:
#   1. Environment variables: AD7606_BIT_FILE, AD7606_PS7_INIT, AD7606_ELF_FILE
#   2. Optional local config file: scripts/local_paths.tcl
#   3. Common auto-detected paths

proc getenv_or_empty {name} {
    global env
    if {[info exists env($name)]} {
        return $env($name)
    }
    return ""
}

proc var_or_empty {name} {
    upvar #0 $name v
    if {[info exists v]} {
        return $v
    }
    return ""
}

proc first_existing {paths} {
    foreach p $paths {
        if {$p ne "" && [file exists $p]} {
            return [file normalize $p]
        }
    }
    return ""
}

proc require_file {label path hint} {
    if {$path eq "" || ![file exists $path]} {
        puts "ERROR: $label not found."
        if {$path ne ""} {
            puts "Tried: $path"
        }
        puts $hint
        error "$label not found"
    }
}

proc reset_and_stop_processor {why} {
    puts "Resetting processor $why..."
    if {[catch {rst -processor} rst_msg]} {
        puts "WARNING: rst -processor failed: $rst_msg"
    }
    after 1000

    puts "Stopping processor $why..."
    if {[catch {stop} stop_msg]} {
        puts "ERROR: Cannot halt ARM Cortex-A9 #0: $stop_msg"
        puts "The processor may be wedged by a previous bad AXI access."
        puts "Press the board PS/System reset button or power-cycle the board, then run this script again."
        error "processor halt failed"
    }
}

set SCRIPT_DIR [file normalize [file dirname [info script]]]
set REPO_ROOT  [file normalize [file join $SCRIPT_DIR ..]]
set LOCAL_CONFIG [file join $SCRIPT_DIR local_paths.tcl]

if {[file exists $LOCAL_CONFIG]} {
    puts "Loading local path config: $LOCAL_CONFIG"
    source $LOCAL_CONFIG
} else {
    puts "No local path config found at scripts/local_paths.tcl. Using environment variables or auto-detected paths."
}

set BIT_ENV [getenv_or_empty AD7606_BIT_FILE]
set PS7_ENV [getenv_or_empty AD7606_PS7_INIT]
set ELF_ENV [getenv_or_empty AD7606_ELF_FILE]

set BIT_CFG [var_or_empty AD7606_BIT_FILE]
set PS7_CFG [var_or_empty AD7606_PS7_INIT]
set ELF_CFG [var_or_empty AD7606_ELF_FILE]

set BIT_FILE [first_existing [list \
    $BIT_ENV \
    $BIT_CFG \
    [file join $REPO_ROOT .. hello hello.runs impl_1 system_top.bit] \
    [file join $REPO_ROOT .. sample_7606 hello.runs impl_1 system_top.bit] \
    [file join $REPO_ROOT .. sample_7606 sample_7606.runs impl_1 system_top.bit] \
    [file join $REPO_ROOT hello.runs impl_1 system_top.bit] \
    [file join $REPO_ROOT sample_7606.runs impl_1 system_top.bit] \
    [file join $REPO_ROOT *.runs impl_1 system_top.bit] \
]]

set PS7_INIT [first_existing [list \
    $PS7_ENV \
    $PS7_CFG \
    [file join $REPO_ROOT platform_hello export platform_hello hw ps7_init.tcl] \
]]

set ELF_FILE [first_existing [list \
    $ELF_ENV \
    $ELF_CFG \
    [file join $REPO_ROOT hello_world build hello_world.elf] \
]]

require_file "BIT_FILE" $BIT_FILE "Set AD7606_BIT_FILE to the latest Vivado bitstream. Recommended: copy scripts/local_paths.example.tcl to scripts/local_paths.tcl and edit the paths."
require_file "PS7_INIT" $PS7_INIT "Build the Vitis platform first, or set AD7606_PS7_INIT to platform_hello/export/platform_hello/hw/ps7_init.tcl"
require_file "ELF_FILE" $ELF_FILE "Build the Vitis application first, or set AD7606_ELF_FILE to hello_world/build/hello_world.elf"

puts "Using BIT_FILE : $BIT_FILE"
puts "Using PS7_INIT : $PS7_INIT"
puts "Using ELF_FILE : $ELF_FILE"

connect

targets
puts "Programming FPGA bitstream..."
targets -set -filter {name =~ "xc7z020"}
fpga -file $BIT_FILE

puts "Switching to ARM Cortex-A9 #0..."
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}

# ps7_init reads/writes PS registers through the selected ARM target. Reset and
# stop the ARM first; otherwise XSCT can fail with:
# "Cannot read memory if not stopped. Execution context is running".
reset_and_stop_processor "before ps7_init"

puts "Running ps7_init / ps7_post_config..."
source $PS7_INIT
ps7_init
ps7_post_config

puts "Stopping processor before direct memory probe..."
reset_and_stop_processor "before BRAM/GPIO probe"

puts "Probing AXI BRAM at 0x40000000..."
mwr -force 0x40000000 0x12345678
mrd -force 0x40000000

puts "Probing AXI GPIO at 0x41200000..."
mrd -force 0x41200000

reset_and_stop_processor "before downloading ELF"

puts "Downloading ELF..."
dow $ELF_FILE

puts "Running application..."
con
