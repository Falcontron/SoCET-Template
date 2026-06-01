## GPIO
Simple digital I/O module with input, output, and edge-triggered input interrupts.

[![Build](https://github.com/Purdue-SoCET/gpio/actions/workflows/test.yml/badge.svg)](https://github.com/Purdue-SoCET/gpio/actions/workflows/test.yml)

# Setup
Ensure you've configured the repository by running `./setup.sh`.
This script will:
- install the Fusesoc digital libraries
- install the git pre-commit hook
# Simulation
To run this in a simulation, execute:  
`fusesoc --cores-root . run --target sim socet:aft:gpio`  
Note that the default simulation tool is Verilator. You may add the flag:
`--tool <toolname>`
to use a different simulator, where <toolname> is a simulator of your choice, supported by fusesoc. Note that the simulator must support SystemVerilog to work.

# Parameters
The GPIO has a parameter `NUM_PINS` with legal values `1 <= NUM_PINS <= 32` to control the number of I/O pins generated. You can simulate with a value for `NUM_PINS` by adding the flag `--NUM_PINS=X` to your `fusesoc run` command.

# Other targets
There are targets for lint, format, and FPGA synthesis. See the file `gpio.core` for details.