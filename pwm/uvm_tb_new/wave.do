onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -expand -group {Clock and Reset} /pwm_tb_top/b_if/clk
add wave -noupdate -expand -group {Clock and Reset} /pwm_tb_top/b_if/n_rst
add wave -noupdate -expand -group {Bus Input} -color Orange /pwm_tb_top/b_if/b_p_if/wen
add wave -noupdate -expand -group {Bus Input} -color Orange /pwm_tb_top/b_if/b_p_if/ren
add wave -noupdate -expand -group {Bus Input} -color Orange /pwm_tb_top/b_if/b_p_if/addr
add wave -noupdate -expand -group {Bus Input} -color Orange /pwm_tb_top/b_if/b_p_if/strobe
add wave -noupdate -expand -group {Bus Input} -color Orange /pwm_tb_top/b_if/b_p_if/wdata
add wave -noupdate -expand -group {PWM Output} -color Turquoise -subitemconfig {{/pwm_tb_top/p_if/pwm_out[1]} {-color Turquoise} {/pwm_tb_top/p_if/pwm_out[0]} {-color Turquoise}} /pwm_tb_top/p_if/pwm_out
add wave -noupdate -expand -group {Bus Output} -color {Blue Violet} /pwm_tb_top/b_if/b_p_if/rdata
add wave -noupdate -expand -group {Bus Output} -color {Blue Violet} /pwm_tb_top/b_if/b_p_if/error
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {2335 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
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
WaveRestoreZoom {2051 ns} {2558 ns}
