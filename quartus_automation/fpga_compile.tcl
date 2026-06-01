load_package flow

set wrapper_name "fpga-quartus/socet_aft_aftx07_wrapper_0_2_0.qpf"
set wrapper_done_file "fpga-quartus/socet_aft_aftx07_wrapper_0_2_0.done"

set base_name "fpga-quartus/socet_aft_aftx07_2_0_0.qpf"
set base_done_file "fpga-quartus/socet_aft_aftx07_2_0_0.done"

if {[file exists $wrapper_done_file] || [file exists $base_done_file]} {
  puts "Project previously compiled"
  puts "See fpga_quartus/*.done for completion date"
  exit 0
}

if {[file exists $wrapper_name]} {
  project_open $wrapper_name
} elseif {[file exists $base_name]} {
  project_open $base_name
} else {
  puts ".qpf file not found"
  exit 1
}

# Should Look at breaking in this into subcommands to avoid unneeded compilation steps (i.e. timing analysis)
execute_flow -compile

project_close
