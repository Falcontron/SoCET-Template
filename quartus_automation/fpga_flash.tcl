load_package jtag

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

# List all available programming hardware, and select the USB-Blaster.
# (Note: this example assumes only one USB-Blaster is connected.)
puts "Programming Hardware:"
foreach hardware_name [get_hardware_names] {
puts $hardware_name
if { [string match "USB-Blaster*" $hardware_name] } {
set usbblaster_name $hardware_name
}
}
puts "\nSelect JTAG chain connected to $usbblaster_name.\n";
# List all devices on the chain, and select the first device on the chain.
puts "\nDevices on the JTAG chain:"
foreach device_name [get_device_names -hardware_name $usbblaster_name] {
puts $device_name
if { [string match "@1*" $device_name] } {
set test_device $device_name
}
}
puts "\nSelect device: $test_device.\n";

begin_memory_edit -hardware_name "$usbblaster_name" -device_name "$test_device"

#writes to x8400
update_content_to_memory_from_file -instance_index 0 -mem_file_path "../../../fpgainit.mif" -mem_file_type mif

#writes t x8800
#update_content_to_memory_from_file -instance_index 100 -mem_file_path "../../../fpgainit.mif" -mem_file_type mif

end_memory_edit
