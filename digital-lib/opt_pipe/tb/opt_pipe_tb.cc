#include <iostream>
#include <queue>
#include <stdint.h>

#include "Vopt_pipe.h"
#include "verilated.h"
#include "verilated_fst_c.h"

#define MAX_SIM_TIME 100

typedef struct {
    vluint64_t end_cycle;
    uint8_t expected;
} test_vector_t;

bool passed_tests = true;

vluint64_t sim_time = 0;
vluint64_t cycles = 0;
Vopt_pipe *dut_ptr;
VerilatedFstC *trace_ptr;

double sc_time_stamp() {
    return sim_time;
}

void signal_handler(int signum) {
    std::cout << "Got signal " << signum << std::endl;
    dut_ptr->final();
    trace_ptr->close();
    exit(1);
}

void tick(Vopt_pipe &dut, VerilatedFstC &trace) {
    dut.CLK = 0;
    dut.eval();
    trace.dump(sim_time);
    sim_time++;
    dut.CLK = 1;
    dut.eval();
    trace.dump(sim_time);
    sim_time++;
    cycles++;
}

void reset(Vopt_pipe &dut, VerilatedFstC &trace) {
    // Initialize signals
    dut.CLK = 0;
    dut.nRST = 0;
    dut.ready = 0;
    dut.in = 0;

    tick(dut, trace);
    dut.nRST = 0;
    tick(dut, trace);
    dut.nRST = 1;
    tick(dut, trace);
}

void check(uint8_t expected, uint8_t received) {
    if (expected != received) {
        passed_tests = false;
        std::cout << "Expected: " << std::hex << (uint64_t)expected << std::endl;
        std::cout << "Received: " << std::hex << (uint64_t)received << std::endl;
    }
}

void checkDone(uint8_t expected) {
    if (!dut_ptr->done) {
        passed_tests = false;
        std::cout << "Expected: " << std::hex << (uint64_t)expected << " at time " << sim_time
                  << std::endl;
    }
}

int main(int argc, char **argv) {
    Vopt_pipe dut;
    VerilatedFstC m_trace;

    Verilated::traceEverOn(true);
    dut.trace(&m_trace, 5);
    m_trace.open("waveform.fst");

    dut_ptr = &dut;
    trace_ptr = &m_trace;

    signal(SIGINT, signal_handler);

    auto tstart = std::chrono::high_resolution_clock::now();

    reset(dut, m_trace);

    std::queue<test_vector_t> tests;

    while (sim_time < MAX_SIM_TIME) {
        dut.ready = 0;
        dut.in = 0;

        // Create a new test vector
        test_vector_t test;
        test.expected = rand() & 0xFFFF;
        test.end_cycle = sim_time + (2 * 2); // NUM_STAGES=2 but we double count sim time
        tests.push(test);
        dut.ready = 1;
        dut.in = test.expected;

        // If the DUT is done then check the top vector
        if (tests.size() > 0 && tests.front().end_cycle == sim_time) {
            test_vector_t front = tests.front();
            tests.pop();
            checkDone(front.expected);
            check(front.expected, dut.out);
        }

        tick(dut, m_trace);
    }

    auto tend = std::chrono::high_resolution_clock::now();

    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(tend - tstart);

    if (passed_tests) {
        std::cout << "PASSED ALL TESTS" << std::endl;
    } else {
        std::cout << "FAILING TESTS" << std::endl;
    }

    std::cout << "Simulated " << std::dec << cycles << " cycles in " << ms.count() << "ms"
              << ", rate of " << (float)cycles / ((float)ms.count() / 1000.0)
              << " cycles per second." << std::endl;

    m_trace.close();
    dut.final();

    return 0;
}
