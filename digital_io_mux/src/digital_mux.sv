// File name:   digital_mux.sv
// Created:     6/28/2022
// Author:      Ansh Patel
// Description: Digital Multiplexer

module digital_mux
#(
    //parameter NUM_PINS = 8;
    parameter NUM_FUNC = 2,
    parameter NUM_BITS = 2 //1
)
(
    input logic CLK,
    input logic RESETn,
    input logic [NUM_FUNC-1:0] output_enable,
    input logic [NUM_FUNC-1:0] from_module,
    input logic [NUM_BITS-1:0] fsel,
    input logic to_module_iopad,
    output logic from_module_ff,
    output logic output_en_ff,
    output logic [NUM_FUNC-1:0] to_module
);

    logic output_en_io;
    logic to_module_x;
    logic to_module_sync;
    logic from_module_io;

    always_ff @(posedge CLK,negedge RESETn) begin : SYNCHRONIZER
        if (!RESETn)
        begin
            to_module_x <= '0;
            to_module_sync <= '0;
            output_en_ff <= '0;
            from_module_ff <= '0;
        end
        else
        begin
            to_module_x <= to_module_iopad;
            to_module_sync <= to_module_x;
            output_en_ff <= output_en_io;
            from_module_ff <= from_module_io;
        end 
    end
 
    always_comb begin : SELECT_FUNCS
        to_module = '0;
        output_en_io = '0;
        from_module_io = '0;
        case (fsel)
        1'b0:
        begin
            output_en_io = output_enable[0];
            to_module[0] = to_module_sync;
            from_module_io = from_module[0];
        end
        1'b1:
        begin
            output_en_io = output_enable[1];
            to_module[1] = to_module_sync;
            from_module_io = from_module[1];
        end
        endcase
    end
endmodule