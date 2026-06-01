module fifo_new(DATAOUT, full, empty, clock, n_rst, wn, rn, DATAIN, clear);
  output logic [65:0] DATAOUT;
  output full, empty;
  input [65:0] DATAIN;
  input clock, n_rst, wn, rn, clear; // Need to understand what is wn and rn are for
  
  reg [2:0] wptr, rptr; // pointers tracking the stack
  reg [65:0] memory [7:0]; // the stack is 8 bit wide and 8 locations in size
  integer i;

  always @(posedge clock, negedge n_rst)
  begin
    if (n_rst == '0)
      begin
        for(i = 0; i < $size(memory); i++)
        begin
          memory[i] <= 0;
        end
        wptr <= 0;
        rptr <= 0;
      end
    else if (clear)
      begin
        for(i = 0; i < $size(memory); i++)
        begin
          memory[i] <= 0;
        end
        wptr <= 0;
        rptr <= 0;
      end
    else begin
      if (wn & !full)
        begin
          memory[wptr] <= DATAIN;
          wptr <= wptr + 1;
        end
      if (rn & !empty)
        begin
          rptr <= rptr + 1;
        end
    end
  end

  assign full = (((wptr+1) == rptr) ? 1 : 0 );
  assign empty = (wptr == rptr) ? 1 : 0;
  assign DATAOUT = memory[rptr];
  
endmodule