

module sg
(
    input logic CLK, nRST,
    input logic enable, polarity,
    output logic tb_sck
);

    logic [3:0] cnt;

    always_ff @(posedge CLK, negedge nRST) begin
        if(!nRST) begin
            tb_sck <= polarity;
        end else begin
            if(enable) begin
                cnt <= cnt + 1;
            end else begin
                cnt <= '0;
            end

            if(enable && cnt == 4'hF) begin
                tb_sck <= ~tb_sck;
            end else if(enable) begin
                tb_sck <= tb_sck;
            end else begin
                tb_sck <= polarity;
            end
        end
    end

endmodule
