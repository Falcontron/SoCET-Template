#include "Vcounter.h"
#include "verilated.h"

#include <cstdint>
#include <iostream>

static void tick(Vcounter* dut) {
    dut->clk = 0;
    dut->eval();

    dut->clk = 1;
    dut->eval();
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    auto* dut = new Vcounter;

    dut->clk = 0;
    dut->rst_n = 0;
    dut->en = 0;
    dut->eval();

    tick(dut);
    tick(dut);

    if (dut->count != 0) {
        std::cerr << "FAIL: counter did not reset to 0\n";
        delete dut;
        return 1;
    }

    dut->rst_n = 1;
    dut->en = 1;

    for (int i = 0; i < 5; i++) {
        tick(dut);
    }

    if (dut->count != 5) {
        std::cerr << "FAIL: expected count=5, got count="
                  << static_cast<int>(dut->count) << "\n";
        delete dut;
        return 1;
    }

    std::cout << "PASS: counter test passed\n";

    delete dut;
    return 0;
}