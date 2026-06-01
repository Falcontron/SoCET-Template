interface uart_if(input logic clk, input logic nReset);
  logic rx;
  logic tx;
  modport master(output rx, input tx);
  modport slave(input rx, output tx);
endinterface