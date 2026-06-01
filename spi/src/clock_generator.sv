

module clock_generator #(parameter NUMBITS = 32)
(
    input logic CLK, nRST,
    input logic [NUMBITS-1:0] divider,
    input logic enable, polarity,
    output logic SCK
);

    logic [31:0] count,count_nxt;
    logic SCK_next;


    always_ff @ (posedge CLK, negedge nRST)
    begin
        if(!nRST) begin
            count <= '0;
            SCK <= '0;
        end else begin
            if(enable) begin
                count <= count_nxt;
                SCK <= SCK_next;
            end else begin
                count <= '0;
                SCK <= polarity;
            end
        end
    end

    always_comb
    begin
        if (count == divider)
        begin
            count_nxt = 0;
        end
        else
            count_nxt = count + 1;
    end
    assign SCK_next = (count == divider) ? ~SCK : SCK;

endmodule
