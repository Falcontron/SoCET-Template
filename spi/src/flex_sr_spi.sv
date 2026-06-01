// $Id: $
// File name:   flex_pts_sr.sv
// Created:     1/28/2016
// Author:      Kuo Tian
// Lab Section: 337-04
// Version:     1.0  Initial Design Entry
// Description: parallel to serial shift register

module flex_sr_spi
#(
    NUM_BITS = 4
)
(
    input logic clk,
    input logic n_rst,
    //control	
    input logic shift_enable,
    input logic shift_clk,
    input logic shift_clear,
    input logic shift_msb,
    input logic load_enable,
    input logic mode,

    //data
    input logic serial_in,
    input logic [(NUM_BITS - 1):0] parallel_in,

    output logic [(NUM_BITS - 1):0] parallel_out,
    output logic serial_out
);
    logic [(NUM_BITS - 1):0] nstate;
    logic [(NUM_BITS - 1):0] cstate;

    assign parallel_out = cstate;
    assign serial_out = shift_msb == 1 ? cstate[(NUM_BITS-1)]:cstate[0];

    always_ff @ (posedge clk, negedge n_rst)
    begin
        if( n_rst == 0)
        begin
            cstate <= '0;
        end
        else
        begin
            cstate <= nstate;
        end        
    end

    always_comb
    begin   
        nstate = cstate;
        if(load_enable)
            nstate = parallel_in;
        else if (shift_clear)
            nstate = '0;
        else
        begin
            if(shift_enable & shift_clk)
            begin
                if (shift_msb)
                begin
                    if (mode)
                        nstate = {cstate[NUM_BITS-2:0], 1'b0}; 
                    else
                        nstate = {cstate[NUM_BITS-2:0], serial_in};  
                end
                else
                begin
                    if (mode)
                        nstate = { 1'b0, cstate[NUM_BITS-1:1]};
                    else
                        nstate = { serial_in, cstate[NUM_BITS-1:1]};
                end
            end
            else
                nstate = cstate;
        end
    end

endmodule

