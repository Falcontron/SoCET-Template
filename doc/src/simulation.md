# Simulating AFTx07

## Repository Structure
AFT-dev is structured as a repository containing the top-level integration file, a TB thereof, and a list of submodules pointing to other repos containing the IP. Convenience scripts are provided for assisting in the setup, but ultimately builds/simulation are done with [FuseSoC](https://github.com/olofk/fusesoc). 

## Simulation Setup
Ensure that you have Verilator >= 5 in your environment. (SoCET students: Look on the Wiki > Digital Design > [Setup for AFT & RISCVBusiness Simulation](https://wiki.itap.purdue.edu/pages/viewpage.action?pageId=169481733)). 
You will also need the following python packages:
```
pyyaml
fusesoc
```

It is recommended to use a virtual environment. To make this easy, a `requirements.txt` is provided in the repository. You can set up the venv with:
```
python3 -m venv .venv
source .venv/bin/activate
pip3 install -r requirements.txt
```

To setup and build the repo, run the following commands:
```
./setup.sh
./build.sh
```
`setup.sh` will install the fusesoc libraries, update the git submodules, and apply some hotfix patches.
`build.sh` will run fusesoc to build both the Verilator and Xcelium simulations. For other simulators, you should run fusesoc manually with your desired tool. The build outputs will be placed in the `./aft_out` directory. The Verilator binary can be invoked directly, the Xcelium sim should be run by changing to the directory `./aft_out/sim-xcelium` and running `make run` or `make run-gui` as needed.

## Running Simulations
Simulations use a sim-only memory model. Currently it is provisioned with 64K of memory (compile times are high with larger memory) originating at 0x8400 as in the memory map. 
By default, simulations will read from two files in the directory from where the simulation is run:
- `meminit.bin`, which must be a flat binary file. You may also use the `--meminit-file` flag to specify a different location for your `.bin` file.
- `firmware.bin`, which must be a flat binary file. You may also use the `--firmware-file` flag to specify a different location for your `.bin` file.

Verilator simulations can be done by invoking the binary `./aft_out/sim-verilator/Vaftx07`. The Verilator version is our primary development version, and the testbench provides a few useful flags:
- `--meminit-file` allows you to specify the path to the `.bin` file containing the initial memory contents.
- `--firmware-file` allows you to specify the path to the `.bin` file containing the bootup firmware.
- `--trace-en` enables FST wave tracing, for viewing in GTKWave or Surfer
- `--trace-start <n>` allows you to specify a cycle at which to start tracing. This is useful if you want to debug something that happens after thousands of cycles without creating large wave dumps or slow simulations.
- `--cycle-limit <n>` allows you to specify the end cycle for simulation. Useful for cases where you want to stop a simulation early (for smaller wave dumps), or if you know the program will enter an infinite loop.
- `--mem-latency <n>` allows you to configure clock cycle latency for memory access. Useful for simulating extra cycles for off-chip RAM.
- `--uart` allows UART simulation. This will open a local TCP server you can connect to with programs like `netcat` to send and receive bytes over the simulated UART
- `--version` print version information and quit
- `--help` display the 'help' information and quit.


You can also enable instruction-level tracing by (manually) editing the file `RISCVBusiness/RISCVBusiness.core`. Uncomment `trackers` in the `default` target of the core file. Next, uncomment the instantiation of `cpu_tracker` in `RISCVBusiness/source_code/standard_core/top_core.sv`. Finally, rebuild the simulator. Now when you run the sim, it will generate a file named `trace.log` that has a trace of *committed* instructions. This in tandem with disassembly of your software program can help with debugging immensely.

Changing build-time properties
- simulation properties, such as the number of harts, cache size, and block size can be specified in `aftx07.rvbcfg.yml`. After editing this file, run through the rebuild steps below.

## Rebuilding Simulations
After edits are made to the RTL, the simulation needs to be rebuilt and re-run.

1. `ccache -C`. Important! This clears the build cache and prevents past builds from affecting your new build.
2. `rm -rf aft_out; rm -rf aft_out_xcelium`. This removes the build folders.
3. `git submodule sync; git submodule update`. Optional. Only neccesary if submodules such as `RISCVBusiness` have been updated.
4. `build.sh`. Rebuilds the simulation.

