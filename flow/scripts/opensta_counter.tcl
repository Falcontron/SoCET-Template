# ============================================================
# opensta_counter.tcl
# ============================================================
#
# OpenSTA script for the template synthesis flow.
#
# Required environment variables:
#
#   STA_TOP
#   STA_LIBERTY
#   STA_NETLIST
#   STA_SDC
#   STA_TIMING_REPORT
#
# This script reads the mapped Verilog netlist from Yosys, applies the
# basic SDC constraints, and writes a timing report that GitHub Actions
# can upload as an artifact.
#
# ============================================================

proc require_env {name} {
    if {![info exists ::env($name)] || $::env($name) eq ""} {
        puts stderr "ERROR: required environment variable $name is not set"
        exit 1
    }
}

require_env STA_TOP
require_env STA_LIBERTY
require_env STA_NETLIST
require_env STA_SDC
require_env STA_TIMING_REPORT

set top_name      $::env(STA_TOP)
set liberty_file  $::env(STA_LIBERTY)
set netlist_file  $::env(STA_NETLIST)
set sdc_file      $::env(STA_SDC)
set timing_report $::env(STA_TIMING_REPORT)

puts "OpenSTA timing setup"
puts "  Top:      $top_name"
puts "  Liberty:  $liberty_file"
puts "  Netlist:  $netlist_file"
puts "  SDC:      $sdc_file"
puts "  Timing:   $timing_report"

read_liberty $liberty_file
read_verilog $netlist_file
link_design $top_name
read_sdc $sdc_file

check_setup

# ------------------------------------------------------------
# Timing report
# ------------------------------------------------------------
#
# Some OpenSTA builds do not support the Tcl command "redirect".
# Use OpenSTA's command-level file redirection instead:
#
#   command >  file
#   command >> file
#
# ------------------------------------------------------------

set timing_fp [open $timing_report "w"]
puts $timing_fp "OpenSTA timing report"
puts $timing_fp "====================="
puts $timing_fp ""
puts $timing_fp "Top module: $top_name"
puts $timing_fp "Liberty:    $liberty_file"
puts $timing_fp "Netlist:    $netlist_file"
puts $timing_fp "SDC:        $sdc_file"
puts $timing_fp ""
puts $timing_fp "Clock summary"
puts $timing_fp "-------------"
close $timing_fp

report_clock_properties >> $timing_report

set timing_fp [open $timing_report "a"]
puts $timing_fp ""
puts $timing_fp "Max-delay setup paths"
puts $timing_fp "---------------------"
close $timing_fp

report_checks -path_delay max -fields {slew cap input_pins nets fanout} -digits 4 >> $timing_report

set timing_fp [open $timing_report "a"]
puts $timing_fp ""
puts $timing_fp "Min-delay hold paths"
puts $timing_fp "--------------------"
close $timing_fp

report_checks -path_delay min -fields {slew cap input_pins nets fanout} -digits 4 >> $timing_report

set timing_fp [open $timing_report "a"]
puts $timing_fp ""
puts $timing_fp "Worst negative slack"
puts $timing_fp "--------------------"
close $timing_fp

report_wns >> $timing_report

set timing_fp [open $timing_report "a"]
puts $timing_fp ""
puts $timing_fp "Total negative slack"
puts $timing_fp "--------------------"
close $timing_fp

report_tns >> $timing_report

puts "OpenSTA timing report complete"