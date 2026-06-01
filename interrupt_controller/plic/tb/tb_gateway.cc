#include "Vgateway_wrapper.h"
#include "verilated.h"
#include "verilated_fst_c.h"
#include <iomanip>
#include <iostream>
#include <string>

uint64_t sim_time = 0;
uint64_t fails = 0;

Vgateway_wrapper *dut;
VerilatedFstC *trace;

void tick() {
    dut->clk = 0;
    dut->eval();
    trace->dump(sim_time++);
    dut->clk = 1;
    dut->eval();
    trace->dump(sim_time++);
}

void reset() {
    dut->clk = 0;
    dut->nrst = 1;
    dut->active_high_interrupt_completed = 0;
    dut->rising_interrupt_completed = 0;
    dut->falling_interrupt_completed = 0;
    dut->active_low_interrupt_completed = 0;
    dut->active_high_interrupt_pending = 0;
    dut->rising_interrupt_pending = 0;
    dut->falling_interrupt_pending = 0;
    dut->active_low_interrupt_pending = 0;

    tick();
    dut->nrst = 0;
    tick();
    dut->nrst = 1;
    tick();
}

void wait_for_propagate(uint32_t clocks) {
    for (auto i = 0; i < clocks; i++)
        tick();
}

void ensure(uint32_t actual, uint32_t expected, const char *test_name) {
    if (actual != expected) {
        std::cout << "[FAIL] " << "Time " << sim_time << "\t" << test_name
                  << ": Expected: " << expected << ", Actual: " << actual << std::endl;
        fails++;
    } else {
        std::cout << "[PASS] " << "Time " << sim_time << "\t" << test_name << std::endl;
    }
}

int main(int argc, char **argv) {
    dut = new Vgateway_wrapper;
    trace = new VerilatedFstC;
    Verilated::traceEverOn(true);
    dut->trace(trace, 5);
    trace->open("gateway.fst");

    // Test case 1: interrupt source is rising edge
    dut->source = 0;
    reset();
    dut->source = 1;
    ensure(dut->active_high_interrupt_notification, 0, "Test 1: Active High");
    ensure(dut->rising_interrupt_notification, 0, "Test 1: Rising");
    ensure(dut->falling_interrupt_notification, 0, "Test 1: Falling");
    ensure(dut->active_low_interrupt_notification, 0, "Test 1: Active Low");
    wait_for_propagate(2);
    ensure(dut->active_high_interrupt_notification, 1, "Test 1: Active High"); // Edge detection without counter
    ensure(dut->rising_interrupt_notification, 1, "Test 1: Rising");
    ensure(dut->falling_interrupt_notification, 1, "Test 1: Falling");
    ensure(dut->active_low_interrupt_notification, 1, "Test 1: Active Low");
    dut->active_high_interrupt_pending = 1;
    dut->rising_interrupt_pending = 1;
    dut->falling_interrupt_pending = 1;
    dut->active_low_interrupt_pending = 1;
    tick();
    dut->active_high_interrupt_pending = 0;
    dut->rising_interrupt_pending = 0;
    dut->falling_interrupt_pending = 0;
    dut->active_low_interrupt_pending = 0;
    ensure(dut->active_high_interrupt_notification, 0, "Test 1: Active High");
    ensure(dut->rising_interrupt_notification, 0, "Test 1: Rising");
    ensure(dut->falling_interrupt_notification, 0, "Test 1: Falling");
    ensure(dut->active_low_interrupt_notification, 0, "Test 1: Active Low");

    // Test case 2: interrupt source is falling edge
    dut->source = 1;
    reset();
    dut->source = 0;
    ensure(dut->active_high_interrupt_notification, 1, "Test 2: Active High");
    ensure(dut->rising_interrupt_notification, 0, "Test 2: Rising");
    ensure(dut->falling_interrupt_notification, 0, "Test 2: Falling");
    ensure(dut->active_low_interrupt_notification, 1, "Test 2: Active Low");
    wait_for_propagate(2);
    ensure(dut->active_high_interrupt_notification, 1, "Test 2: Active High");
    ensure(dut->rising_interrupt_notification, 1, "Test 2: Rising");
    ensure(dut->falling_interrupt_notification, 1, "Test 2: Falling");
    ensure(dut->active_low_interrupt_notification, 1, "Test 2: Active Low");
    dut->active_high_interrupt_pending = 1;
    dut->rising_interrupt_pending = 1;
    dut->falling_interrupt_pending = 1;
    dut->active_low_interrupt_pending = 1;
    tick();
    dut->active_high_interrupt_pending = 0;
    dut->rising_interrupt_pending = 0;
    dut->falling_interrupt_pending = 0;
    dut->active_low_interrupt_pending = 0;
    ensure(dut->active_high_interrupt_notification, 0, "Test 2: Active High");
    ensure(dut->rising_interrupt_notification, 0, "Test 2: Rising");
    ensure(dut->falling_interrupt_notification, 0, "Test 2: Falling");
    ensure(dut->active_low_interrupt_notification, 0, "Test 2: Active Low");
    dut->source = 1;

    // Test case 3: multiple interrupt causes should only cause a single interrupt notification
    dut->source = 0;
    reset();
    dut->source = 1;
    ensure(dut->active_high_interrupt_notification, 0, "Test 3: Active High");
    ensure(dut->rising_interrupt_notification, 0, "Test 3: Rising");
    ensure(dut->falling_interrupt_notification, 0, "Test 3: Falling");
    ensure(dut->active_low_interrupt_notification, 0, "Test 3: Active Low");
    wait_for_propagate(2);
    ensure(dut->active_high_interrupt_notification, 1, "Test 3: Active High");
    ensure(dut->rising_interrupt_notification, 1, "Test 3: Rising");
    ensure(dut->falling_interrupt_notification, 1, "Test 3: Falling");
    ensure(dut->active_low_interrupt_notification, 1, "Test 3: Active Low");
    dut->active_high_interrupt_pending = 1;
    dut->rising_interrupt_pending = 1;
    dut->falling_interrupt_pending = 1;
    dut->active_low_interrupt_pending = 1;
    wait_for_propagate(2);
    dut->active_high_interrupt_pending = 0;
    dut->rising_interrupt_pending = 0;
    dut->falling_interrupt_pending = 0;
    dut->active_low_interrupt_pending = 0;
    ensure(dut->active_high_interrupt_notification, 0, "Test 3: Active High");
    ensure(dut->rising_interrupt_notification, 0, "Test 3: Rising");
    ensure(dut->falling_interrupt_notification, 0, "Test 3: Falling");
    ensure(dut->active_low_interrupt_notification, 0, "Test 3: Active Low");
    for (int i = 0; i < 10; i++) {
        ensure(dut->active_high_interrupt_notification, 0, "Test 3: Active High");
        ensure(dut->rising_interrupt_notification, 0, "Test 3: Rising");
        ensure(dut->falling_interrupt_notification, 0, "Test 3: Falling");
        ensure(dut->active_low_interrupt_notification, 0, "Test 3: Active Low");
        dut->source = i % 2 == 1;
        tick();
    }

    // Test case 4: active_high triggered interrupt stays high after a completion
    dut->source = 0;
    reset();
    dut->source = 1;
    ensure(dut->active_high_interrupt_notification, 0, "Test 4: Active High");
    tick();
    ensure(dut->active_high_interrupt_notification, 1, "Test 4: Active High");
    dut->active_high_interrupt_pending = 1;
    tick();
    ensure(dut->active_high_interrupt_notification, 0, "Test 4: Active High");
    dut->active_high_interrupt_pending = 0;
    dut->active_high_interrupt_completed = 1;
    tick();
    dut->active_high_interrupt_completed = 0;
    tick();
    ensure(dut->active_high_interrupt_notification, 1, "Test 4: Active High");
    tick();

    // Test case 5: active_low triggered interrupt stays low after a completion
    dut->source = 0;
    reset();
    dut->source = 1;
    ensure(dut->active_low_interrupt_notification, 0, "Test 5: Active Low");
    tick();
    ensure(dut->active_low_interrupt_notification, 1, "Test 5: Active Low");
    dut->active_low_interrupt_pending = 1;
    tick();
    ensure(dut->active_low_interrupt_notification, 0, "Test 5: Active Low");
    dut->active_low_interrupt_pending = 0;
    dut->active_low_interrupt_completed = 1;
    tick();
    dut->active_low_interrupt_completed = 0;
    tick();
    ensure(dut->active_low_interrupt_notification, 1, "Test 5: Active Low");
    tick();

    if (fails != 0) {
        std::cout << "Total failures: " << fails << std::endl;
    }

    trace->close();

    return 0;
}
