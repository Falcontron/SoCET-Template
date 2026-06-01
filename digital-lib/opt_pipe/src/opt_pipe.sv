module opt_pipe#(
    parameter int WIDTH,
    parameter int NUM_STAGES
) (
    input logic CLK,
    input logic nRST,
    input logic ready,
    input logic [WIDTH-1:0] in,
    output logic done,
    output logic [WIDTH-1:0] out
);
    generate
        if (NUM_STAGES == 0) begin
            assign done = ready;
            assign out = in;
        end else begin
            logic [NUM_STAGES-1:0] done_delay;
            logic [NUM_STAGES-1:0] [WIDTH-1:0] out_delay;

            assign done = done_delay[0];
            assign out = out_delay[0];

            always_ff @(posedge CLK, negedge nRST) begin
                if (!nRST) begin
                    done_delay <= '0;
                    out_delay <= '0;
                end else begin
                    done_delay <= {ready, done_delay[NUM_STAGES-1:1]};
                    out_delay <= {in, out_delay[NUM_STAGES-1:1]};
                end
            end
        end
    endgenerate
endmodule
