// created by Yiyang Shui (ericshuisyy@gmail.com), 09/29/2022
// last modified: 10/12/2022

#include <iostream>
#include <string>

#include "verilated.h"
#include "verilated_fst_c.h"
#include "Vdma_wrapper.h"

#include "tb_dma.h"

const int CLK_PERIOD = 10;
const int BUS_DELAY  = 800; // ps, Based on FF propagation delay

// Sizing related constants
const int DATA_WIDTH      = 1;
const int ADDR_WIDTH      = 32;
const int DATA_WIDTH_BITS = DATA_WIDTH * 8;
const int DATA_MAX_BIT    = DATA_WIDTH_BITS - 1;
const int ADDR_MAX_BIT    = ADDR_WIDTH - 1;

// Define our address mapping scheme via constants
const int ADDR_STATUS      = 0;
const int ADDR_STATUS_BUSY = 0;
const int ADDR_STATUS_ERR  = 1;
const int ADDR_RESULT      = 2;
const int ADDR_SAMPLE      = 4;
const int ADDR_COEF_START  = 6;  // F0
const int ADDR_COEF_SET    = 14; // Coeff Set Confirmation

const int IDLE = 0;
const int NON_SEQ = 0b10;
const int SEQ = 0b11;

const int SAR = 0x7FFF0004; //Source Address Register
const int DAR = 0x7FFF0008; //Destination Address Register
const int TSR = 0x7FFF000C; //Transfer Size Register
const int CR = 0x7FFF0010; //Control Register

vluint64_t sim_time = 0;

std::string test_name;
int test_number;
int fail;
uint32_t test_data;

struct DMA_CR_CONFIG{
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
    uint32_t DMA_CR = config.EN | (config.TCIE << 1) | (config.HTIE << 2) | (config.SRC << 3) 
                        | (config.DST << 4) | (config.PSIZE << 5) | (config.TE << 7) | (config.CIRC << 8)
                        | (config.CIRC << 10) | (config.IDST << 11) | (config.ISRC << 12);

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
    while (dut.SUB_HREADY == 0)
    {
        tick(dut, trace);
        printf("Time: %4d\n", sim_time);
    }
    tick(dut, trace);
    dut.SUB_HWDATA = data;
    dut.SUB_HTRANS = IDLE;

    // Wait for hready to go high to proceed
    tick(dut, trace);
    while (dut.SUB_HREADY == 0)
    {
        tick(dut, trace);
        printf("Time: %4d\n", sim_time);
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
    while (dut.SUB_HREADY == 0)
    {
        tick(dut, trace);
    }
    tick(dut, trace);
    dut.SUB_HTRANS = IDLE;

    while(dut.SUB_HREADY == 0)
    {
        if(dut.SUB_HRDATA == expected_data)
        {
            printf("Time %4d [Correct]: At address %x, the SUB_HRDATA %x matches the expected value %x\n", 
                sim_time, address, dut.SUB_HRDATA, expected_data);
        } else
        {
            printf("Time %4d [Incorrect]: At address %x, the SUB_HRDATA %x does NOT matches the expected value %x\n",
                sim_time, address, dut.SUB_HRDATA, expected_data);
        }
        tick(dut, trace);
        printf("Time: %4d\n", sim_time);
    }
    dut.SUB_HSEL = 0;

}



int main(int argc, char **argv)
{
    Vdma_wrapper dut;
    VerilatedFstC m_trace;

    Verilated::traceEverOn(true);
    dut.trace(&m_trace, 5);
    m_trace.open("dma_trace.vcd");

    // setup tb variables, reset
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
    tick(dut, m_trace);

    printf("Reset Test\n");

    dut.nRST = 1;
    test_name = "Reset";
    test_number = 1;
    fail = 0;

    reset(dut, m_trace);

    // test case 1.1
    test_name = "Memory-to-Memory test case 1.1";
    printf("%s\n", test_name.c_str());

    printf("1\n");
    tick(dut, m_trace);
    printf("2\n");
    
    tick(dut, m_trace);
    dut.SUB_HSEL = 1;
    dut.SUB_HTRANS = NON_SEQ;
    dut.SUB_HADDR = SAR;
    dut.SUB_HSIZE = 0;
    dut.SUB_HWRITE = 1;

    for(auto i = 0; i < 100; i++)
    {
        tick(dut, m_trace);
    }

    printf("TB ended\n");
    m_trace.close();
    return (fail > 0);
}
