# ELF-File Loading for Boot Loader
> As of April 27, 2024
## Overview
The boot loader of the AFTx07 previously did not have ELF-file loading capabilities. Therefore, modifications were made to `AFTx07/boot/v2/host.py` to allow for this.
## Modifications
In `AFTx07/boot/v2/host.py` ([host.py](../v2/host.py)), the Pyelftools library was imported. From this library, the `ELFFile` class was used in the program function.
Conditional statements were used to check the type of the file being loaded. In the case it was an ELF-file type, the `.text` section of the file was converted to binary data to be used for the rest of the code.
```
...
def program(protocol: Protocol, address: int, file_name: str):
    try:
        with open(file_name, "rb") as bin_file:
            bin = None
            if file_name.endswith(".elf"): # Check if file-type is ELF
                elf_file = ELFFile(bin_file)
                section = elf_file.get_section_by_name(".text") # Retrieve .text section of file
                bin = section.data() # Convert to binary
            else:
                bin = bin_file.read()
...
```

## Testing for FPGA
Before proceeding with testing, follow the steps in `AFTx07/doc/src/software_test.md` ([software_test.md](../../doc/src/software_test.md)) to generate the `.bin`/`.elf` files and the steps in `AFTx07/doc/src/fpga_test.md` ([fpga_test.md](../../doc/src/fpga_test.md)) to ensure the FPGA is ready for testing.
Once the `.bin`/`.elf` files are generated, add the file(s) to test into the same folder as the `host.py`. Then run `host.py`. Before running `host.py`, ensure that the serial port matches the port the UART is in and the baud rate is the one you want to use. For example:
```
host.py --serial /dev/tty.usbserial-A50285BI --baud 115200
```
In the terminal, enter:
```
program 0x8800 [file name].elf
```
> Make sure to program to address `0x8800` to avoid overwriting the boot loader’s RAM.

Then run:
```
enter 0x8800
```

To check if the FPGA is responding appropriately, run `host.py` again, and program the corresponding `.bin` file this time:
```
program 0x8800 [file name].bin
```
Run:
```
enter 0x8800
```
and check if the FPGA responds similarly to the ELF-file previously.
> If there are issues like the file not loading programming or no response from the FPGA, ensure that:
> * CTS pin on FTDI USB-to-Serial chip is grounded
> * `CPU_MHZ` in `BufferedUART.hh` is set to 25 instead of 30
> * Change `FF_RAM_SIZE` in `top_level/src/aftx07.sv` ([aftx07.sv](../../top_level/src/aftx07.sv)) to `64*K` instead of `32*K` (or alternatively change the linker that you use to build software tests to use only 16K of RAM)
> * If you're using riscv-gcc/13.2.0, include `stddef.h` in `crc.h` (alternatively build with riscv-gcc/12.2.0)
> * When building blink/pwm related tests from `AFTx07/sw-tests` ([sw-tests](../../sw-tests)) directory, run `cmake3` with `-DSYNTHESIS=1` to be able to see the LEDs blink - otherwise it will blink too fast to notice

## Future Work
As of now, the ELF-files cannot be run through the simulator; the simulator from `AFTx07/doc/src/simulation.md` ([simulation.md](../../doc/src/simulation.md)) only accepts binary files.
