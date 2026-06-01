#include <cassert>
#include <iostream>

#include "../util/PlusargsBuilder.hh"

void test_basic_option() {
    auto argv = PlusargsBuilder()
        .addOption("clock", 100)
        .build();
    
    assert(argv.size() == 1);
    assert(std::string(argv.data()[0]) == "+clock=100");
    std::cout << "✓ test_basic_option passed\n";
}

void test_flag() {
    auto argv = PlusargsBuilder()
        .addFlag("verbose")
        .build();
    
    assert(argv.size() == 1);
    assert(std::string(argv.data()[0]) == "+verbose");
    std::cout << "✓ test_flag passed\n";
}

void test_chaining() {
    auto argv = PlusargsBuilder()
        .addOption("clock", 100)
        .addFlag("debug")
        .addOption("cycles", 1000)
        .build();
    
    assert(argv.size() == 3);
    assert(std::string(argv.data()[0]) == "+clock=100");
    assert(std::string(argv.data()[1]) == "+debug");
    assert(std::string(argv.data()[2]) == "+cycles=1000");
    std::cout << "✓ test_chaining passed\n";
}

int main() {
    test_basic_option();
    test_flag();
    test_chaining();
    std::cout << "All tests passed!\n";
    return 0;
}
