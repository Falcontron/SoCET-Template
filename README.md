# ATTENTION
For documentation, please do the following:
1. Install [MdBook](https://github.com/rust-lang/mdBook)
2. Navigate to the `docs` directory, and run `mdbook build`
3. Open the file `book/index.html` in your favorite web browser.

TODO: Automatically build/serve the documentation so it is readable
without installing tools (happy to take PRs!)



## AFTx07 In-Progress
Requirements:
* FOR STUDENTS IN SOCET: FIX YOUR PYTHON PATH!! `export PYTHONPATH=""`    
* Install fusesoc: `pip3 install --user fusesoc`
OR use python virtual environment to install and use all required packages with required versions:
    - Initialize virtual environment: `python3 -m venv .venv`
    - Activate venv: `source .venv/bin/activate`
    - Install packages with pip: `pip3 install -r requirements.txt`
    - To reactivate venv (i.e. after logout): `source .venv/bin/activate` again (`deactivate` to exit venv)
* Setup Verilator path

# Simulation

To start, run "setup.sh" to do the following:
- Setup fusesoc libraries  
- Setup submodules
- Apply hotfix patches
- Config RISC-V core

Next, you can build the project by running "build.sh". This will
build the simulator for Verilator & Xcelium

Then, you can run AFTx07 simulation with:

`./aft_out/socet_aft_aftx07_2.0.0/sim-verilator/Vaftx07` for Verilator, or navigating the the 
`./aft_out_xcelium/socet_aft_aftx07_2.0.0/sim-xcelium/` directory, and running `make run` or `make run-gui`

You can also run using FuseSoC directly with the command:
`fusesoc --cores-root . run --target sim --tool <toolname> socet:aft:aftx07`

# Synthesis
The provided script `synthesis_setup.py` will generate a filelist for synthesis.
You must first run using fusesoc, but provide the `--no-export` flag (after `run`).
Then, give the `.eda.yml` file generated in the build process as an argument to
`synthesis_setup.py` to generate a filelist.

You can now include this filelist in a synthesis script to read in the HDL.
