// File name:   gpio.sv
// Created:     10/23/2014
// Author:      John Skubic
// Version:     1.0
// Description: GPIO pins
//


module gpio #(
    parameter int NUM_PINS = 8  //MAX 32
) (
    input CLK,
    input nRST,

    //APB_Slave Interface
    bus_protocol_if.peripheral_vital busif,
    // Note: This module does not require hints

    //Gpio Interface
    gpio_if.gpio gpioif

);


`ifdef VERILATOR
    localparam int BUS_DATA_WIDTH = busif.DATA_WIDTH;
    localparam int INTERFACE_PINS = gpioif.NUM_PINS;
`else  // VERILATOR
    localparam int BUS_DATA_WIDTH = $bits(busif.rdata);
    localparam int INTERFACE_PINS = $bits(gpioif.out_data);
`endif  // VERILATOR-else

`ifndef SYNTHESIS
    if (NUM_PINS > BUS_DATA_WIDTH) begin : gen_check_width
        $error(
            "gpio: NUM_PINS must be <= bus DATA_WIDTH\n\tNUM_PINS=%0d\n\tDATA_WIDTH=%0d",
            NUM_PINS,
            busif.DATA_WIDTH
        );
    end

    if (NUM_PINS < 1 || NUM_PINS > 32) begin : gen_check_pin_count
        $error(
            "gpio: NUM_PINS must satisfy 1 <= NUM_PINS <= 32\n\tNUM_PINS=%0d", NUM_PINS
        );
    end

    if (NUM_PINS != INTERFACE_PINS) begin : gen_check_interface
        $error(
            {
                "gpio: Inconsistent NUM_PINS values for gpio and gpio_if!\n",
                "\tgpio.NUM_PINS=%0d\n\tgpioif.NUM_PINS=%0d"
            },
            NUM_PINS,
            gpioif.NUM_PINS
        );
    end

`endif  // SYNTHESIS

    //GPIO Register indicies
    localparam int DATA_IND = 0;  //32'hXXXXX000
    localparam int EN_IND = 1;  //32'hXXXXX004
    localparam int INTR_EN_IND = 2;  //32'hXXXXX008
    localparam int INTR_POSEDGE_IND = 3;  //32'hXXXXX00C
    localparam int INTR_NEGEDGE_IND = 4;  //32'hXXXXX010
    localparam int INTR_CLR_IND = 5;  //32'hXXXXX014
    localparam int INTR_STAT_IND = 6;  //32'hXXXXX018
    localparam int NUM_REGISTERS = 7;

    genvar i;

    // each register's write enable and regs
    logic [NUM_REGISTERS - 1 : 0][NUM_PINS - 1 : 0] registers;

    // bus information
    logic [NUM_REGISTERS - 1 : 0][31:0] bus_read;
    logic [NUM_REGISTERS - 1:0] reg_select;
    logic [NUM_PINS - 1 : 0] read_r;
    logic [31:0] strobe_expanded;  // 32b since max pins are 32

    //edge detection vars
    logic [NUM_PINS - 1 : 0] pos_edge;
    logic [NUM_PINS - 1 : 0] neg_edge;
    logic [NUM_PINS - 1 : 0] gen_intr;

    //assign output
    assign gpioif.oe_data = registers[EN_IND];
    assign gpioif.out_data = registers[DATA_IND];
    assign gpioif.irq = registers[INTR_STAT_IND];

    assign reg_select = 1 << (busif.addr >> 2);  // Offset addr in multiples of 4
    assign busif.rdata = bus_read[(busif.addr>>2)];
    assign busif.request_stall = 0;
    assign busif.error = 0;

    generate
        for (i = 0; i < 4; i++) begin : gen_strobe
            if (i < BUS_DATA_WIDTH / 8) begin : gen_strobe_data
                assign strobe_expanded[8*i+:8] = {8{busif.strobe[i]}};
            end else begin : gen_strobe_padding
                assign strobe_expanded[8*i+:8] = 8'h00;
            end
        end
    endgenerate

    // edge detector for interrupt generation
    socetlib_edge_detector #(
        .WIDTH(NUM_PINS)
    ) edgd (
        .CLK(CLK),
        .nRST(nRST),
        .signal(gpioif.in_data),
        .pos_edge(pos_edge),
        .neg_edge(neg_edge)
    );



    // read logic
    always_ff @(posedge CLK, negedge nRST) begin
        if (~nRST) read_r <= '0;
        else read_r <= gpioif.in_data;
    end

    //---------------------------------------//
    // Writing to registers
    //---------------------------------------//
    generate
        for (i = 0; i < NUM_REGISTERS; i++) begin : gen_write_regs
            if ((i != INTR_STAT_IND) && (i != INTR_CLR_IND)) begin : gen_exclude_intr
                always_ff @(posedge CLK, negedge nRST) begin
                    if (~nRST) begin
                        registers[i] <= '0;
                    end else if (reg_select[i] && busif.wen) begin
                        registers[i] <= (busif.wdata[NUM_PINS-1 : 0]
                                            & strobe_expanded[NUM_PINS-1 : 0]);
                    end
                end
            end
        end
    endgenerate

    //---------------------------------------//
    // Formation of read data
    //---------------------------------------//
    generate
        for (i = 0; i < NUM_REGISTERS; i++) begin : gen_rdata
            //set unused bits to 0
            if (NUM_PINS < 32) assign bus_read[i][31 : NUM_PINS] = '0;

            //if trying to access data reg, return the read register data
            if (i == DATA_IND) assign bus_read[i][NUM_PINS-1 : 0] = read_r;
            else assign bus_read[i][NUM_PINS-1 : 0] = registers[i];
        end
    endgenerate

    //--------------------------------------//
    // Interrupt functionality
    //--------------------------------------//
    assign gen_intr = ((registers[INTR_POSEDGE_IND] & pos_edge)
                      | (registers[INTR_NEGEDGE_IND] & neg_edge))
                      & registers[INTR_EN_IND];

    always_ff @(posedge CLK, negedge nRST) begin
        if (~nRST) begin
            registers[INTR_STAT_IND] <= '0;
        end else begin
            registers[INTR_STAT_IND] <= (registers[INTR_STAT_IND] & ~registers[INTR_CLR_IND])
                                            | gen_intr;
        end
    end

    // immediately clear the clear register unless the register is being written to
    always_ff @(posedge CLK, negedge nRST) begin
        if (~nRST) begin
            registers[INTR_CLR_IND] <= '0;
        end else if (reg_select[INTR_CLR_IND] && busif.wen) begin
            registers[INTR_CLR_IND] <= (busif.wdata[NUM_PINS-1:0] & strobe_expanded[NUM_PINS-1:0]);
        end else begin
            registers[INTR_CLR_IND] <= '0;
        end
    end


endmodule
