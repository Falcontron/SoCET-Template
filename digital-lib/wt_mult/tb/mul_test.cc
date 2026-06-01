#include <getopt.h>
#include <iostream>
#include <limits>
#include <queue>
#include <random>
#include <signal.h>
#include <stdint.h>

#include "Vwt_mult.h"
#include "Vwt_mult_wt_mult_pkg.h"
#include "verilated.h"
#include "verilated_fst_c.h"

#ifndef WIDTH
#define WIDTH 32
#endif

#ifndef SIGNED
#define SIGNED 1
#endif

#define MAX_SIM_TIME 100000

#if WIDTH <= 4
#define EXTRA_BITS (8 - WIDTH)
#if SIGNED == 1
#define in_t int8_t
#define out_t int8_t
#else
#define in_t uint8_t
#define out_t uint8_t
#endif
#elif WIDTH <= 8
#define EXTRA_BITS (8 - WIDTH)
#if SIGNED == 1
#define in_t int8_t
#define out_t int16_t
#else
#define in_t uint8_t
#define out_t uint16_t
#endif
#elif WIDTH <= 16
#define EXTRA_BITS (16 - WIDTH)
#if SIGNED == 1
#define in_t int16_t
#define out_t int32_t
#else
#define in_t uint16_t
#define out_t uint32_t
#endif
#elif WIDTH <= 32
#define EXTRA_BITS (32 - WIDTH)
#if SIGNED == 1
#define in_t int32_t
#define out_t int64_t
#else
#define in_t uint32_t
#define out_t uint64_t
#endif
#elif WIDTH <= 64
#define EXTRA_BITS (64 - WIDTH)
#if SIGNED == 1
#define in_t int64_t
#define out_t __int128_t
#else
#define in_t uint64_t
#define out_t __uint128_t
#endif
#endif

#define MAX max_n_bit(WIDTH)
#define SEXT(x) ((in_t)((in_t)(x) << EXTRA_BITS) >> EXTRA_BITS)

constexpr __uint128_t max_n_bit(int n) {
    if (n == 128) {
        return __uint128_t(__int128_t(-1L));
    }
    return ((__int128_t)1 << n) - 1;
}

typedef struct {
    in_t a;
    in_t b;
    out_t expected;
    uint32_t start_cycle;
    uint32_t end_cycle;
} test_vector_t;

uint64_t num_passed = 0;
bool passed_tests = true;

vluint64_t sim_time = 0;
vluint64_t cycles = 0;
Vwt_mult *dut_ptr;
VerilatedFstC *trace_ptr;
bool use_seed = false;
int seed = 0;

double sc_time_stamp() {
    return sim_time;
}

void signal_handler(int signum) {
    std::cout << "Got signal " << signum << std::endl;
    dut_ptr->final();
    trace_ptr->close();
    exit(1);
}

void tick(Vwt_mult &dut, VerilatedFstC &trace) {
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

void reset(Vwt_mult &dut, VerilatedFstC &trace) {
    // Initialize signals
    dut.CLK = 0;
    dut.nRST = 0;
    dut.ready = 0;
    dut.a = 0;
    dut.b = 0;

    tick(dut, trace);
    dut.nRST = 0;
    tick(dut, trace);
    dut.nRST = 1;
    tick(dut, trace);
}

void check(out_t expected, out_t received, in_t a, in_t b) {
    if (!dut_ptr->done) {
        passed_tests = false;
        std::cout << "DUT not done yet!" << std::endl;
    } else if (expected != received) {
        passed_tests = false;
        std::cout << "A: " << std::hex << (uint64_t)a << ", B: " << (uint64_t)b << std::endl;
        std::cout << "Expected: " << std::hex << (uint64_t)expected << std::endl;
        std::cout << "Received: " << std::hex << (uint64_t)received << std::endl;
    } else {
        num_passed++;
    }
}

template <typename T, typename U>
T cast_out(U dut_out) {
    T out;
    if constexpr (std::is_same<T, unsigned __int128>::value || std::is_same<T, __int128>::value) {
        out = ((out_t)dut_out[3] << 96) | ((out_t)dut_out[2] << 64) | ((out_t)dut_out[1] << 32) |
              ((out_t)dut_out[0]);
    } else {
        out = dut_out;
    }
    return out;
}

void help() {
    std::cout << "--seed <seed>:       Set seed of srand\n"
                 "--help:              Show help\n";
    exit(1);
}

void cmdArgs(int argc, char **argv) {
    const char *const short_opts = "s:h";
    const option long_opts[] = {{"seed", required_argument, nullptr, 's'},
                                {"help", no_argument, nullptr, 'h'},
                                {nullptr, no_argument, nullptr, 0}};

    while (true) {
        const auto opt = getopt_long(argc, argv, short_opts, long_opts, nullptr);

        if (-1 == opt) break;

        switch (opt) {
        case 's':
            seed = std::stoi(optarg);
            use_seed = true;
            std::cout << "Seed set to: " << seed << std::endl;
            break;

        case 'h':
        case '?':
        default:
            help();
            break;
        }
    }
}

int main(int argc, char **argv) {
    Vwt_mult dut;
    VerilatedFstC m_trace;

    Verilated::traceEverOn(true);
    dut.trace(&m_trace, 5);
    m_trace.open("waveform.fst");

    dut_ptr = &dut;
    trace_ptr = &m_trace;

    signal(SIGINT, signal_handler);

    cmdArgs(argc, argv);
    std::mt19937 generator;
    std::uniform_int_distribution<in_t> distr(0, MAX);
    if (use_seed) {
        generator.seed(seed);
    } else {
        std::random_device rand_dev;
        generator.seed(rand_dev());
    }

    auto tstart = std::chrono::high_resolution_clock::now();

    reset(dut, m_trace);

    uint64_t expected = 0;
    uint64_t received = 0;
    uint64_t test_vec_as_uint = 0;
    uint64_t a = 0;
    uint64_t b = 0;

    std::queue<test_vector_t> tests;

    while (sim_time < MAX_SIM_TIME) {
        dut.ready = 0;
        dut.a = 0;
        dut.b = 0;

        // Create a new test vector
        test_vector_t test;
        test.a = distr(generator);
        test.b = distr(generator);
        if (SIGNED) {
            test.expected = (out_t)SEXT(test.a) * (out_t)SEXT(test.b);
        } else {
            test.expected = (out_t)test.a * (out_t)test.b;
        }
        test.start_cycle = sim_time;
        test.end_cycle = sim_time + (2 * dut.wt_mult_pkg->wt_delay(WIDTH, SIGNED, STAGE_DEPTH,
                                                                   MERGE_PROD_GEN_REDUCE_STAGES,
                                                                   MERGE_REDUCE_FINAL_STAGES));
        tests.push(test);
        dut.a = test.a;
        dut.b = test.b;
        dut.ready = 1;

        // If the DUT is done then check the top vector
        if (tests.size() > 0 && sim_time >= tests.front().end_cycle) {
            test_vector_t front = tests.front();
            tests.pop();
            out_t out = cast_out<out_t, decltype(dut.out)>(dut.out);
            check(front.expected & max_n_bit(WIDTH * 2), out, front.a, front.b);
        }

        tick(dut, m_trace);
    }

    auto tend = std::chrono::high_resolution_clock::now();

    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(tend - tstart);

    if (passed_tests) {
        std::cout << "PASSED ALL " << num_passed << " TESTS" << std::endl;
    } else {
        std::cout << "FAILING TESTS" << std::endl;
    }

    std::cout << "Simulated " << std::dec << cycles << " cycles in " << ms.count() << "ms"
              << ", rate of " << (float)cycles / ((float)ms.count() / 1000.0)
              << " cycles per second." << std::endl;

    m_trace.close();
    dut.final();

    return !passed_tests;
}
