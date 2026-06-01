onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_time_base/tb_test_case
add wave -noupdate -radix decimal /tb_time_base/tb_test_case_num
add wave -noupdate -divider {System Signals}
add wave -noupdate /tb_time_base/tb_clk
add wave -noupdate /tb_time_base/tb_n_rst
add wave -noupdate -divider Inputs
add wave -noupdate /tb_time_base/tb_tc_en
add wave -noupdate /tb_time_base/tb_tc_rst
add wave -noupdate /tb_time_base/tb_tarr
add wave -noupdate /tb_time_base/tb_tpsc
add wave -noupdate -divider Outputs
add wave -noupdate -expand -group nxt_tcnt -radix unsigned /tb_time_base/tb_nxt_tcnt
add wave -noupdate -expand -group nxt_tcnt /tb_time_base/tb_expected_nxt_tcnt
add wave -noupdate -expand -group tcnt -radix unsigned /tb_time_base/tb_tcnt
add wave -noupdate -expand -group tcnt /tb_time_base/tb_expected_tcnt
add wave -noupdate /tb_time_base/tb_check
add wave -noupdate /tb_time_base/tb_mismatch
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {5247893 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 262
configure wave -valuecolwidth 100
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
configure wave -timelineunits ps
update
WaveRestoreZoom {5211648 ps} {5493937 ps}
