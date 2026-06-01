
#include "BufferedUART.hh"
#include "PacketParser.hh"
#include "Packet.hh"
#include "Protocol.hh"

#include "format.h"
#include "riscv.hh"

#define SRAM_BASE (0x20000)
#define BAUD_RATE (115200)

extern "C" void entry_point(uint32_t);
extern "C" void boot();


// NOTE: We can't assume that we're
// here during the bootloader, since
// an exception with unset mtvec by app
// will come here. We can't assume the 
// stack is OK either (could be an exception explicitly
// from bad stack use). Need to reinitialize.
extern "C" void __attribute__((used)) send_exc_state() {
    dprint("Exception.\n");

    uint32_t exc_data[3];
    BufferedUART uart(BAUD_RATE);
    PacketParser parser(uart);
    //Packet data = Packet::error(Protocol::ResponseCode::ExceptionInfo);
    auto code = Protocol::ResponseCode::ExceptionInfo;

    asm volatile(
        "csrr %0, mepc\n"
        "csrr %1, mcause\n"
        "csrr %2, mtval\n"
        : "=r"(exc_data[0]), "=r"(exc_data[1]), "=r"(exc_data[2])
    );

    Packet data = Packet::ack();
    CLINT *clint = (CLINT *)CLINT_BASE;
    clint->mtimecmph = 0xFFFFFFFF;
    clint->mtimecmp = 0xFFFFFFFF;
    // Timer expired
    data = Packet::error(code);
    for(auto i = 0; i < 3; i++) {
        auto v = exc_data[i];
        for(auto j = 0; j < 4; j++) {
            data.append_data(v & 0xFF);
            v >>= 8;
        }
    }
    
    parser.send(std::move(data));
}

void __attribute__((naked)) __attribute__((aligned(4))) handler() {
    asm volatile(
        ".extern send_exc_state\n"
        ".option push\n"
        ".option norelax\n"
        "la sp, __stack_top\n"
        "la gp, __global_pointer$\n"
        "jal send_exc_state\n"
        "csrw mepc, 0\n"
        "csrw mie, 0\n"
        "csrw mstatus, 0\n"
        "j boot\n"
        ".option pop\n"
        //: : "r"(boot)
    );
}

extern "C" [[noreturn]] void __attribute__((used)) main() {
    dprint("Start.");


    volatile uint32_t *gpio_data = (volatile uint32_t *)0x80000000;
    if((*gpio_data & 1) != 0) {
        entry_point(SRAM_BASE);
    }

    CLINT *clint = (CLINT *)CLINT_BASE;
    clint->mtimecmph = 0xFFFFFFFF;
    clint->mtimecmp  = 0xFFFFFFFF;


    // Set up exception CSRs
    asm volatile(
        "csrw mtvec, %0\n"
        "csrw mie, %1\n"
        "csrw mstatus, %2\n"
        : : "r"(handler), "r"(0x80), "I"(0x8)
    );

    BufferedUART uart(BAUD_RATE);
    PacketParser parser(uart);

    // Send startup/hello packet
    Packet data = Packet::error(Protocol::ResponseCode::Message);
    data.append_data('B');  // static message for (re)Boot
    parser.send(std::move(data));

    Protocol protocol;
    protocol.enter_protocol(parser);

    for(;;) {
        asm volatile("wfi");
    }
}
