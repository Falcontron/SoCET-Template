CROSS := riscv64-unknown-elf-
CC := $(CROSS)gcc
CXX := $(CROSS)g++
CFLAGS := -march=rv32imc_zicsr_zifencei -mabi=ilp32 -mcmodel=medlow -static \
			-nostdlib -nostartfiles -ffreestanding -ffunction-sections -fdata-sections \
			-Wl,--gc-sections -Oz -g -Wall -Wextra -fstack-usage #-fPIC #-DDEBUG

# CC := clang
# CXX := clang++
# CFLAGS := --target=riscv32 -march=rv32imc_zicsr_zifencei -mabi=ilp32 -mcmodel=medlow -static \
# 			-nostdlib -ffreestanding -ffunction-sections -fdata-sections -Wl,--gc-sections -Oz -Wall -Wextra -flto \
# 			-stdlib=libstdc++ -cxx-isystem ~/riscv-gcc/riscv64-unknown-elf/include/c++/12.2.0 \
# 			-cxx-isystem ~/riscv-gcc/riscv64-unknown-elf/include/c++/12.2.0/riscv64-unknown-elf
# 			#-stdlib++-isystem ~/riscv-gcc/riscv64-unknown-elf/include/c++/12.2.0/riscv64-unknown-elf/

OBJCOPY := $(CROSS)objcopy
OBJCOPYFLAGS := -O binary
OBJDUMP := $(CROSS)objdump
OBJDUMPFLAGS := -d

CSRC := format.c util.c crc.c
CXXSRC := main.cc BufferedUART.cc Packet.cc PacketParser.cc Protocol.cc
ASMSRC := boot.S
TEST_ASMSRC := smile.S
OBJ := $(patsubst %.cc,%.o,$(CXXSRC))
OBJ += $(patsubst %.c,%.o,$(CSRC))
OBJ += $(patsubst %.S,%.o,$(ASMSRC))
TEST_OBJ := $(patsubst %.S,%.o,$(TEST_ASMSRC))
DUMP := boot.dump
TEST_DUMP := test.dump
ELF := boot.elf
TEST_ELF := test.elf
BIN := boot.bin
TEST_BIN := test.bin

UART_OBJ := uart_test.o BufferedUART.o boot.o format.o
UART_ELF := uart_test.elf
UART_BIN := uart_test.bin

#$(UART_BIN): $(UART_ELF)
#	$(OBJCOPY) $(OBJCOPYFLAGS) $^ $@
#
#$(UART_ELF): $(UART_OBJ)
#	$(CC) $(CFLAGS) $(LDFLAGS) -T link.ld $^ -o $@

all: $(BIN) $(DUMP)

$(DUMP): $(ELF)
	$(OBJDUMP) $(OBJDUMPFLAGS) $^ > $@

#$(TEST_DUMP): $(TEST_ELF)
#	$(OBJDUMP) $(OBJDUMPFLAGS) $^ > $@

$(BIN): $(ELF)
	$(OBJCOPY) $(OBJCOPYFLAGS) $^ $@

#$(TEST_BIN): $(TEST_ELF)
#	$(OBJCOPY) $(OBJCOPYFLAGS) $^ $@

$(ELF): $(OBJ)
	$(CXX) $(CFLAGS) $(LDFLAGS) -T link.ld $^ -o $@

$(TEST_ELF): $(TEST_OBJ)
	$(CXX) $(CFLAGS) $(LDFLAGS) -T link.ld $^ -o $@

%.o: %.c
	$(CXX) $(CFLAGS) -c $^ -o $@

%.o: %.cc
	$(CXX) $(CFLAGS) -c $^ -o $@

%.o: %.S
	$(CXX) $(CFLAGS) -c $^ -o $@

clean:
	rm -f $(OBJ)
	rm -f $(TEST_OBJ)
	rm -f $(ELF)
	rm -f $(TEST_ELF)
	rm -f $(BIN)
	rm -f $(TEST_BIN)
	rm -f $(DUMP)
	rm -f $(TEST_DUMP)
