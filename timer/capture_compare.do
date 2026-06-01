onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {TB Signals}
add wave -noupdate /tb_capture_compare/tb_TCCMR_IND
add wave -noupdate /tb_capture_compare/tb_TCCR_IND
add wave -noupdate /tb_capture_compare/tb_test_case
add wave -noupdate /tb_capture_compare/tb_test_case_num
add wave -noupdate -divider {System Signals}
add wave -noupdate /tb_capture_compare/tb_clk
add wave -noupdate /tb_capture_compare/tb_n_rst
add wave -noupdate -divider {Input Signals}
add wave -noupdate /tb_capture_compare/busif/wen
add wave -noupdate /tb_capture_compare/busif/wdata
add wave -noupdate /tb_capture_compare/tb_t_in
add wave -noupdate /tb_capture_compare/tb_reg_select
add wave -noupdate /tb_capture_compare/tb_strobe_expanded
add wave -noupdate /tb_capture_compare/tb_tcr
add wave -noupdate -divider {Output Signals}
add wave -noupdate /tb_capture_compare/tb_tccmr
add wave -noupdate /tb_capture_compare/tb_tccr
add wave -noupdate /tb_capture_compare/tb_bus_read
add wave -noupdate /tb_capture_compare/tb_t_out
add wave -noupdate /tb_capture_compare/DUT/cc_intr
add wave -noupdate /tb_capture_compare/busif/error
add wave -noupdate /tb_capture_compare/DUT/cc_en
add wave -noupdate /tb_capture_compare/DUT/cc_intr_en
add wave -noupdate /tb_capture_compare/DUT/cc_polarity
add wave -noupdate /tb_capture_compare/DUT/cc_sel
add wave -noupdate /tb_capture_compare/DUT/cc_outmode
add wave -noupdate -divider {Counter Signals}
add wave -noupdate /tb_capture_compare/tb_tarr
add wave -noupdate /tb_capture_compare/tb_tpsc
add wave -noupdate -radix unsigned /tb_capture_compare/tb_tcnt
add wave -noupdate /tb_capture_compare/tb_nxt_tcnt
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {70059 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 232
configure wave -valuecolwidth 81
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {20285 ps} {244164 ps}
