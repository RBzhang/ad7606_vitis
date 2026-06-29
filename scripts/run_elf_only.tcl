# scripts/run_elf_only.tcl
# Fast AD7606 Zynq/Vitis run flow when the FPGA bitstream is already programmed:
#   1. Switch to ARM Cortex-A9 #0
#   2. Stop processor, then run ps7_init / ps7_post_config
#   3. Download ELF and run
#
# Use this script when only Vitis C code changed and the PL bitstream is unchanged.
#
# Path configuration priority:
#   1. Environment variables: AD7606_PS7_INIT, AD7606_ELF_FILE
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

proc stop_processor {why} {
    puts "Stopping processor $why..."
    if {[catch {stop} stop_msg]} {
        puts "WARNING: stop failed: $stop_msg"
        puts "If ps7_init fails with 'Cannot read memory if not stopped', reset/power-cycle the board or use run_full.tcl."
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

set PS7_ENV [getenv_or_empty AD7606_PS7_INIT]
set ELF_ENV [getenv_or_empty AD7606_ELF_FILE]

set PS7_CFG [var_or_empty AD7606_PS7_INIT]
set ELF_CFG [var_or_empty AD7606_ELF_FILE]

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

require_file "PS7_INIT" $PS7_INIT "Build the Vitis platform first, or set AD7606_PS7_INIT to platform_hello/export/platform_hello/hw/ps7_init.tcl"
require_file "ELF_FILE" $ELF_FILE "Build the Vitis application first, or set AD7606_ELF_FILE to hello_world/build/hello_world.elf"

puts "Using PS7_INIT : $PS7_INIT"
puts "Using ELF_FILE : $ELF_FILE"
puts "NOTE: This script does not program the FPGA bitstream. Use run_full.tcl if the board was power-cycled or the bitstream changed."

connect

targets
puts "Switching to ARM Cortex-A9 #0..."
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}

# ps7_init reads/writes PS registers through the selected ARM target. The ARM
# execution context must be stopped first; otherwise XSCT can fail with:
# "Cannot read memory if not stopped. Execution context is running".
stop_processor "before ps7_init"

puts "Running ps7_init / ps7_post_config..."
source $PS7_INIT
ps7_init
ps7_post_config

stop_processor "before downloading ELF"

puts "Downloading ELF..."
dow $ELF_FILE

puts "Running application..."
con
