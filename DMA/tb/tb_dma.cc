// created by Yiyang Shui (ericshuisyy@gmail.com), 09/29/2022
// last modified: 10/12/2022

#include <iostream>
#include <string>

#include "verilated.h"
#include "verilated_fst_c.h"
#include "Vdma_wrapper.h"

#include "tb_dma.h"

const int CLK_PERIOD = 10;
const int BUS_DELAY = 800; // ps, Based on FF propagation delay

// Sizing related constants
const int DATA_WIDTH = 1;
const int ADDR_WIDTH = 32;
const int DATA_WIDTH_BITS = DATA_WIDTH * 8;
const int DATA_MAX_BIT = DATA_WIDTH_BITS - 1;
const int ADDR_MAX_BIT = ADDR_WIDTH - 1;

// Define our address mapping scheme via constants
const int ADDR_STATUS = 0;
const int ADDR_STATUS_BUSY = 0;
const int ADDR_STATUS_ERR = 1;
const int ADDR_RESULT = 2;
const int ADDR_SAMPLE = 4;
const int ADDR_COEF_START = 6; // F0
const int ADDR_COEF_SET = 14;  // Coeff Set Confirmation

const int IDLE = 0;
const int NON_SEQ = 0b10;
const int SEQ = 0b11;

const int SAR = 0x80050004; // Source Address Register
const int DAR = 0x80050008; // Destination Address Register
const int TSR = 0x8005000C; // Transfer Size Register
const int CR = 0x80050010;  // Control Register
const int SR = 0x80050014;  // Status Register

vluint64_t sim_time = 0;

std::string test_name;
int test_number;
int fail;
uint32_t test_data;

struct DMA_CR_CONFIG
{
    // Bit[0] : EN : should be set to start the transfer
    uint8_t EN = 0;
    // Bit[1] : TCIE : is the Transfer Complete Interrupt Enable
    uint8_t TCIE = 0;
    // Bit[2] : HTIE : is the Half Transfer Interrupt Enable
    uint8_t HTIE = 0;
    // Bit[4] : SRC : Is the source a peripheral or memory (0: Source is Memory, 1: Source is Peripheral)
    uint8_t SRC = 0;
    // Bit[5] : DST : Is the source a peripheral or memory (0: Source is Memory, 1: Source is Peripheral)
    uint8_t DST = 0;
    // Bit[6:7] : PSIZE : Peripheral Size (00: 8-bit, 01: 16-bit, 10: 32-bit)
    uint8_t PSIZE = 0;
    // Bit[8] : TE : DMA Trigger Enable
    uint8_t TE = 0;
    // Bit[10] : CIRC: Circular Mode
    uint8_t CIRC = 0;
    // Bit[11]: IDST: Increment destination address every read/write
    uint8_t IDST = 0;
    // Bit[12]: ISRC: Increment source address every read/write
    uint8_t ISRC = 0;
} configuration;

uint32_t DMA_CR_trans(DMA_CR_CONFIG config)
{
    uint32_t DMA_CR = config.EN | (config.TCIE << 1) | (config.HTIE << 2) | (config.SRC << 3) | (config.DST << 4) | (config.PSIZE << 5) | (config.TE << 8) | (config.CIRC << 10) | (config.IDST << 11) | (config.ISRC << 12);

    return DMA_CR;
}

void tick(Vdma_wrapper &dut, VerilatedFstC &trace)
{
    dut.CLK = 0;
    dut.eval();
    trace.dump(sim_time);
    sim_time++;

    dut.CLK = 1;
    dut.eval();
    trace.dump(sim_time);
    sim_time++;
}

void posedge(Vdma_wrapper &dut, VerilatedFstC &trace)
{
    if (dut.CLK == 0)
    {
        dut.CLK = 1;
        dut.eval();
        trace.dump(sim_time);
        sim_time++;
    }
    else
    {
        tick(dut, trace);
    }
}

void negedge(Vdma_wrapper &dut, VerilatedFstC &trace)
{
    if (dut.CLK == 1)
    {
        dut.CLK = 0;
        dut.eval();
        trace.dump(sim_time);
        sim_time++;
    }
    else
    {
        dut.CLK = 1;
        dut.eval();
        trace.dump(sim_time);
        sim_time++;

        dut.CLK = 0;
        dut.eval();
        trace.dump(sim_time);
        sim_time++;
    }
}

void reset(Vdma_wrapper &dut, VerilatedFstC &trace)
{
    dut.CLK = 0;
    dut.nRST = 1;

    tick(dut, trace);
    dut.nRST = 0;
    tick(dut, trace);
    dut.nRST = 1;
    tick(dut, trace);
}

void ahb_write(Vdma_wrapper &dut, VerilatedFstC &trace, uint32_t address, uint32_t data)
{
    // Provide Initial Data
    // dut.CLK = 0;
    // dut.eval();
    // trace.dump(sim_time);
    // sim_time++;
    tick(dut, trace);
    dut.SUB_HSEL = 1;
    dut.SUB_HTRANS = NON_SEQ;
    dut.SUB_HADDR = address;
    dut.SUB_HSIZE = 0;
    dut.SUB_HWRITE = 1;
    while (dut.SUB_HREADYOUT == 0)
    {
        tick(dut, trace);
    }
    tick(dut, trace);
    dut.SUB_HWDATA = data;
    dut.SUB_HTRANS = NON_SEQ; // was IDLE

    // Wait for hready to go high to proceed
    tick(dut, trace);
    while (dut.SUB_HREADYOUT == 0)
    {
        tick(dut, trace);
    }
    dut.SUB_HSEL = 0;
    dut.SUB_HWDATA = 0;
    dut.SUB_HADDR = 0;
    dut.SUB_HWRITE = 0;
}

void ahb_read(Vdma_wrapper &dut, VerilatedFstC &trace, uint32_t address, uint32_t expected_data)
{
    tick(dut, trace);
    dut.SUB_HSEL = 1;
    dut.SUB_HTRANS = NON_SEQ;
    dut.SUB_HADDR = address;
    dut.SUB_HSIZE = 0;
    dut.SUB_HWRITE = 0;
    while (dut.SUB_HREADYOUT == 0)
    {
        tick(dut, trace);
    }
    dut.SUB_HTRANS = NON_SEQ;

    while (dut.SUB_HREADYOUT == 0)
    {
        tick(dut, trace);
        printf("Time: %4d\n", sim_time);
    }
    // check output
    if (dut.SUB_HRDATA == expected_data)
    {
        printf("Time %4d [Correct]: At address %x, the SUB_HRDATA %x matches the expected value %x\n",
               sim_time, address, dut.SUB_HRDATA, expected_data);
    }
    else
    {
        printf("Time %4d [Incorrect]: At address %x, the SUB_HRDATA %x does NOT matches the expected value %x\n",
               sim_time, address, dut.SUB_HRDATA, expected_data);
    }
    tick(dut, trace);
    // finish write
    dut.SUB_HSEL = 0;
    dut.SUB_HTRANS = IDLE;
    dut.SUB_HADDR = 0;
    dut.SUB_HSIZE = 0;
    dut.SUB_HWRITE = 0;
}

// assume simple_memory has be configured in main
void simple_memory_write(Vdma_wrapper &dut, VerilatedFstC &trace, uint32_t addr, uint32_t wdata)
{
    tick(dut, trace);
    dut.MAN_HWRITE = 1;
    dut.MAN_HADDR = addr;
    dut.MAN_HWDATA = wdata;
    while (dut.mem_request_stall)
    {
        dut.MAN_HWRITE = 1;
        dut.MAN_HADDR = addr;
        dut.MAN_HWDATA = wdata;
        tick(dut, trace);
        dut.MAN_HWRITE = 1;
        dut.MAN_HADDR = addr;
        dut.MAN_HWDATA = wdata;
    }

    dut.MAN_HWRITE = 1;
    dut.MAN_HADDR = addr;
    dut.MAN_HWDATA = wdata;
    tick(dut, trace);

    dut.MAN_HWRITE = 0;
    dut.MAN_HADDR = 0;
    dut.MAN_HWDATA = 0;
    tick(dut, trace);
}

void wait_for_dma_interrupt(Vdma_wrapper &dut, VerilatedFstC &trace)
{
    while (!(dut.dma_interrupt == 1 && dut.MAN_HADDR == 0 && dut.MAN_HWDATA == 0 && dut.MAN_HRDATA == 0))
    {
        tick(dut, trace);
    }
    tick(dut, trace);
    ahb_read(dut, trace, SR, 0x1);
}

void wait_for_daq(Vdma_wrapper &dut, VerilatedFstC &trace)
{
    while (!(dut.daq == 1 && dut.MAN_HADDR == 0 && dut.MAN_HWDATA == 0 && dut.MAN_HRDATA == 0))
    {
        tick(dut, trace);
    }
    tick(dut, trace);
    // ahb_read(dut, trace, SR, 0x1);
}

int main(int argc, char **argv)
{
    // set up objects & configs
    Vdma_wrapper dut;
    VerilatedFstC m_trace;

    Verilated::traceEverOn(true);
    dut.trace(&m_trace, 5);
    m_trace.open("dma_trace.vcd");
    struct DMA_CR_CONFIG config;

    // set up tb variables, reset
    printf("\n ---\n TB start\n ---\n\n");
    printf("Initialization\n");
    test_number = 0;
    dut.SUB_HTRANS = NON_SEQ;
    dut.SUB_HWRITE = 0;
    dut.SUB_HADDR = 0;
    dut.SUB_HWDATA = 0;
    dut.SUB_HSIZE = 0;
    dut.SUB_HSEL = 0;
    dut.SUB_HBURST = 0;
    dut.MAN_HREADY = 1;
    dut.MAN_HRESP = 0;
    dut.MAN_HRDATA = 0;
    dut.latency = 2;
    dut.mem_strobe = 0xf;

    tick(dut, m_trace);

    printf("Reset Test\n");

    dut.nRST = 1;
    test_name = "Reset";
    dut.test_num = 0;
    fail = 0;

    reset(dut, m_trace);

    tick(dut, m_trace);
    printf("Prepping simple_memory\n");
    simple_memory_write(dut, m_trace, 0x14, 0x00001111);
    simple_memory_write(dut, m_trace, 0x18, 0x00002222);
    simple_memory_write(dut, m_trace, 0x1c, 0x00003333);

    // ------------------
    // test case 1.1
    // ------------------
    test_name = "Memory-to-Memory test case 1.1"; // one word transfer
    dut.test_num = 1;
    dut.test_case = 1;
    printf("%s\n", test_name.c_str());

    tick(dut, m_trace);

    simple_memory_write(dut, m_trace, 0x4, 0x11111111);
    simple_memory_write(dut, m_trace, 0x8, 0x22222222);

    // DMA setup
    ahb_write(dut, m_trace, SAR, 0x4);
    ahb_write(dut, m_trace, DAR, 0x12);
    ahb_write(dut, m_trace, TSR, 0x1);
    config.EN = 1;
    config.TCIE = 1;
    config.HTIE = 0;
    config.SRC = 0;
    config.DST = 0;
    config.PSIZE = 0;
    config.TE = 0;
    config.CIRC = 0;
    config.IDST = 0;
    config.ISRC = 0;

    ahb_write(dut, m_trace, CR, DMA_CR_trans(config));
    printf("DMA Now Enabled\n");

    // // memory start providing data
    // dut.MAN_HREADY = 1;
    // dut.MAN_HRESP = 0;
    // dut.MAN_HRDATA = 0x5678;
    // for (auto i = 0; i < 100; i++)
    // {
    //     tick(dut, m_trace);
    // }

    wait_for_dma_interrupt(dut, m_trace);

    // ------------------
    // test case 1.2
    // ------------------
    test_name = "Memory-to-Memory test case 1.2"; // 4 words, both source & destination incremental transfer
    dut.test_num = 1;
    dut.test_case = 2;
    printf("%s\n", test_name.c_str());

    reset(dut, m_trace);

    tick(dut, m_trace);

    simple_memory_write(dut, m_trace, 0x4, 0x11111111);
    simple_memory_write(dut, m_trace, 0x8, 0x22222222);
    simple_memory_write(dut, m_trace, 0xc, 0x33333333);
    simple_memory_write(dut, m_trace, 0x10, 0x44444444);

    // DMA setup
    ahb_write(dut, m_trace, SAR, 0x4);
    ahb_write(dut, m_trace, DAR, 0x20);
    ahb_write(dut, m_trace, TSR, 0x4);
    config.EN = 1;
    config.TCIE = 1;
    config.HTIE = 0;
    config.SRC = 0;
    config.DST = 0;
    config.PSIZE = 0b10;
    config.TE = 0;
    config.CIRC = 0;
    config.IDST = 1;
    config.ISRC = 1;

    ahb_write(dut, m_trace, CR, DMA_CR_trans(config));
    printf("DMA Now Enabled\n");

    wait_for_dma_interrupt(dut, m_trace);

    // ------------------
    // test case 1.3
    // ------------------
    test_name = "Memory-to-Memory test case 1.3"; // 8 words, both source & destination incremental transfer
    dut.test_num = 1;
    dut.test_case += 1;
    printf("%s\n", test_name.c_str());

    reset(dut, m_trace);

    tick(dut, m_trace);

    simple_memory_write(dut, m_trace, 0x4, 0x11111111);
    simple_memory_write(dut, m_trace, 0x8, 0x22222222);
    simple_memory_write(dut, m_trace, 0xc, 0x33333333);
    simple_memory_write(dut, m_trace, 0x10, 0x44444444);
    simple_memory_write(dut, m_trace, 0x14, 0x55555555);
    simple_memory_write(dut, m_trace, 0x18, 0x66666666);
    simple_memory_write(dut, m_trace, 0x1c, 0x77777777);
    simple_memory_write(dut, m_trace, 0x20, 0x88888888);
    simple_memory_write(dut, m_trace, 0x24, 0x99999999);
    simple_memory_write(dut, m_trace, 0x28, 0x19191919);

    // DMA setup
    ahb_write(dut, m_trace, SAR, 0x4);
    ahb_write(dut, m_trace, DAR, 0x30);
    ahb_write(dut, m_trace, TSR, 10);
    config.EN = 1;
    config.TCIE = 1;
    config.HTIE = 0;
    config.SRC = 0;
    config.DST = 0;
    config.PSIZE = 0b10;
    config.TE = 0;
    config.CIRC = 0;
    config.IDST = 1;
    config.ISRC = 1;

    ahb_write(dut, m_trace, CR, DMA_CR_trans(config));
    printf("DMA Now Enabled\n");

    wait_for_dma_interrupt(dut, m_trace);

    // ------------------
    // test case 1.4
    // ------------------
    test_name = "Memory-to-Memory test case 1.4"; // 4 words, fixed source, destination incremental transfer
    dut.test_num = 1;
    dut.test_case += 1;
    printf("%s\n", test_name.c_str());

    reset(dut, m_trace);

    tick(dut, m_trace);

    simple_memory_write(dut, m_trace, 0x4, 0x11111111);
    simple_memory_write(dut, m_trace, 0x8, 0x22222222);
    simple_memory_write(dut, m_trace, 0xc, 0x33333333);
    simple_memory_write(dut, m_trace, 0x10, 0x44444444);

    // DMA setup
    ahb_write(dut, m_trace, SAR, 0x4);
    ahb_write(dut, m_trace, DAR, 0x20);
    ahb_write(dut, m_trace, TSR, 4);
    config.EN = 1;
    config.TCIE = 1;
    config.HTIE = 0;
    config.SRC = 0;
    config.DST = 0;
    config.PSIZE = 0b10;
    config.TE = 0;
    config.CIRC = 0;
    config.IDST = 1;
    config.ISRC = 0;

    ahb_write(dut, m_trace, CR, DMA_CR_trans(config));
    printf("DMA Now Enabled\n");

    wait_for_dma_interrupt(dut, m_trace);

    // ------------------
    // test case 1.5
    // ------------------
    test_name = "Memory-to-Memory test case 1.5"; // 4 words, fixed destination, destination source transfer
    dut.test_num = 1;
    dut.test_case += 1;
    printf("%s\n", test_name.c_str());

    reset(dut, m_trace);

    tick(dut, m_trace);

    simple_memory_write(dut, m_trace, 0x4, 0x11111111);
    simple_memory_write(dut, m_trace, 0x8, 0x22222222);
    simple_memory_write(dut, m_trace, 0xc, 0x33333333);
    simple_memory_write(dut, m_trace, 0x10, 0x44444444);

    // DMA setup
    ahb_write(dut, m_trace, SAR, 0x4);
    ahb_write(dut, m_trace, DAR, 0x20);
    ahb_write(dut, m_trace, TSR, 0x8);
    config.EN = 1;
    config.TCIE = 1;
    config.HTIE = 0;
    config.SRC = 0;
    config.DST = 0;
    config.PSIZE = 0b10;
    config.TE = 0;
    config.CIRC = 0;
    config.IDST = 0;
    config.ISRC = 1;

    ahb_write(dut, m_trace, CR, DMA_CR_trans(config));
    printf("DMA Now Enabled\n");

    wait_for_dma_interrupt(dut, m_trace);

    // ------------------
    // test case 1.6
    // ------------------
    test_name = "Memory-to-Memory test case 1.6"; // 4 words, both source & destination incremental transfer
                                                  // In circular mode
    dut.test_num = 1;
    dut.test_case += 1;
    printf("%s\n", test_name.c_str());

    reset(dut, m_trace);

    tick(dut, m_trace);

    simple_memory_write(dut, m_trace, 0x4, 0x11111111);
    simple_memory_write(dut, m_trace, 0x8, 0x22222222);
    simple_memory_write(dut, m_trace, 0xc, 0x33333333);
    simple_memory_write(dut, m_trace, 0x10, 0x44444444);

    // DMA setup
    ahb_write(dut, m_trace, SAR, 0x4);
    ahb_write(dut, m_trace, DAR, 0x20);
    ahb_write(dut, m_trace, TSR, 0x4);
    config.EN = 1;
    config.TCIE = 1;
    config.HTIE = 0;
    config.SRC = 0;
    config.DST = 0;
    config.PSIZE = 0b10;
    config.TE = 0;
    config.CIRC = 1;
    config.IDST = 1;
    config.ISRC = 1;

    ahb_write(dut, m_trace, CR, DMA_CR_trans(config));
    printf("DMA Now Enabled\n");

    for (auto i = 0; i < 2; i++)
    {
        simple_memory_write(dut, m_trace, 0x4, i * 4 + 1);
        simple_memory_write(dut, m_trace, 0x8, i * 4 + 2);
        simple_memory_write(dut, m_trace, 0xc, i * 4 + 3);
        simple_memory_write(dut, m_trace, 0x10, i * 4 + 4);
    }
    // wait_for_dma_interrupt(dut, m_trace);
    for (auto i = 0; i < 400; i++)
    {
        tick(dut, m_trace);
    }

    // ------------------
    // test case 1.7
    // ------------------
    test_name = "Memory-to-Memory test case 1.7"; // 4 words, both source & destination incremental transfer
                                                  // In circular mode, core memory write inserted in the middle
    dut.test_num = 1;
    dut.test_case += 1;
    printf("%s\n", test_name.c_str());

    reset(dut, m_trace);

    tick(dut, m_trace);

    simple_memory_write(dut, m_trace, 0x4, 0x11111111);
    simple_memory_write(dut, m_trace, 0x8, 0x22222222);
    simple_memory_write(dut, m_trace, 0xc, 0x33333333);
    simple_memory_write(dut, m_trace, 0x10, 0x44444444);

    // DMA setup
    ahb_write(dut, m_trace, SAR, 0x4);
    ahb_write(dut, m_trace, DAR, 0x20);
    ahb_write(dut, m_trace, TSR, 0x4);
    config.EN = 1;
    config.TCIE = 1;
    config.HTIE = 0;
    config.SRC = 0;
    config.DST = 0;
    config.PSIZE = 0b10;
    config.TE = 0;
    config.CIRC = 1;
    config.IDST = 1;
    config.ISRC = 1;

    ahb_write(dut, m_trace, CR, DMA_CR_trans(config));
    printf("DMA Now Enabled\n");

    for (auto i = 0; i < 200; i++)
    {
        tick(dut, m_trace);
    }

    simple_memory_write(dut, m_trace, 0x4, 5);
    simple_memory_write(dut, m_trace, 0x8, 6);
    simple_memory_write(dut, m_trace, 0xc, 7);
    simple_memory_write(dut, m_trace, 0x10, 8);
    // wait_for_dma_interrupt(dut, m_trace);
    for (auto i = 0; i < 200; i++)
    {
        tick(dut, m_trace);
    }

    // Memory to Peripheral without trigger is operationally identical to memory to memory transfer

    // ------------------
    // test case 2.1
    // ------------------
    test_name = "Memory-to-Peripheral with Trigger test case 2.1"; // one word transfer
    dut.test_num = 2;
    dut.test_case = 1;
    printf("%s\n", test_name.c_str());

    reset(dut, m_trace);
    tick(dut, m_trace);

    simple_memory_write(dut, m_trace, 0x4, 0x11111111);
    simple_memory_write(dut, m_trace, 0x8, 0x22222222);

    // DMA setup
    ahb_write(dut, m_trace, SAR, 0x4);
    ahb_write(dut, m_trace, DAR, 0x12);
    ahb_write(dut, m_trace, TSR, 0x1);
    config.EN = 1;
    config.TCIE = 1;
    config.HTIE = 0;
    config.SRC = 0;
    config.DST = 0;
    config.PSIZE = 0;
    config.TE = 1;
    config.CIRC = 0;
    config.IDST = 0;
    config.ISRC = 0;

    ahb_write(dut, m_trace, CR, DMA_CR_trans(config));
    printf("DMA now enabled\n");
    tick(dut, m_trace);
    tick(dut, m_trace);
    tick(dut, m_trace);

    dut.drq = 1;
    printf("Peripheral data request sent\n");
    tick(dut, m_trace);

    wait_for_daq(dut, m_trace);

    // ------------------
    // test case 2.2
    // ------------------
    test_name = "Memory-to-Peripheral with Trigger test case 2.2"; // 4 words, both source & destination incremental transfer
    dut.test_num = 2;
    dut.test_case += 1;
    printf("%s\n", test_name.c_str());

    reset(dut, m_trace);
    tick(dut, m_trace);

    simple_memory_write(dut, m_trace, 0x4, 0x11111111);
    simple_memory_write(dut, m_trace, 0x8, 0x22222222);
    simple_memory_write(dut, m_trace, 0xc, 0x33333333);
    simple_memory_write(dut, m_trace, 0x10, 0x44444444);
    simple_memory_write(dut, m_trace, 0x14, 0x55555555);

    // DMA setup
    ahb_write(dut, m_trace, SAR, 0x4);
    ahb_write(dut, m_trace, DAR, 0x20);
    ahb_write(dut, m_trace, TSR, 0x4);
    config.EN = 1;
    config.TCIE = 1;
    config.HTIE = 0;
    config.SRC = 0;
    config.DST = 0;
    config.PSIZE = 0b10;
    config.TE = 1;
    config.CIRC = 0;
    config.IDST = 1;
    config.ISRC = 1;

    ahb_write(dut, m_trace, CR, DMA_CR_trans(config));
    printf("DMA now enabled\n");
    tick(dut, m_trace);
    tick(dut, m_trace);
    tick(dut, m_trace);

    dut.drq = 1;
    printf("Peripheral data request sent\n");
    tick(dut, m_trace);

    wait_for_daq(dut, m_trace);

    // ------------------
    // test case 2.3
    // ------------------
    test_name = "Memory-to-Peripheral with Trigger test case 2.3"; // 4 words, both source & destination incremental transfer
    dut.test_num = 2;
    dut.test_case += 1;
    printf("%s\n", test_name.c_str());

    reset(dut, m_trace);
    dut.drq = 0;
    tick(dut, m_trace);

    simple_memory_write(dut, m_trace, 0x4, 0x11111111);
    simple_memory_write(dut, m_trace, 0x8, 0x22222222);
    simple_memory_write(dut, m_trace, 0xc, 0x33333333);
    simple_memory_write(dut, m_trace, 0x10, 0x44444444);
    simple_memory_write(dut, m_trace, 0x14, 0x55555555);

    // DMA setup
    ahb_write(dut, m_trace, SAR, 0x4);
    ahb_write(dut, m_trace, DAR, 0x20);
    ahb_write(dut, m_trace, TSR, 0x2);
    config.EN = 1;
    config.TCIE = 1;
    config.HTIE = 0;
    config.SRC = 0;
    config.DST = 1;
    config.PSIZE = 0b10;
    config.TE = 1;
    config.CIRC = 0;
    config.IDST = 1;
    config.ISRC = 1;

    ahb_write(dut, m_trace, CR, DMA_CR_trans(config));
    printf("DMA now enabled\n");
    tick(dut, m_trace);
    tick(dut, m_trace);
    tick(dut, m_trace);

    dut.drq = 1;
    printf("Peripheral data request sent (1st)\n");
    tick(dut, m_trace);

    wait_for_daq(dut, m_trace);
    dut.drq = 0;
    tick(dut, m_trace);

    dut.drq = 1;
    printf("Peripheral data request sent (2nd)\n");
    tick(dut, m_trace);

    wait_for_daq(dut, m_trace);
    dut.drq = 0;
    tick(dut, m_trace);

    // TB ended
    printf("\n ---\n TB ended\n ---\n\n");

    for (auto i = 0; i < 5; i++)
    {
        tick(dut, m_trace);
    }

    m_trace.close();
    return (fail > 0);
}