`timescale 1ns / 10ps

module counter
#(
    parameter NUM_CNT_BITS = 8
)
(
    input wire clk,
    input wire n_rst,
    input wire clear,
    input wire count_enable,
    input wire [(NUM_CNT_BITS - 1):0] rollover_val,
    output reg [(NUM_CNT_BITS - 1):0] count_out,
    output reg rollover_flag
);

    reg [(NUM_CNT_BITS - 1):0] next_count;
    reg next_flag;

    always_ff @(posedge clk, negedge n_rst)
    begin
        if(n_rst == 1'b0) begin
            rollover_flag = 1'b0;
            count_out = '0;
        end
        else begin
            count_out = next_count;
            rollover_flag = next_flag;

        end
    end

    always_comb
    begin
        next_count = count_out; //default value

        if(clear == 1'b1) begin
            next_count = '0;
        end
        else if(count_enable == 1'b0) begin
            next_count = count_out;
        end
        else if(count_out == rollover_val) begin
            next_count = 1;
        end
        else begin
            next_count = count_out + 1;
        end
    end


    always_comb
    begin
        next_flag = rollover_flag; //default value

        if(clear == 1'b1) begin
            next_flag = 1'b0;
        end
        else if(count_enable == 1'b0) begin
            next_flag = rollover_flag;
        end
        else if(count_out == (rollover_val - 1)) begin
            next_flag = 1'b1;
        end
        else begin
            next_flag = 1'b0;
        end
    end


endmodule