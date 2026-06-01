# rtl source directory (may need to add multiple, separate with '+' between directories)
SRCDIR=../bus_protocol_if
# src files (all in one line, separate with spaces, all on one line)
SRCFILES=../bus_protocol_if/bus_protocol_if.sv ff_ram.sv
# tb source directory
TBDIR=bus_agent
# name of top-level testbench module
TBTOP=top
# name of UVM test to be run
TESTNAME=write_test

build:
	vlog +incdir+$(SRCDIR)+$(TBDIR) \
	+acc \
	+cover \
	-L $$QUESTA_HOME/uvm-1.2 $(SRCFILES) $(TBTOP).sv \
	-logfile tb_compile.log \
	-printinfilenames=file_search.log

run: build
	vsim -c $(TBTOP) -L \
	$$QUESTA_HOME/uvm-1.2 \
	-voptargs=+acc \
	-coverage \
	+UVM_TESTNAME="$(TESTNAME)" \
	+UVM_VERBOSITY=UVM_LOW \
	-do "coverage save -onexit coverage.ucdb" -do "run -all"

run_gui: build
	vsim -i $(TBTOP) -L \
	$$QUESTA_HOME/uvm-1.2 \
	-voptargs=+acc \
	-coverage \
	+UVM_TESTNAME="$(TESTNAME)" \
	+UVM_VERBOSITY=UVM_LOW \
	-do "do wave.do" -do "run -all"

clean:
	rm -rf work
	rm -rf covhtmlreport
	rm *.log
	rm transcript
	rm *.ucdb
	rm *.wlf
	rm *.vstf

.phony: build, run, run_gui, clean