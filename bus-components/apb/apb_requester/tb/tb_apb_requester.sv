
`ifdef VERILATOR
module tb_apb_requester(input CLK);
`else
module tb_apb_requester();
    
    logic CLK = 0;

    always #(10) CLK++;
`endif
    
    logic nRST;

    bus_protocol_if rq();
    bus_protocol_if protif();
    apb_if apbif(CLK, nRST);

    apb_requester DUT(
        .busif(rq),
        .apbif
    );

    apb_completer #(.BASE_ADDR(0), .NWORDS(32)) APB_MEM(
        .apbif,
        .protif
    );

    simple_memory MEM(
        .CLK,
        .latency(2),
        .prif(protif),
        .hintif(protif)
    );

    task reset();
        nRST = 1;
        @(negedge CLK);
        nRST = 0;
        repeat(2) @(negedge CLK);
        nRST = 1;
    endtask
    
    task reset_inputs();
        rq.wen = 0;
        rq.ren = 0;
        rq.strobe = 0;
        rq.addr = 0;
        rq.wdata = 0;
    endtask

    task write(input [31:0] addr, input [31:0] value);
        rq.wen = 1;
        rq.ren = 0;
        rq.strobe = 4'hF;
        rq.addr = addr;
        rq.wdata = value;
        while(rq.request_stall) begin
            @(posedge CLK);

            // In verilator, this #1 breaks TB. Sampling time issue.
            // TODO: See if use of clocking blocks fixes this
`ifndef VERILATOR 
            #(1);
`endif
        end
        reset_inputs();
        @(posedge CLK); // addr phase
        @(posedge CLK); // data phase
`ifndef VERILATOR
        #(1);
`endif
    endtask


    initial begin
        reset_inputs();
        reset();

        write(0, 32'hDEAD);
        write(4, 32'hBEEF);
        write(8, 32'hCAFE);

        $finish();
    end

endmodule
