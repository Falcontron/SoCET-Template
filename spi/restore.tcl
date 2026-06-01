
# NC-Sim Command File
# TOOL:	ncsim(64)	15.20-s030
#
#
# You can restore this configuration with:
#
#      irun -access +rwc +nctimescale+1ns/1ps -incdir ./include src/APB_SlaveInterface.sv src/clock_divider.sv src/clock_generator.sv src/controller.sv src/counters.sv src/edge_detect_spi.sv src/fifo.sv src/flex_counter_spi.sv src/flex_sr_spi.sv src/interrupt_control.sv src/sg.sv src/spi.sv src/sync_high.sv tb/tb_spi.sv -input restore.tcl
#

set tcl_prompt1 {puts -nonewline "ncsim> "}
set tcl_prompt2 {puts -nonewline "> "}
set vlog_format %h
set vhdl_format %v
set real_precision 6
set display_unit auto
set time_unit module
set heap_garbage_size -200
set heap_garbage_time 0
set assert_report_level note
set assert_stop_level error
set autoscope yes
set assert_1164_warnings yes
set pack_assert_off {}
set severity_pack_assert_off {note warning}
set assert_output_stop_level failed
set tcl_debug_level 0
set relax_path_name 1
set vhdl_vcdmap XX01ZX01X
set intovf_severity_level ERROR
set probe_screen_format 0
set rangecnst_severity_level ERROR
set textio_severity_level ERROR
set vital_timing_checks_on 1
set vlog_code_show_force 0
set assert_count_attempts 1
set tcl_all64 false
set tcl_runerror_exit false
set assert_report_incompletes 0
set show_force 1
set force_reset_by_reinvoke 0
set tcl_relaxed_literal 0
set probe_exclude_patterns {}
set probe_packed_limit 4k
set probe_unpacked_limit 16k
set assert_internal_msg no
set svseed 1
set assert_reporting_mode 0
alias . run
alias iprof profile
alias quit exit
database -open -shm -into waves.shm waves -default
probe -create -database waves tb_spi.DUT.CLK tb_spi.DUT.nRST tb_spi.test_block tb_spi.test_num tb_spi.tb_enable tb_spi.tb_polarity tb_spi.spiif.spi.SS_OUT tb_spi.spiif.spi.MISO_IN tb_spi.spiif.spi.MOSI_OUT tb_spi.spiif.spi.SCK_OUT tb_spi.spiif.spi.SS_IN tb_spi.spiif.spi.MISO_OUT tb_spi.spiif.spi.MOSI_IN tb_spi.spiif.spi.SCK_IN tb_spi.spiif.spi.interrupts tb_spi.spiif.spi.mode tb_spi.DUT.EN tb_spi.DUT.SR.cstate tb_spi.DUT.control_reg tb_spi.DUT.status_reg tb_spi.DUT.byte_length_reg tb_spi.DUT.baud_rate_reg tb_spi.DUT.CTRL.op_complete tb_spi.DUT.CTRL.TX_REN tb_spi.DUT.CTRL.RX_WEN tb_spi.DUT.CTRL.counter_en tb_spi.DUT.CTRL.counter_rst tb_spi.DUT.CTRL.shifter_en tb_spi.DUT.CTRL.shifter_load tb_spi.DUT.CTRL.shifter_rst tb_spi.DUT.CTRL.state tb_spi.DUT.CTRL.state_n tb_spi.DUT.CG.count tb_spi.DUT.CG.count_nxt tb_spi.DUT.CG.divider tb_spi.DUT.FIFO_TX.regs tb_spi.DUT.FIFO_TX.rd_ptr tb_spi.DUT.FIFO_TX.wr_ptr tb_spi.DUT.FIFO_TX.numdata tb_spi.apbif.apb_s.PADDR tb_spi.apbif.apb_s.PENABLE tb_spi.apbif.apb_s.PRDATA tb_spi.apbif.apb_s.PSEL tb_spi.apbif.apb_s.PWDATA tb_spi.apbif.apb_s.PWRITE tb_spi.DUT.FIFO_RX.regs

simvision -input restore.tcl.svcf
