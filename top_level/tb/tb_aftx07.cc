#include <atomic>
#include <cerrno>
#include <chrono>
#include <climits>
#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <getopt.h>
#include <iostream>
#include <optional>
#include <thread>
#include <unistd.h>

#include "sim-peripherals/MemoryMap.hh"
#include "sim-peripherals/UARTDataBuffer.hh"
#include "sim-peripherals/UARTSimulator.hh"
#include "sim-peripherals/UARTTcpServer.hh"
#include "util/PlusargsBuilder.hh"
#include "Vaftx07.h"
#include "verilated_fst_c.h"
#include "verilated.h"
#include "version.h"

#define TCP_SERVER_PORT "7777"

uint64_t sim_time = 0;
const unsigned int MILLION = 1000000;
const std::string DEFAULT_HW_FNAME = "firmware.bin";
const std::string DEFAULT_SW_FNAME = "meminit.bin";
const uint64_t DEFAULT_MEM_LATENCY = 0;
const uint64_t PCLK_RATIO = 8;
std::atomic_bool finished = false;
class MemoryMap;

struct TBCfg {
    bool trace_en;
    bool launch_uart_server;
    unsigned long cycle_limit;
    unsigned long trace_start_cycle;
    std::string hw_fname;
    std::string sw_fname;
    unsigned long mem_latency;
    Vaftx07 *dutp;
    MemoryMap *memp;
    VerilatedFstC *tracep;
};

const TBCfg default_config = {
    .trace_en = false,
    .launch_uart_server = false,
    .cycle_limit = 10*MILLION,
    .trace_start_cycle = 0,
    .hw_fname = DEFAULT_HW_FNAME,
    .sw_fname = DEFAULT_SW_FNAME,
    .mem_latency = DEFAULT_MEM_LATENCY,
    .dutp = nullptr,
    .memp = nullptr,
    .tracep = nullptr
};
static UARTDataBuffer tx_buf;
static UARTDataBuffer rx_buf;
static TBCfg config;
static bool no_sim = false;

std::string get_version() {
    return std::string(VERSION_INFO);
}

void print_config(TBCfg& config) {
    std::cout << "Configuration: " << std::endl;
    std::cout << "\tVersion: " << get_version() << std::endl;
    std::cout << "\tTrace: " << ((config.trace_en) ? "Enabled" : "Disabled") << std::endl;
    std::cout << "\tCycle Limit: " << config.cycle_limit << std::endl;
    std::cout << "\tTrace Start: " << config.trace_start_cycle << std::endl;
    std::cout << "\tFirmware Binary File: " << config.hw_fname << std::endl;
    std::cout << "\tSoftware Binary File: " << config.sw_fname << std::endl;
    std::cout << "\tMemory Latency: " << config.mem_latency << std::endl;

    if(config.trace_en && config.cycle_limit > 10 * MILLION) {
        std::cout << "WARNING: Enabling trace leads to extreme slowdown in simulation! Are you sure you want to run for >10M cycles with trace enabled?";
    }
}

void print_help() {
    std::cerr << get_version() << std::endl;
    std::cerr << "Usage: ./Vaftx07 [flags...]" << std::endl;
    std::cerr << "\t--meminit-file: path to binary for simulation" << std::endl;
    std::cerr << "\t--trace-en: Enable FST wave tracing" << std::endl;
    std::cerr << "\t--cycle-limit n: Set cycle count limit to n" << std::endl;
    std::cerr << "\t--trace-start n: Start dumping wave trace after cycle n (ignored if not --trace-en)" << std::endl;
    std::cerr << "\t--mem-latency n: Set simulated memory latency" << std::endl;
    std::cerr << "\t--uart: Open TCP server for listening to UART commands" << std::endl;
    std::cerr << "\t--version: Print the version information" << std::endl;
    std::cerr << "\t--help: Print this" << std::endl;
}

auto parse_cli(int argc, char **argv) -> std::optional<TBCfg> {
    static struct option long_options[] = {
        {"firmware-file",   required_argument,  0, 'f'},
        {"meminit-file",    required_argument,  0, 'm'},
        {"trace-en",        no_argument,        0, 't'},
        {"trace-start",     required_argument,  0, 's'},
        {"cycle-limit",     required_argument,  0, 'c'},
        {"help",            no_argument,        0, 'h'},
        {"uart",            no_argument,        0, 'u'},
        {"version",         no_argument,        0, 'v'},
        {"mem-latency",     required_argument,  0, 'l'},
	{0, 0, 0, 0}
    };

    TBCfg config = default_config;
    int option_index = 0;
    char *endp = NULL;

    for(;;) {
        int c = getopt_long(argc, argv, "f:t:s:c:huv", long_options, &option_index);
        if(c == -1) {
            break;
        }

        switch(c) {
            case '?':
            case 'h':
                no_sim = true;
                print_help();
                return {};
            case 'f':
                config.hw_fname = std::string(optarg);
                break;
            case 'm':
                config.sw_fname = std::string(optarg);
                break;
            case 't':
                config.trace_en = true;
                break;
            case 'l':
                endp = nullptr;
                errno = 0;
                config.mem_latency = std::strtoul(optarg, &endp, 0);
                if(errno == ERANGE) {
                    std::cerr << "Error: Input value " << optarg << " for mem-latency "
                        << " does not fit within an unsigned long" << std::endl;
                    return {};
                } else if(errno == EINVAL) {
                    std::cerr << "Error: Input value " << optarg << " for mem-latency "
                        << " did not have a valid base" << std::endl;
                    return {};
                }
                break;          
            case 's':
                endp = nullptr;
                errno = 0;
                config.trace_start_cycle = std::strtoul(optarg, &endp, 0);
                if(errno == ERANGE) {
                    std::cerr << "Error: Input value " << optarg << " for trace-start "
                        << " does not fit within an unsigned long" << std::endl;
                    return {};
                } else if(errno == EINVAL) {
                    std::cerr << "Error: Input value " << optarg << " for trace-start "
                        << " did not have a valid base" << std::endl;
                    return {};
                }
                break;
            case 'c':
                endp = nullptr;
                errno = 0;
                config.cycle_limit = std::strtoul(optarg, &endp, 0);
                if(errno == ERANGE) {
                    std::cerr << "Error: Input value " << optarg << " for cycle-limit "
                        << " does not fit within an unsigned long" << std::endl;
                    return {};
                } else if(errno == EINVAL) {
                    std::cerr << "Error: Input value " << optarg << " for cycle-limit "
                        << " did not have a valid base" << std::endl;
                    return {};
                }
                break;
            case 'u':
                config.launch_uart_server = true;
                break;
            case 'v':
                no_sim = true;
                std::cout << get_version() << std::endl;
                return {};
        }
    }

    return std::make_optional(std::move(config));
}

void signalHandler(int signum) {
    std::cout << "Got signal " << signum << std::endl;
    std::cout << "Calling SystemVerilog 'final' block & exiting!" << std::endl;

    config.dutp->final();
    config.memp->dump();

    if(config.trace_en) {
        config.tracep->close();
    }

    exit(signum);
}

static uint64_t pclk_counter = 0;

void tick(Vaftx07& dut, VerilatedFstC& trace) {
    dut.HCLK = 0;
    dut.PCLK = (pclk_counter < PCLK_RATIO / 2) ? 0 : 1;
    dut.eval();
    if(config.trace_en && sim_time >= config.trace_start_cycle) trace.dump(sim_time);
    sim_time++;

    dut.HCLK = 1;
    dut.eval();
    if(config.trace_en && sim_time >= config.trace_start_cycle) trace.dump(sim_time);
    sim_time++;

    pclk_counter = (pclk_counter + 1) % PCLK_RATIO;
}

void tick_full_pclk(Vaftx07& dut, VerilatedFstC& trace) {
    // Drain to the next PCLK rising edge first, then do a full PCLK period
    do { 
        tick(dut, trace); 
    } while (pclk_counter != PCLK_RATIO / 2);
    do { 
        tick(dut, trace); 
    } while (pclk_counter != 0);
}

void reset(Vaftx07& dut, VerilatedFstC& trace) {
    dut.ahb_nRST = 0;
    dut.apb_nRST = 0;
    tick_full_pclk(dut, trace);

    dut.ahb_nRST = 1;
    dut.apb_nRST = 1;
    tick_full_pclk(dut, trace);

    dut.ahb_nRST = 0;
    dut.apb_nRST = 0;
    tick_full_pclk(dut, trace);

    dut.ahb_nRST = 1;
    dut.apb_nRST = 1;
    tick_full_pclk(dut, trace);
}


int main(int argc, char **argv) {
    if(auto result = parse_cli(argc, argv)) {
        config = *result;
    } else {
        // don't return EXIT_FAILURE if they just asked for help/version
        return no_sim ? EXIT_SUCCESS : EXIT_FAILURE;
    }
    print_config(config);

    // build plusargs array for modules needing arguments
    auto args = PlusargsBuilder()
                .addOption("firmware", config.hw_fname)
                .addOption("meminit", config.sw_fname)
                .addOption("latency", config.mem_latency)
		.build();
    Verilated::commandArgs(args.size(), args.data());

    std::cout << "Constructing DUT model" << std::endl;
    Vaftx07 dut;
    VerilatedFstC m_trace;
    UARTSimulator uart_sim(rx_buf, tx_buf, 30, 9600);

    config.dutp = &dut;
    config.tracep = &m_trace;

    if(config.trace_en) {
        Verilated::traceEverOn(true);
        dut.trace(&m_trace, 5);
        m_trace.open("waveform.fst");
    }

    auto count = 500;
    auto uart_clk_div = 9540;
    auto uart_bit = 0;
    auto send = 0;
    std::uint16_t uart_bytes = 0;
    std::thread server_thread;

    if(config.launch_uart_server) {
        std::cout << "Starting TCP server on localhost:" << TCP_SERVER_PORT << std::endl;
        server_thread = std::thread([&] {
            tcp_server(rx_buf, tx_buf, TCP_SERVER_PORT, finished);
        });
    }

    // Do this after building everything;
    // if we exit earlier, nothing to clean up
    signal(SIGINT, signalHandler);

    std::cout << "------------------" << std::endl;
    std::cout << " Simulation Begin" << std::endl;
    std::cout << "------------------" << std::endl;


    auto tstart = std::chrono::high_resolution_clock::now();

    reset(dut, m_trace);

    while(!Verilated::gotFinish() && sim_time < config.cycle_limit) {
        tick(dut, m_trace);
        count -= 1;
        if(count == 8) {
            dut.io_mux_to_module_iopad = 0xFF;
        } else if(count == 0) {
            dut.io_mux_to_module_iopad = 0x0;
            count = 10000;
        }

        dut.uart_rx = uart_sim.tick(dut.uart_tx);
    }
    auto tend = std::chrono::high_resolution_clock::now();
    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(tend - tstart);
    std::cout   << "Simulated " << sim_time 
                << " cycles in " << ms.count() << "ms" 
                << ", rate of " << (float)sim_time / ((float)ms.count() / 1000.0) 
                << " cycles per second." << std::endl;

    if(config.trace_en) {
        m_trace.close();
    }

    dut.final();
    finished.store(true);

    if(config.launch_uart_server) {
        server_thread.join();
    }

    return 0;
}
