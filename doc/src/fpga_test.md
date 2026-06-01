# FPGA Testing

## Setup
The FPGA testing toolchain utilizes FuseSoC to facilitate building via Quartus targeting the Cyclone IV E on the DE2-115 development board.

Ensure that you have the Intel Quartus module loaded (`ml intel/quartus-std`) and update the wrapper file `./fpga/aftx07_fpga.sv` and pin-mapping script `./fpga/pinmap.tcl` as needed. See the [DE2-115 User Manual](https://www.terasic.com.tw/attachment/archive/502/DE2_115_User_manual.pdf) for pin mappings. To map a `aftx07_fpga` port signal `SIGNAL_X` to a pin `PIN_0`, add the following statements to the pin-mapping script:
```
set_location_assignment PIN_0 -to SIGNAL_X
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SIGNAL_X
```

> **If you are working at a workstation that is not locally synched with asicfab:**
>
> You may need to add the modulefiles path to your `MODULEPATH` to be able to load the Quartus module. In a local terminal instance, run:
> ```
> export MODULEPATH=/package/eda/setup/modulefiles:$MODULEPATH
> module load intel/quartus-std/21.1
> ```
> Now the Quartus module should be loaded. Test by executing `quartus` which should open the Quartus GUI.


To build AFTx07, optionally with IO synchronization wrapper, with Quartus, run the corresponding FuseSoC command in the `AFTx07/` directory:
```
fusesoc --cores-root . run --build --target fpga socet:aft:aftx07
fusesoc --cores-root . run --build --target fpga socet:aft:aftx07_wrapper
```
The build will create a `./build/module/fpga-quartus/` directory for the given module.

> **If you are working at a workstation that is not locally synched with asicfab:**
>
> You will need to copy the `fpga-quartus/` build folder from asicfab to the local file system. You can do this using scp:
> ```
> scp -r socet##@asicfab:"path/to/AFTx07/build/module/fpga-quartus/" ~/fpga-quartus
> ```
> The Quartus build folder will be copied over into `~/fpga-quartus` on the local file system.
>
> The remaining Quartus-related steps assumes that you are working from this build directory if this is your case.

To open the build project in the Quartus GUI, select `File -> Open Project...` and then locate the `.qpf` project file in the `./build/module/fpga-quartus/` directory and open it.

Analysis & Synthesis, the Fitter, and the Assembler will likely have to be re-run before being able to program the FPGA, but before doing so, a memory initialization file (MIF) can be copied into the project directory if needed. Once the design has been compiled, program the FPGA via `Tools -> Programmer -> Start`. If the start button is greyed out, ensure that the USB Blaster is selected in the `Hardware Setup` menu.

## Loading Programs into Memory
Quartus utilizes a .mif file to initialize on-board memory blocks. After copying a binary file to `meminit.bin`, run the binary to MIF conversion script: `python3 bin_to_mif.py` to generate `fpgainit.mif`. Copy this file into the desired module's `./build/module/fpga-quartus/` directory.


> **If you are working at a workstation that is not locally synched with asicfab:**
>
> Each time you want to use a new `.mif` file, you will need to copy it over from asicfab into the local `fpga-quartus/` build directory. You can use the following scp command to do so:
> ```
> scp socet##@asicfab:"path/to/AFTx07/fpgainit.mif" ~/fpga-quartus/fpgainit.mif
> ```

If the module has already been synthesized and routed by Quartus, the .mif file can be updated by following the aformentioned steps and then:
1. In the Quartus GUI, run `Processing -> Update Memory Initialization File`
2. Run the `Assembler` from the `Tasks` window
3. Program the FPGA via `Tools -> Programmer -> Start`

## Writing and Building Software Tests
The toolchain is designed so that software tests run interchangeably both in simulation and in synthesis on FPGA. This is achieved via defining the `SYNTHESIS` CMake build flag - see the [Software Testing](./software_test.md) page for build instructions.

To keep tests portable between simulation and synthesis, use the `SYNTHESIS` macro to conditionally compile FPGA-specific code where possible, though some tests may be wholly FPGA-specific.

## External Hardware Information
External hardware information used by FPGA routines and tests. Pin names from the FPGA refer to a function of an IO mux pin whose mapping can be found on the [IO Mux APB Register Map](https://wiki.itap.purdue.edu/display/ecedesign/APB+Register+Map) Wiki page. AFTx07's IO pins are currently mapped so that PinX = GPIO[X] on the FPGA.

### FPGA print()
The FPGA print routine targets the 1602A-OLED display using the following connections (FPGA -> OLED):
- GPIO1 -> Pin 14 (SDI)
- GPIO2 -> Pin 12 (SCL)
- GPIO3 -> Pin 16 (/CS)

### spi_tft.c Test
The `spi_tft.c` test targets the 2.2in SPI TFT LCD ILI9341 using the following connections (FPGA -> LCD):
- GPIO0    -> Pin 4 (nRESET)
- GPIO4    -> Pin 3 (CS)
- GPIO7    -> Pin 5 (DC)
- SPI_0 MOSI -> Pin 6 (SDI)
- SPI_0 SCK  -> Pin 7 (SCK)

## Automation Scripts
An automated script, `fpga_build.sh`, has been setup to automate the steps above when working on an ececomp lab machine. This must be ran on asicfab to have access to the correct build tools.

The script will build the fpga_quartus folder and copy it into a folder on your lab machine, alongside the quartus automation scripts, and a makefile.

> **On asicfab, run:**
> ```
> ./fpga_build
> ```
>**Flags:**
> ```
> -o <file_name>    Set output directory path on local machine
> -n                Compile the FPGA *without* the wrapper
> ```

Once running locally, the provided makefile can allow the compiling, programing, and flashing of the FPGA.

> **On SOCET lab machines, run:**
> 
> ```
> make fpga_compile # Only needs ran once per new fpga build
> make fpga_program # Programs FPGA to the AFT
> make fpga_flash # Uploads a memory initilization file (see below)
> ```

To use `fpga_flash`, the program must be a .mif. See the section above about uploading a program to memory for details on how to create the file.


> By default, the program will be uploaded to `0x8400`. To change this, modify the below line in fpga_flash.tcl, changing 0 to the **word**-offset from 0x8400
> ```
> update_content_to_memory_from_file -instance_index 0 -mem_file_path "../../../fpgainit.mif" -mem_file_type mif
> ```