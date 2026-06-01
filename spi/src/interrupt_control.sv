`include "spi_type_pkg.vh"

module interrupt_control
(
    input logic CLK, nRST,
    input logic transfer_complete, modf,
    input logic rx_water, tx_water, rx_full, tx_empty,
    input logic [5:0] interrupt_enable,
    input logic [5:0] clear,
    output logic [5:0] interrupts
);

    logic [5:0] interrupt_e, interrupt_flags, interrupt_n;
    logic [5:0] input_group;

    assign input_group = {transfer_complete, rx_water,
                          tx_water, rx_full, tx_empty, modf};

    assign interrupts = interrupt_flags;

    always_ff @(posedge CLK,negedge nRST) begin
        if(nRST == 0) begin
            interrupt_flags <= '0;
            interrupt_e <= '0;
        end else begin
            interrupt_flags <= interrupt_n;
            interrupt_e <= input_group;
        end
    end

    always_comb begin
        interrupt_n = interrupts;

        for(int i = 0; i < 6; i++) begin
            if(clear[i]) begin
                interrupt_n[i] = 1'b0;
            end else begin
                // Edge detection: either retain prior interrupt state, or if the status just updated from 0 -> 1, latch a new interrupt.
                interrupt_n[i] = interrupt_flags[i] | (~interrupt_e[i] & input_group[i]); 
            end
        end

        interrupt_n &= interrupt_enable;
    end


endmodule
