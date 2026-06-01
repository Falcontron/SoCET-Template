#include "Vplic_wrapper.h"
#include "verilated.h"
#include "verilated_fst_c.h"
#include <array>
#include <iomanip>
#include <iostream>
#include <string>

uint64_t sim_time = 0;

Vplic_wrapper *dut;
VerilatedFstC *trace;

const uint32_t num_interrupts = 64;
const uint32_t num_contexts = 2;

template <uint32_t Base, uint32_t Offset, uint32_t Num>
constexpr std::array<uint32_t, Num> get_array() {
    uint32_t arr[Num] = {0};
    uint32_t val = Base;
    for (int i = 0; i < Num; i++) {
        arr[i] = val;
        val += Offset;
    }
    std::array<uint32_t, Num> ret;
    std::move(std::begin(arr), std::end(arr), ret.begin());
    return ret;
}

const uint32_t INTERRUPT_PRIORITY_START = 0x0;
const uint32_t INTERRUPT_PENDING_START = 0x1000;
const uint32_t INTERRUPT_ENABLE_START = 0x2000;
const uint32_t PRIORITY_THRESHOLD_START = 0x200000;
const uint32_t CLAIM_COMPLETE_START = PRIORITY_THRESHOLD_START + 0x4;

const auto interrupt_priority = get_array<INTERRUPT_PRIORITY_START, 4, num_interrupts>();
const auto interrupt_pending = get_array<INTERRUPT_PENDING_START, 4, num_interrupts / 32>();
const auto interrupt_enable = get_array<INTERRUPT_ENABLE_START, 0x80, num_contexts>();
const auto priority_threshold = get_array<PRIORITY_THRESHOLD_START, 0x1000, num_contexts>();
const auto claim_complete = get_array<CLAIM_COMPLETE_START, 0x1000, num_contexts>();

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
    dut->hw_interrupt_requests = 0;

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

    dut->CLK = 0;
    dut->eval();
    trace->dump(sim_time++);
    auto rvalue = dut->rdata;
    dut->CLK = 1;
    dut->eval();
    trace->dump(sim_time++);

    dut->ren = 0;
    dut->addr = 0;

    return rvalue;
}

void wait_for_propagate(uint32_t clocks) {
    for (auto i = 0; i < clocks; i++)
        tick();
}

uint32_t fails = 0;
void ensure(uint32_t actual, uint32_t expected, const char *test_name) {
    if (actual != expected) {
        std::cout << std::dec << "[FAIL] " << test_name << ":\tTime " << sim_time
                  << ": Expected: " << std::hex << expected << ", Actual: " << actual << std::dec
                  << std::endl;
        fails++;
    } else {
        std::cout << "[PASS] " << test_name << ":\tTime " << sim_time << std::endl;
    }
}

int main(int argc, char **argv) {
    dut = new Vplic_wrapper;
    trace = new VerilatedFstC;
    Verilated::traceEverOn(true);
    dut->trace(trace, 5);
    trace->open("plic.fst");

    // Test 1: Simple interrupt enabled and triggered
    // Expected behavior: Claim returns 1, then after a completion, it returns 0
    reset();
    reg_write(interrupt_priority[1], 0x7);
    reg_write(interrupt_enable[0], 0x2);
    dut->hw_interrupt_requests = 0x1;
    wait_for_propagate(2);
    ensure(reg_read(claim_complete[0]), 1, "Test 1");
    dut->hw_interrupt_requests = 0x0;
    tick();
    reg_write(claim_complete[0], 1);
    ensure(reg_read(claim_complete[0]), 0, "Test 1");

    // Test 2: Multiple interrupts enabled, single claimer, no priority tie
    // Expected behavior: Higher priority interrupt's ID is returned by the claim
    reset();
    reg_write(interrupt_priority[1], 0x7);
    reg_write(interrupt_priority[2], 0x9);
    reg_write(interrupt_enable[0], 0b110);
    dut->hw_interrupt_requests = 0b11;
    wait_for_propagate(2);
    ensure(reg_read(claim_complete[0]), 2, "Test 2");
    tick();
    reg_write(claim_complete[0], 2);
    // Interrupt 1 triggers because there will be some delay before interrupt 2 is retriggered
    ensure(reg_read(claim_complete[0]), 1, "Test 2");
    dut->hw_interrupt_requests = 0b01;
    tick();
    reg_write(claim_complete[0], 1);
    wait_for_propagate(2);
    ensure(reg_read(claim_complete[0]), 0, "Test 2");

    // Test 3: Multiple interrupts enabled, single claimer, priority tie
    // Expected behavior: Lower interrupt ID's ID is returned
    reset();
    reg_write(interrupt_priority[1], 0x7);
    reg_write(interrupt_priority[2], 0x7);
    reg_write(interrupt_enable[0], 0b110);
    dut->hw_interrupt_requests = 0b11;
    wait_for_propagate(2);
    ensure(reg_read(claim_complete[0]), 1, "Test 3");
    reg_write(claim_complete[0], 1);
    ensure(reg_read(claim_complete[0]), 2, "Test 3");
    dut->hw_interrupt_requests = 0b0;
    tick();
    reg_write(claim_complete[0], 2);
    ensure(reg_read(claim_complete[0]), 0, "Test 3");

    // Test 4: Multiple interrupts enabled, multiple claimer, no priority tie
    // Expected behavior: Higher priority interrupt's ID is returned by claim, then second highest
    // priority interrupt's ID is returned by a claim by a different context
    reset();
    reg_write(interrupt_priority[1], 0x7);
    reg_write(interrupt_priority[2], 0x9);
    reg_write(interrupt_enable[0], 0b110);
    reg_write(interrupt_enable[1], 0b110);
    dut->hw_interrupt_requests = 0b11;
    wait_for_propagate(2);
    ensure(reg_read(claim_complete[0]), 2, "Test 4");
    tick();
    ensure(reg_read(claim_complete[1]), 1, "Test 4");
    dut->hw_interrupt_requests = 0b0;
    tick();
    reg_write(claim_complete[0], 2);
    reg_write(claim_complete[1], 1);
    ensure(reg_read(claim_complete[0]), 0, "Test 4");
    ensure(reg_read(claim_complete[1]), 0, "Test 4");

    // Test 5: Multiple interrupts enabled, multiple claimer, priority tie
    // Expected behavior: Lower interrupt ID's ID is returned by claim, then second lowest
    // priority interrupt ID's ID is returned by a claim by a different context
    reset();
    reg_write(interrupt_priority[1], 0x7);
    reg_write(interrupt_priority[2], 0x7);
    reg_write(interrupt_enable[0], 0b110);
    reg_write(interrupt_enable[1], 0b110);
    dut->hw_interrupt_requests = 0b11;
    wait_for_propagate(2);
    ensure(reg_read(claim_complete[0]), 1, "Test 5");
    tick();
    ensure(reg_read(claim_complete[1]), 2, "Test 5");
    dut->hw_interrupt_requests = 0b00;
    tick();
    reg_write(claim_complete[0], 1);
    reg_write(claim_complete[1], 2);
    ensure(reg_read(claim_complete[0]), 0, "Test 5");
    ensure(reg_read(claim_complete[1]), 0, "Test 5");

    // Test 6: Multiple interrupts for a single source requested before a completion (rising edge)
    // Expected behavior: After completing the interrupt, another interrupt is immediately fired
    reset();
    reg_write(interrupt_priority[3], 0x7);
    reg_write(interrupt_enable[0], 0b1000);
    dut->hw_interrupt_requests = 0b100;
    tick();
    dut->hw_interrupt_requests = 0b000;
    wait_for_propagate(2);
    ensure(reg_read(claim_complete[0]), 3, "Test 6");
    dut->hw_interrupt_requests = 0b100;
    tick();
    dut->hw_interrupt_requests = 0b000;
    reg_write(claim_complete[0], 3);
    wait_for_propagate(2);
    ensure(reg_read(claim_complete[0]), 3, "Test 6");

    // Test 7: Multiple interrupts for a single source requested before a completion (falling edge)
    // Expected behavior: After completing the interrupt, another interrupt is immediately fired
    reset();
    dut->hw_interrupt_requests = 0b1000;
    tick();
    reg_write(interrupt_priority[4], 0x7);
    reg_write(interrupt_enable[0], 0b10000);
    dut->hw_interrupt_requests = 0b0000;
    tick();
    dut->hw_interrupt_requests = 0b1000;
    wait_for_propagate(2);
    ensure(reg_read(claim_complete[0]), 4, "Test 7");
    dut->hw_interrupt_requests = 0b0000;
    tick();
    dut->hw_interrupt_requests = 0b1000;
    reg_write(claim_complete[0], 4);
    wait_for_propagate(2);
    ensure(reg_read(claim_complete[0]), 4, "Test 7");

    // Test 8: Multiple interrupts for a single source requested before a completion, multiple
    // claimers Expected behavior: No other interrupt is pending until the first claimer completes
    // the interrupt
    reset();
    reg_write(interrupt_priority[3], 0x7);
    reg_write(interrupt_enable[0], 0b1000);
    reg_write(interrupt_enable[1], 0b1000);
    dut->hw_interrupt_requests = 0b100;
    tick();
    dut->hw_interrupt_requests = 0b000;
    wait_for_propagate(2);
    ensure(reg_read(claim_complete[0]), 3, "Test 8");
    dut->hw_interrupt_requests = 0b100;
    tick();
    dut->hw_interrupt_requests = 0b000;
    wait_for_propagate(2);
    ensure(reg_read(claim_complete[1]), 0, "Test 8");
    dut->hw_interrupt_requests = 0b100;
    tick();
    dut->hw_interrupt_requests = 0b000;
    reg_write(claim_complete[0], 3);
    wait_for_propagate(2);
    ensure(reg_read(claim_complete[1]), 3, "Test 8");
    reg_write(claim_complete[1], 3);
    wait_for_propagate(2);
    ensure(reg_read(claim_complete[0]), 3, "Test 8");
    reg_write(claim_complete[0], 3);
    wait_for_propagate(2);
    ensure(reg_read(claim_complete[1]), 0, "Test 8");

    // Test 9+10: From Chapter 1.2 of spec

    // Test 9: Level triggered interrupt still high after completion
    // Expected behavior: Another interrupt notification is sent which needs to be claimed and
    // completed
    reset();
    reg_write(interrupt_priority[1], 0x7);
    reg_write(interrupt_enable[0], 0x2);
    dut->hw_interrupt_requests = 0x1;
    wait_for_propagate(2);
    ensure(reg_read(claim_complete[0]), 1, "Test 9");
    reg_write(claim_complete[0], 1);
    wait_for_propagate(2);
    ensure(reg_read(claim_complete[0]), 1, "Test 9");
    dut->hw_interrupt_requests = 0;
    reg_write(claim_complete[0], 0);
    wait_for_propagate(2);
    ensure(reg_read(claim_complete[0]), 0, "Test 9");

    // Test 10: Level triggered interrupt goes low after core accepts it, but before it has been
    // claimed Expected behavior: Interrupt request stays in the IP bit but 0 sent on claim
    reset();
    reg_write(interrupt_priority[1], 0x7);
    reg_write(interrupt_enable[0], 0x2);
    dut->hw_interrupt_requests = 0x1;
    wait_for_propagate(2);
    ensure(dut->interrupt_service_request, 1, "Test 10");
    dut->hw_interrupt_requests = 0x0;
    wait_for_propagate(2);
    ensure(dut->interrupt_service_request, 1, "Test 10");
    wait_for_propagate(2);
    ensure(reg_read(claim_complete[0]), 0, "Test 10"); // TODO: Rework gateway

    // Test 11: Priority of 0 never fires an interrupt
    // Expected behavior: Interrupt claim returns 0
    reset();
    reg_write(interrupt_priority[1], 0x0);
    reg_write(interrupt_enable[0], 0x2);
    dut->hw_interrupt_requests = 0x1;
    tick();
    ensure(reg_read(claim_complete[0]), 0, "Test 11");
    dut->hw_interrupt_requests = 0x0;
    tick();
    ensure(reg_read(claim_complete[0]), 0, "Test 11");

    // Test 12: Writes of values greater than 8 bits masked to lower bits
    // Expected behavior: Priority set 1 << 9 sets it to 0
    reset();
    reg_write(interrupt_priority[1], 1 << 9);
    tick();
    ensure(reg_read(interrupt_priority[1]), 0, "Test 12");

    // Test 13: Bit 0 of word 0 of interrupt pending is hardwired to 0
    // Expected behavior: Reads of interupt pending bit 0 returns 0 even all other interrupts are
    // enabled and pending
    reset();
    for (int i = 1; i < 64; i++) {
        reg_write(interrupt_priority[i], i);
    }
    // Ignore interrupt 2 and 3 (edge triggered)
    const uint32_t ignore = 1 << 0 | 1 << 3 | 1 << 4;
    reg_write(interrupt_enable[0], 0xAAAAAAAA & ~ignore); // TODO: make this a 2d array
    reg_write(interrupt_enable[0] + 4, 0xAAAAAAAA);
    reg_write(interrupt_enable[0] + 8, 0x1);
    reg_write(interrupt_enable[1], 0x55555555 & ~ignore);
    reg_write(interrupt_enable[1] + 4, 0x55555555);
    reg_write(interrupt_enable[1] + 8, 0x1);
    ensure(reg_read(interrupt_enable[0]), 0xAAAAAAAA & ~ignore, "Test 13");
    ensure(reg_read(interrupt_enable[0] + 4), 0xAAAAAAAA, "Test 13");
    ensure(reg_read(interrupt_enable[0] + 8), 0x1, "Test 13");
    ensure(reg_read(interrupt_enable[1]), 0x55555555 & ~ignore, "Test 13");
    ensure(reg_read(interrupt_enable[1] + 4), 0x55555555, "Test 13");
    ensure(reg_read(interrupt_enable[1] + 8), 0x1, "Test 13");
    dut->hw_interrupt_requests = 0xFFFFFFFFFFFFFFFF;
    wait_for_propagate(2);
    ensure(reg_read(interrupt_pending[0]) & ~ignore, 0xFFFFFFFF & ~ignore, "Test 13");
    ensure(reg_read(interrupt_pending[0] + 4), 0xFFFFFFFF, "Test 13");
    ensure(reg_read(interrupt_pending[0] + 8), 0x1, "Test 13");

    // Test 14: Interrupt enable bits for interrupt 0 is hardwired zero
    // Expected behavior: Enabling all interrupts does not enable interrupt 0
    reset();
    reg_write(interrupt_priority[1], 0x7);
    reg_write(interrupt_enable[0], 0xFFFFFFFF);
    reg_write(interrupt_enable[0] + 4, 0xFFFFFFFF);
    reg_write(interrupt_enable[1], 0xFFFFFFFF);
    reg_write(interrupt_enable[1] + 4, 0xFFFFFFFF);
    ensure(reg_read(interrupt_enable[0]), 0xFFFFFFFE, "Test 14");
    ensure(reg_read(interrupt_enable[0] + 4), 0xFFFFFFFF, "Test 14");
    ensure(reg_read(interrupt_enable[1]), 0xFFFFFFFE, "Test 14");
    ensure(reg_read(interrupt_enable[1] + 4), 0xFFFFFFFF, "Test 14");

    // Test 15: Priority thresholds properly mask low priority interrupts
    // Expected behavior: A low priority interrupt is fired and claim returns 0, a high priority
    // interrupt is fired and claim returns id
    reset();
    reg_write(interrupt_priority[1], 0x7);
    reg_write(interrupt_priority[2], 0x9);
    reg_write(interrupt_enable[0], 0b110);
    reg_write(priority_threshold[0], 0x8);
    dut->hw_interrupt_requests = 0b110;
    wait_for_propagate(2);
    ensure(reg_read(claim_complete[0]), 2, "Test 15");
    dut->hw_interrupt_requests = 0x0;
    tick();
    reg_write(claim_complete[0], 2);
    ensure(reg_read(claim_complete[0]), 0, "Test 15");

    // Test 16: Interrupt claim clears IP bit
    // Expected behavior: An interrupt is fired and IP goes high, after a claim, IP goes low
    reset();
    reg_write(interrupt_priority[1], 0x7);
    reg_write(interrupt_enable[0], 0x2);
    dut->hw_interrupt_requests = 0x1;
    wait_for_propagate(2);
    ensure(reg_read(interrupt_pending[0]) & 0x2, 0x2, "Test 16");
    ensure(reg_read(interrupt_pending[0]) & 0x2, 0x2, "Test 16");
    ensure(reg_read(claim_complete[0]), 1, "Test 16");
    ensure(reg_read(interrupt_pending[0]) & 0x2, 0x0, "Test 16");
    dut->hw_interrupt_requests = 0x0;
    tick();
    reg_write(claim_complete[0], 1);
    ensure(reg_read(claim_complete[0]), 0, "Test 16");

    // Test 17: Write of disabled ID does not complete interrupt
    // Expected behavior: An interrupt fires and is claimed, after writing 0, another interrupt
    // cannot be fired because the core has not sent the complete signal to the gateway.
    reset();
    reg_write(interrupt_priority[1], 0x7);
    reg_write(interrupt_enable[0], 0x2);
    dut->hw_interrupt_requests = 0x1;
    wait_for_propagate(2);
    ensure(reg_read(claim_complete[0]), 1, "Test 17");
    dut->hw_interrupt_requests = 0x0;
    tick();
    reg_write(claim_complete[0], 0);
    dut->hw_interrupt_requests = 0x1;
    tick();
    ensure(reg_read(claim_complete[0]), 0, "Test 17");
    dut->hw_interrupt_requests = 0x0;

    // Test 18: Completion from a context with interrupt disabled
    // Expected behavior: An interrupt fires and is claimed by a context with it enabled, writing
    // from other context does not complete the interrupt
    reset();
    reg_write(interrupt_priority[1], 0x7);
    reg_write(interrupt_enable[0], 0x2);
    dut->hw_interrupt_requests = 0x1;
    wait_for_propagate(2);
    ensure(reg_read(claim_complete[0]), 1, "Test 18");
    dut->hw_interrupt_requests = 0x0;
    tick();
    reg_write(claim_complete[1], 1);
    dut->hw_interrupt_requests = 0x1;
    tick();
    ensure(reg_read(claim_complete[0]), 0, "Test 18");
    dut->hw_interrupt_requests = 0x0;
    reg_write(claim_complete[0], 1);
    dut->hw_interrupt_requests = 0x1;
    wait_for_propagate(2);
    ensure(reg_read(claim_complete[0]), 1, "Test 18");
    dut->hw_interrupt_requests = 0x0;

    // Test 19: Interrupts are enabled/disabled on different contexts are properly sent to right
    // context Expected behavior: After context 0 enables interrupt 1 and context 1 enables
    // interrupt 2 and both interrupts go high, context 1 can only claim interrupt 2 and context 0
    // can only claim interrupt 1
    reset();
    reg_write(interrupt_priority[1], 0x4);
    reg_write(interrupt_priority[2], 0x4);
    reg_write(interrupt_enable[0], 0x2);
    reg_write(interrupt_enable[1], 0x4);
    dut->hw_interrupt_requests = 0b11;
    wait_for_propagate(2);
    ensure(reg_read(claim_complete[1]), 0, "Test 19");
    ensure(reg_read(claim_complete[0]), 1, "Test 19");
    ensure(reg_read(claim_complete[1]), 2, "Test 19");
    reset();
    reg_write(interrupt_priority[1], 0x4);
    reg_write(interrupt_priority[2], 0x4);
    reg_write(interrupt_enable[0], 0x2);
    reg_write(interrupt_enable[1], 0x4);
    dut->hw_interrupt_requests = 0b11;
    wait_for_propagate(2);
    ensure(reg_read(claim_complete[1]), 0, "Test 19");
    ensure(reg_read(claim_complete[0]), 1, "Test 19");
    ensure(reg_read(claim_complete[1]), 2, "Test 19");

    trace->close();

    return fails;
}
