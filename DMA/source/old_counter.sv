import cpu_types_pkg::*;

module counter #(parameter WIDTH = 8)
(
    input logic CLK,
    input logic nRST,
    input logic count_enable,
    input logic clear,
    input logic rollover_val,
    output logic [WIDTH-1:0] count_out,
    output logic rollover_flag
);

logic [WIDTH-1:0] count;
logic [WIDTH-1:0] nxt_count;
logic nxt_flag;

always_ff @ (posedge CLK, negedge nRST) 
begin
   if(nRST == 1'b0) begin
      count <= 'h0;
   end
   else begin
      if(clear == 1'b1) begin
         count <= 'h0;
      end
      else if(count_enable == 1'b1) begin
         count <= nxt_count;
      end
   end
end


assign nxt_count = (rollover_val == count ? 'h1 : (counter + 'h1));

assign rollover_flag = (count == rollover_val);
assign count_out = counter;

endmodule