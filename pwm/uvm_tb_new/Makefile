TOPMOD = pwm_tb_top
TOP = $(TOPMOD).sv
TB = uvm_tb_new
SRC = ../soure/pwm_wrapper.sv
TESTNAME = multi_channel_config_test

# Path to bus_protocol_if source directory
BUS_PROTOCOL_IF_DIR=~/verif/bus-components/generic/bus_protocol_if

# pwm test configuration parameters
PERIOD = 10
DUTY = 5
EN = 1
POL = 0
ALIGN = 0
CHANNELS = 1

# Preprocessing for multiple PWM channels
preprocess:
	@echo "Preprocessing..."
	python3 preprocess_pwm_tb.py $(CHANNELS)
	@echo "Preprocessing finished."

build: preprocess
	vlog +incdir+../source+$(TB)+bus_agent+pwm_agent+$(BUS_PROTOCOL_IF_DIR) \
	+acc \
	+cover \
	-L $$QUESTA_HOME/uvm-1.2 ../source/pwm_wrapper.sv ../source/flex_counter.sv \
	$(BUS_PROTOCOL_IF_DIR)/bus_protocol_if.sv $(TOP) \
	-logfile tb_compile.log \
	-printinfilenames=file_search.log

run: build
	vsim -c $(TOPMOD) -L \
	$$QUESTA_HOME/uvm-1.2 \
	-voptargs=+acc \
	-coverage \
	+uvm_set_config_int=*,period,$(PERIOD) +uvm_set_config_int=*,duty,$(DUTY) \
	+uvm_set_config_int=*,enable,$(EN) +uvm_set_config_int=*,polarity,$(POL) +uvm_set_config_int=*,alignment,$(ALIGN) \
	+UVM_TESTNAME="$(TESTNAME)" \
	+UVM_VERBOSITY=UVM_LOW \
	-do "coverage save -onexit coverage.ucdb" -do "run -all"

run_gui: build
	vsim -i $(TOPMOD) -L \
	$$QUESTA_HOME/uvm-1.2 \
	-voptargs=+acc \
	-coverage \
	+uvm_set_config_int=*,period,$(PERIOD) +uvm_set_config_int=*,duty,$(DUTY) \
	+uvm_set_config_int=*,enable,$(EN) +uvm_set_config_int=*,polarity,$(POL) +uvm_set_config_int=*,alignment,$(ALIGN) \
	+UVM_TESTNAME="$(TESTNAME)" \
	+UVM_VERBOSITY=UVM_LOW \
	-do "do wave.do" -do "run -all"

clean: clean_preprocess
	rm -rf work
	rm -rf mitll90_Dec2019_all
	rm -rf covhtmlreport
	rm *.log
	rm transcript
	rm *.ucdb
	rm *.wlf
	rm *.vstf

clean_preprocess:
	python3 preprocess_pwm_tb.py 1

.phony: preprocess, build, run, run_gui, clean, clean_preprocess