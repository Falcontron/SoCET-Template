# Software Testing

## Toolchain setup
Ensure that you have the RISC-V toolchain in your environment. Alternatively, build a new RISC-V toolchain from source, and make sure it is added to your PATH.

### Test code
Tests should be single ".c" files placed in the directory `./sw-tests/`. They should have a function with the prototype `int main()` (**no arguments**). Functions should return 0 on success, and any other value on failure.

## The "Femtokernel"
There is a software test harness dubbed the "Femtokernel" that seeks to provide a unified interface and set of functions for developers to use when making software tests. This code is found in `./sw-tests/support`.

### Startup Procedure
The Femtokernel provides startup code that sets up the C runtime (set sp/gp, clear bss) and sets the interrupt enable bits in the `mie` register. The global interrupt enable is left unset, so that interrupts are not immediately occurring on entry.

`mtvec` is set up with a kernel-provided vector table (in vectored mode), consisting of `weak alias`es to a default handler that will print debug information. To define your own interrupt handler, simply define your own function with the same signature as those in `interrupt.h`, which will override the default definition. You may also override the `default_handler` if you require different debug information to be printed.

### Provided Features
APIs are provided in the `support/*.h` files. They are as follows:
- `riscv.h`
  - `void enter_user_mode()` - Core will return from this function in U-mode
  - `void interrupt_{enable, disable}()` - Sets/clears `mstatus.mie` bit
  - `uint32_t get_{mcause, mtval, mepc}` - Gets the respective CSR register value
- `interrupt.h` - handler definitions for override
  - `void __attribute__((interrupt)) exception_handler()`
  - `void __attribute__((interrupt)) default_handler()`
  - `void __attribute__((interrupt)) mswi_handler()`
  - `void __attribute__((interrupt)) mext_handler()`
- `format.h` - printf-like
  - `void format(const char *fmt, char *buf, ...)`
  - `void print(const char *fmt, ...)`
  - `void dprint(const char *fmt, ...)` - enabled with `DEBUG` flag
  - `void kprint(const char *fmt, ...)` - prepends `"[Kernel]"` to Femtokernel print statements
- `alloc.h` - heap allocation
  - `void *malloc(uint32_t sz)`
  - `void *calloc(uint32_t sz)`
  - `void free(void *ptr)`
- `pal.h` - Peripheral Abstraction Layer
  - `*_BASE` - base address for peripherals
  - `*RegBlk` - register block structs for peripherals
  - Useful macro defines for setting peripheral register bits
- `fpga.h` - FPGA testing functions
  - `void wait(int t)` - adds a delay, useful for output observation


### Ending Procedure
After the test, the kernel will check pass/fail and show the cycle/instruction count of the executed C-code.

### Femtokernel TODOs
If you want to contribute, here are a few things that need to be done:
- Better CMakeLists.txt. Currently very inflexible/hard-coded.
- Arguments to main
- Automatic Verilator coverage reporting: run all tests, report aggregate coverage results
- Automatic run script: 1 script to copy/run all tests, check for pass/fail
- More coverage of CPU features in `riscv.h`

### Building
The CMake file is set up to build each ".c" file in the folder as a separate test, linked to the Femtokernel binaries. To set it up (ensure you are using CMake 3):
```
mkdir build && cd build
cmake ..
make
```

This will create 3 files for each test: a `.elf` complied output, a `.bin` flat binary (for use with simulation), and a `.dump` file, which contains the result of running `riscv64-unknown-elf-objdump -d <name>.elf`, i.e. the (source-free) disassembly.

### CMake Options
The CMake file also provides build options that currently changes the behavior of print functions:
- `DEBUG` - enables `dprint` statements
- `SYNTHESIS` - enables all print routines (`print`, `kprint`, `dprint`) to print via bit-banged SPI over GPIO[3:1] to a 1602A-OLED module

To enable an option `OPT`, run `cmake -DOPT=1 ..` from the `build` directory. To disable an option, run `cmake -DOPT=0 ..`. Then run `make` to recompile the tests.