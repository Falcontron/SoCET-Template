all:
	riscv64-unknown-elf-gcc -Os -march=rv32imc_zicsr_zba_zbb_zbs -mabi=ilp32 -mcmodel=medany -static \
		-nostartfiles -nostdlib -Wl,--gc-sections -ffreestanding -ffunction-sections 		\
		-fdata-sections -fstack-usage -fno-tree-loop-distribute-patterns -flto -Tlink.ld	\
		-DFPGA *.c boot.S -o test.elf
	riscv64-unknown-elf-objcopy -O binary test.elf meminit.bin
	python3 ../../bin_to_mif.py
	# cp fpgainit.mif ../../build/socet_aft_aftx07_wrapper_0.2.0/fpga-quartus/

clean:
	rm -rf *.bin *.mif *.elf *.hex *.su
