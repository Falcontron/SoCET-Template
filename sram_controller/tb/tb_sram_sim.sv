`timescale 1ns / 100ps
module tb_sram_sim();
    parameter ADDR_WIDTH = 19; // for the memory chip
    parameter DATA_WIDTH = 16;
    logic tb_n_OE;
    logic tb_n_CE;
    logic tb_n_WE;
    logic tb_n_LB;
    logic tb_n_UB;
    logic [ADDR_WIDTH-1:0] tb_addr;
    wire [DATA_WIDTH-1:0] tb_data_wire;
    logic [DATA_WIDTH-1:0] tb_data;

    assign tb_data_wire = tb_data;


    sram_sim #(
        .MEMCHIP("IS61WV25616BLL-10TL"),
        .ADDR_WIDTH(19), // for the memory chip
        .DATA_WIDTH(16),
        .WIDTH(16),
        .NREGS(64)
    ) SRAM_CHIP (
        .n_OE(tb_n_OE),
        .n_CE(tb_n_CE),
        .n_WE(tb_n_WE),
        .n_LB(tb_n_LB),
        .n_UB(tb_n_UB),
        .addr(tb_addr),
        .DOUT(tb_data_wire)
    );

    initial begin
        tb_n_OE = 1'b1;
        tb_n_CE = 1'b1;
        tb_n_WE = 1'b1;
        tb_n_LB = 1'b1;
        tb_n_UB = 1'b1;
        tb_addr = '0;
        tb_data = 'z;

        //write data
        tb_addr = 19'hAA;
        tb_n_CE = 1'b0;
        tb_n_WE = 1'b0;
        tb_n_LB = 1'b0;
        tb_n_UB = 1'b0;
        #(5);
        tb_data = 16'hBB;

        #(30); // IDLE for a bit
        tb_addr = 19'h0;
        tb_n_CE = 1'b1;
        tb_n_WE = 1'b1;
        tb_n_LB = 1'b1;
        tb_n_UB = 1'b1;
        tb_data = 'z;

        #(20);
        //read data
        tb_addr = 19'hAA;
        tb_n_CE = 1'b0;
        tb_n_OE = 1'b0;
        #(30);
        tb_n_CE = 1'b1;
        tb_n_OE = 1'b1;
        #(20); //wait between test


        //write data
        tb_addr = 19'hFA;
        tb_n_CE = 1'b0;
        tb_n_WE = 1'b0;
        tb_n_LB = 1'b0;
        tb_n_UB = 1'b0;
        #(5);
        tb_data = 16'hDE;
        #(30); 
        // IDLE for a bit
        tb_addr = 19'h0;
        tb_n_CE = 1'b1;
        tb_n_WE = 1'b1;
        tb_n_LB = 1'b1;
        tb_n_UB = 1'b1;
        tb_data = 'z;

        #(20);
        //read data
        tb_addr = 19'hFA;
        tb_n_CE = 1'b0;
        tb_n_OE = 1'b0;

        #(30);





        //read data
        $finish();

        
    end

endmodule