onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {TEST SIGNALS}
add wave -noupdate /tb_timer/tb_test_case
add wave -noupdate -radix unsigned /tb_timer/tb_test_case_num
add wave -noupdate -divider {System Signals}
add wave -noupdate /tb_timer/tb_clk
add wave -noupdate /tb_timer/tb_n_rst
add wave -noupdate -divider {BUS IN}
add wave -noupdate /tb_timer/tb_busif/wen
add wave -noupdate /tb_timer/tb_busif/ren
add wave -noupdate -radix hexadecimal /tb_timer/tb_busif/addr
add wave -noupdate /tb_timer/tb_busif/strobe
add wave -noupdate /tb_timer/tb_busif/wdata
add wave -noupdate -divider {BUS OUT}
add wave -noupdate /tb_timer/tb_busif/rdata
add wave -noupdate /tb_timer/tb_busif/error
add wave -noupdate /tb_timer/tb_busif/request_stall
add wave -noupdate -divider {Check Output Signals}
add wave -noupdate /tb_timer/tb_check
add wave -noupdate /tb_timer/tb_mismatch
add wave -noupdate -divider {Timer In & Out}
add wave -noupdate /tb_timer/tb_t_in
add wave -noupdate /tb_timer/tb_t_out
add wave -noupdate /tb_timer/timerif/t_irq
add wave -noupdate /tb_timer/timerif/tc_irq
add wave -noupdate -divider {Timer Registers}
add wave -noupdate /tb_timer/DUT/tccmr
add wave -noupdate /tb_timer/DUT/tccr
add wave -noupdate /tb_timer/DUT/tcnt
add wave -noupdate /tb_timer/DUT/nxt_tcnt
add wave -noupdate /tb_timer/DUT/tcr
add wave -noupdate /tb_timer/DUT/nxt_tcr
add wave -noupdate /tb_timer/DUT/tpsc
add wave -noupdate /tb_timer/DUT/nxt_tpsc
add wave -noupdate /tb_timer/DUT/tarr
add wave -noupdate /tb_timer/DUT/nxt_tarr
add wave -noupdate -divider {Timer Bus Data}
add wave -noupdate /tb_timer/DUT/bus_read
add wave -noupdate /tb_timer/DUT/reg_select
add wave -noupdate /tb_timer/DUT/strobe_expanded
add wave -noupdate /tb_timer/DUT/error
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {26216 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 182
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
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ps} {248832 ps}
