load_package flow

set wrapper_name "fpga-quartus/socet_aft_aftx07_wrapper_0_2_0.qpf"
set base_name "fpga-quartus/socet_aft_aftx07_2_0_0.qpf"

if {[file exists $wrapper_name]} {
  project_open $wrapper_name
} elseif {[file exists $base_name]} {
  project_open $base_name
} else {
  puts ".qpf file not found"
  exit 1
}

#TBD: make this a script for quartus_stp so that jtag packages can be used to allow for more versatility 
qexec "quartus_pgm -c USB-blaster -m jtag -o \"p;./socet_aft_aftx07_wrapper_0_2_0.sof\""

project_close
