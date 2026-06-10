# ============================================================
# counter.sdc
# ============================================================
#
# Basic timing constraints for the template counter design.
#
# This file is intentionally simple. It gives OpenSTA enough timing
# information to produce a useful CI timing report for the small example
# design in rtl/counter.sv.
#
# Assumptions:
#
#   * clk is the only clock.
#   * clk has a 10 ns period, equivalent to 100 MHz.
#   * output ports are required 1 ns before the next active clock edge.
#   * reset is asynchronous and is excluded from normal timing analysis.
#
# Notes:
#
#   This counter example only has clk, rst_n, and output ports. There are
#   no normal synchronous data inputs besides reset, so this file does not
#   apply a generic set_input_delay constraint.
#
#   Future repos with real input ports should add project-specific
#   set_input_delay constraints for those ports.
#
#   Avoid using remove_from_collection here because some OpenSTA builds
#   do not support that command.
#
# ============================================================

create_clock -name clk -period 10.000 [get_ports clk]

set_output_delay 1.000 -clock clk [all_outputs]

set_false_path -from [get_ports rst_n]