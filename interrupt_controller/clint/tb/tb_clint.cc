#include <iostream>
#include <string>

#include "verilated.h"
#include "verilated_fst_c.h"
#include "Vclint_wrapper.h"
#include "Vclint_wrapper_bus_protocol_if.h"

uint64_t sim_time = 0;

Vclint_wrapper *dut;
VerilatedFstC *trace;

const uint32_t MSIP0_ADDR = 0x0;
const uint32_t MSIP1_ADDR = MSIP0_ADDR + 0x4;
const uint32_t MTIMECMP0_ADDR = MSIP0_ADDR + 0x4000;
const uint32_t MTIMECMPH0_ADDR = MTIMECMP0_ADDR + 0x4;
const uint32_t MTIMECMP1_ADDR = MTIMECMP0_ADDR + 0x8;
const uint32_t MTIMECMPH1_ADDR = MTIMECMPH0_ADDR + 0x8;
const uint32_t MTIME_ADDR = MTIMECMP0_ADDR + 0x7FF8;
const uint32_t MTIMEH_ADDR = MTIME_ADDR + 0x4;

void tick() {
    dut->CLK = 0;
    dut->eval();
    trace->dump(sim_time++);
    dut->CLK = 1;
    dut->eval();
    trace->dump(sim_time++);
}

void reset() {
    dut->CLK = 0;
    dut->nRST = 1;

    tick();
    dut->nRST = 0;
    tick();
    dut->nRST = 1;
    tick();
}

void reg_write(uint32_t offset, uint32_t wdata) {
    dut->ren = 0;
    dut->wen = 1;
    dut->addr = offset;
    dut->wdata = wdata;
    dut->strobe = 0xF;

    tick();

    dut->wen = 0;
    dut->addr = 0;
    dut->wdata = 0;
    dut->strobe = 0;
}

uint32_t reg_read(uint32_t offset) {
    dut->ren = 1;
    dut->wen = 0;
    dut->addr = offset;
    dut->wdata = 0;
    dut->strobe = 0xF;

    tick();
    auto rvalue = dut->rdata;

    dut->ren = 0;
    dut->addr = 0;

    return rvalue;
}

void ensure(uint32_t actual, uint32_t expected, const char *test_name) {
    if(actual != expected) {
        std::cout << "[FAIL] " << test_name << ": Time " << sim_time << ": Expected: " << expected << ", Actual: " << actual << std::endl; 
    } else {
        std::cout << "[PASS] " << test_name << std::endl;
    }
}

int main(int argc, char **argv) {
    dut = new Vclint_wrapper;
    trace = new VerilatedFstC;
    Verilated::traceEverOn(true);
    dut->trace(trace, 5);
    trace->open("clint.fst");

    reset();
    // Software interrupts
    // Trigger/clear interrupt
    // hart 0
    {
        reg_write(MSIP0_ADDR, 1);
        ensure(dut->soft_int & 1, 1, "hart0: Interrupt raised");
        // Readback
        auto msip_value = reg_read(MSIP0_ADDR);
        ensure(msip_value, 0x1, "hart0: Read MSIP");
        reg_write(MSIP0_ADDR, 0);
        ensure(dut->soft_int & 1, 0, "hart0: Interrupt fell");
        ensure(dut->clear_soft_int & 1, 1, "hart0: Clear raised");
        tick();
        ensure(dut->clear_soft_int & 1, 0, "hart0: Clear fell");
        msip_value = reg_read(MSIP0_ADDR);
        ensure(msip_value, 0x0, "hart0: Read MSIP 2");
    }

    // hart 1
    {
        reg_write(MSIP1_ADDR, 1);
        ensure((dut->soft_int >> 1) & 1, 1, "hart1: Interrupt raised");
        // Readback
        auto msip_value = reg_read(MSIP1_ADDR);
        ensure(msip_value, 0x1, "hart1: Read MSIP");
        reg_write(MSIP1_ADDR, 0);
        ensure((dut->soft_int >> 1) & 1, 0, "hart1: Interrupt fell");
        ensure((dut->clear_soft_int >> 1) & 1, 1, "hart1: Clear raised");
        tick();
        ensure((dut->clear_soft_int >> 1) & 1, 0, "hart1: Clear fell");
        msip_value = reg_read(MSIP1_ADDR);
        ensure(msip_value, 0x0, "hart1: Read MSIP 2");
    }

    // MTIME
    reset();
    auto offset = (sim_time / 2) - 1;
    auto mtime_value = reg_read(MTIME_ADDR) + 1; // +1 accounts for cycle spent reading in value
    for(auto i = 0; i < 10; i++) {
        tick();
    }
    ensure(reg_read(MTIME_ADDR), mtime_value + 10, "MTIME Read 2");

    reg_write(MTIME_ADDR, 0xF000);
    ensure(reg_read(MTIME_ADDR), 0xF001, "MTIME after write");
    reg_write(MTIMEH_ADDR, 0xFFFF);
    ensure(reg_read(MTIMEH_ADDR), 0xFFFF, "MTIMEH after write");

    // MTIMECMP
    // hart 0
    {
        reg_write(MTIMECMPH0_ADDR, 0xFFFF);
        ensure(reg_read(MTIMECMPH0_ADDR), 0xFFFF, "hart0: MTIMECMPH");
        mtime_value = reg_read(MTIME_ADDR);
        reg_write(MTIMECMP0_ADDR, mtime_value + 10);
        for(auto i = 0; i < 9; i++) {
            tick();
        }
        ensure(dut->timer_int & 1, 1, "hart0: Timer int raised");
        reg_write(MTIMECMPH0_ADDR, 0xFFFFFFFF);
        ensure(dut->timer_int & 1, 0, "hart0: Timer int fell");
        ensure(dut->clear_timer_int, 1, "hart0: Timer clear raised");
        tick();
        ensure(dut->clear_timer_int, 0, "hart0: Timer clear fell");
    }
    // hart 1
    {
        reg_write(MTIMECMPH1_ADDR, 0xFFFF);
        ensure(reg_read(MTIMECMPH1_ADDR), 0xFFFF, "hart1: MTIMECMPH");
        mtime_value = reg_read(MTIME_ADDR);
        reg_write(MTIMECMP1_ADDR, mtime_value + 10);
        for(auto i = 0; i < 9; i++) {
            tick();
        }
        ensure((dut->timer_int >> 1) & 1, 1, "hart1: Timer int raised");
        reg_write(MTIMECMPH1_ADDR, 0xFFFFFFFF);
        ensure((dut->timer_int >> 1) & 1, 0, "hart1: Timer int fell");
        ensure((dut->clear_timer_int >> 1), 1, "hart1: Timer clear raised");
        tick();
        ensure((dut->clear_timer_int >> 1), 0, "hart1: Timer clear fell");
    }

    // Illegal read
    ensure(reg_read(0x100), 0xBAD1BAD1, "Illegal read returns 0xBAD1BAD1");
    ensure(dut->__PVT__clint_wrapper__DOT__busif->error, 1, "Illegal read raises busif.error");
    ensure(reg_read(MSIP0_ADDR), 0x0, "Illegal read returns normal value");
    ensure(dut->__PVT__clint_wrapper__DOT__busif->error, 0, "Illegal read lowers busif.error");

    trace->close();

    return 0;
}
