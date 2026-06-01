#include <iostream>
#include <string>

#include "verilated.h"
#include "verilated_fst_c.h"
#include "Vgpio_wrapper.h"
#include "Vgpio_wrapper_gpio_wrapper.h" // hacky way to get NUM_PINS from DUT

#define ONES (~0u)
#define MAX_PINS (32u)

vluint64_t sim_time = 0;

uint32_t NUM_PINS = 0;

const uint32_t DATA_ADDR = 0x0;
const uint32_t DIR_ADDR = 0x4;
const uint32_t INTR_EN_ADDR = 0x8;
const uint32_t POS_EN_ADDR = 0xC;
const uint32_t NEG_EN_ADDR = 0x10;
const uint32_t INTR_CLR_ADDR = 0x14;
const uint32_t INTR_STAT_ADDR = 0x18;

std::string test_name;
int test_number;
int fail;
uint32_t test_data;

void tick(Vgpio_wrapper &dut, VerilatedFstC &trace)
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

void reset(Vgpio_wrapper &dut, VerilatedFstC &trace)
{
    dut.CLK = 0;
    dut.nRST = 1;

    tick(dut, trace);
    dut.nRST = 0;
    tick(dut, trace);
    dut.nRST = 1;
    tick(dut, trace);
}

void error(std::string msg)
{
    printf("Time %4d [FAILED]: Test %s (%2d) %s\n",
           sim_time, test_name.c_str(), test_number, msg.c_str());
}

void self_check(uint32_t exp, uint32_t act)
{
    if (exp != act)
    {
        printf("Time %4d [FAILED]: Test %s (%2d)\n\tExpected %x, Actual %x\n",
               sim_time, test_name.c_str(), test_number, exp, act);
        fail++;
    }
}

void reg_read(Vgpio_wrapper &dut, VerilatedFstC &trace, uint32_t offset, uint32_t expected)
{
    dut.ren = 1;
    dut.wen = 0;
    dut.addr = offset;
    dut.wdata = 0;
    dut.strobe = 0;

    tick(dut, trace);

    self_check(expected, dut.rdata);

    dut.ren = 0;
    dut.addr = 0;
}

void reg_write(Vgpio_wrapper &dut, VerilatedFstC &trace, uint32_t offset, uint32_t wdata)
{
    dut.ren = 0;
    dut.wen = 1;
    dut.addr = offset;
    dut.wdata = wdata;
    dut.strobe = 0xF;

    tick(dut, trace);

    dut.wen = 0;
    dut.addr = 0;
    dut.wdata = 0;
    dut.strobe = 0;
}

int main(int argc, char **argv)
{
    Vgpio_wrapper dut;
    VerilatedFstC m_trace;

    Verilated::traceEverOn(true);
    dut.trace(&m_trace, 5);
    m_trace.open("gpio.vcd");

    // FIXME: VERILATOR TB BREAKS WITH NUM_PINS < 7
    // need to create a test runner that will properly bit mask all inputs
    // because verilator bins bit widths to byte increments 8, 16, etc...
    uint32_t NUM_PINS = dut.gpio_wrapper->get_num_pins();
    uint32_t PIN_MASK = ONES >> (MAX_PINS - NUM_PINS);
    assert(NUM_PINS > 0 && NUM_PINS <= MAX_PINS);

    printf("----------------------------------\n");
    printf(" Running TB with NUM_PINS = %0d\n", NUM_PINS);
    printf("----------------------------------\n");

    // setup tb variables
    dut.nRST = 1;
    dut.in_data = 0;
    test_name = "Reset";
    test_number = 1;
    fail = 0;

    reset(dut, m_trace);

    if (dut.oe_data != 0)
    {
        error("Incorrect reset value for DIR register");
        fail++;
    }

    test_number++;
    if (dut.out_data != 0)
    {
        error("Incorrect reset value for DATA register");
        fail++;
    }

    test_number++;
    if (dut.irq != 0)
    {
        error("Incorrect reset value for INTR_STAT register");
        fail++;
    }

    // Test block 2: Basic input
    test_name = "Basic input";
    test_number++;
    test_data = 0x3A3A3A3A & PIN_MASK;
    dut.in_data = test_data;
    tick(dut, m_trace);
    reg_read(dut, m_trace, DATA_ADDR, test_data & PIN_MASK);

    // Ensure that interrupt did not fire since interrupts are disabled
    test_number++;
    self_check(0, dut.irq);

    // Test block 2: Configure to output mode
    test_name = "Output";
    test_number++;
    dut.in_data = 0;
    test_data = ONES;
    reg_write(dut, m_trace, DIR_ADDR, ONES);
    reg_write(dut, m_trace, DATA_ADDR, test_data);
    tick(dut, m_trace);
    self_check(test_data & PIN_MASK, dut.out_data);

    test_number++;
    test_data = 0;
    reg_write(dut, m_trace, DATA_ADDR, test_data);
    tick(dut, m_trace);
    self_check(test_data & PIN_MASK, dut.out_data);

    // Test block 3: Configure to mixed input/output mode w/interrupts
    test_name = "I/O + Interrupt";
    test_number++;
    reg_write(dut, m_trace, DIR_ADDR, 0x0F); // Lower 4 output, upper 4 input
    reg_write(dut, m_trace, INTR_EN_ADDR, 0xF0);
    reg_write(dut, m_trace, POS_EN_ADDR, 0x30);
    reg_write(dut, m_trace, NEG_EN_ADDR, 0xC0);
    reg_write(dut, m_trace, DATA_ADDR, 0x0A);

    tick(dut, m_trace);
    self_check(0x0A, dut.out_data);

    test_number++;
    dut.in_data = 0xF0;
    tick(dut, m_trace);

    self_check(0x30, dut.irq);

    test_number++;
    reg_read(dut, m_trace, INTR_STAT_ADDR, dut.irq);

    // Check partial interrupt clears: CLear unset bits, see that
    // interrupt is unaffected
    test_number++;
    reg_write(dut, m_trace, INTR_CLR_ADDR, 0x0F);
    tick(dut, m_trace); // Allow time for clear to take effect

    self_check(0x30, dut.irq);

    // Actually clear interrupt
    test_number++;
    reg_write(dut, m_trace, INTR_CLR_ADDR, 0x70);
    tick(dut, m_trace);

    self_check(0x00, dut.irq);

    test_number++;
    dut.in_data = 0x00;
    tick(dut, m_trace);

    self_check(0xC0, dut.irq);

    test_number++;
    reg_read(dut, m_trace, INTR_STAT_ADDR, dut.irq);

    test_number++;
    reg_write(dut, m_trace, INTR_CLR_ADDR, 0xFF);
    tick(dut, m_trace);

    self_check(0, dut.irq);

    test_number++;
    reg_write(dut, m_trace, INTR_EN_ADDR, 0x00);
    dut.in_data = 0xFF;
    tick(dut, m_trace);

    self_check(0, dut.irq);

    // Block 4: Test write strobe
    // The low byte shouldn't be set after this write
    test_name = "write strobe";
    reg_write(dut, m_trace, DIR_ADDR, ONES);
    dut.ren = 0;
    dut.wen = 1;
    dut.addr = DATA_ADDR;
    dut.wdata = ONES;
    dut.strobe = 0b1110;

    tick(dut, m_trace);

    dut.ren = 0;
    dut.wen = 0;
    dut.addr = 0;
    dut.wdata = 0;
    dut.strobe = 0;

    // Check output data is correct
    self_check((~0xff) & PIN_MASK, dut.out_data); // FIXME: IS THIS LINE EQUIVALENT TO THE .SV TB?

    printf("Passed %2d / %2d tests\n", test_number - fail, test_number);

    m_trace.close();

    return (fail > 0);
}
