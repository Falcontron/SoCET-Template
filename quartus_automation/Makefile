.DEFAULT_GOAL="Please-specifiy-either-fpga_compile-fpga_program-or-fpga_flash"

fpga_compile:
	quartus_sh -t fpga_compile.tcl

fpga_program:
	quartus_sh -t fpga_program.tcl

fpga_flash: $(FPGA_MIF)
	make fpga_program
	quartus_stp -t fpga_flash.tcl
