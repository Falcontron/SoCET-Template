#include <cstdint>

#include "Packet.hh"
#include "PacketParser.hh"
#include "BufferedUART.hh"

#include "riscv.hh"

/// Warning: "field" MUST not have side-effects!
#define PACKET_CHECK(field) \
    if((field) == PKT_START) {  \
        bad_packet = true;      \
        dprint("Unexpected START\n"); \
        goto exit;              \
    } else if((field) == PKT_END) { \
        bad_packet = true;          \
        dprint("Unexpected END\n");  \
        uart.get_byte();            \
        goto exit;                  \
    } else if((field) == PKT_ESC) { \
        dprint("ESC: Advancing\n"); \
        uart.get_byte();            \
    }                               \
    (field) = uart.get_byte();

void PacketParser::send_sym_escaped(uint8_t sym) {
    if(sym == PKT_ESC || sym == PKT_START || sym == PKT_END) {
        uart.send_byte(PKT_ESC);
    }
    uart.send_byte(sym);
}

uint8_t PacketParser::recv_sym_escaped() {
    auto byte = uart.get_byte();
    if(byte == PKT_ESC) {
        byte = uart.get_byte();
    }

    return byte;
}

Packet PacketParser::next_incoming() {

    bool bad_packet = false;
    Packet packet;
    CLINT *clint = (CLINT *)CLINT_BASE;
    const uint64_t cycles_per_second = CPU_MHZ*1000000;

    // Set timer

    dprint("Start\n");
    // New strategy: Wait for a start byte
    while((packet.start = uart.get_byte()) != PKT_START);
    uint64_t mtime = (uint64_t)clint->mtime | ((uint64_t)clint->mtimeh << 32);
    mtime += cycles_per_second;
    clint->mtimecmph = (uint32_t)(mtime >> 32);
    clint->mtimecmp = (uint32_t)(mtime & 0xFFFFFFFF);

    // packet.start = uart.get_byte();
    // if(packet.start != PKT_START) {
    //     dprint("Did not get START\n");
    //     bad_packet = true;
    //     goto exit;
    // }

    dprint("Code\n");
    packet.code = uart.peek_byte();
    PACKET_CHECK(packet.code);

    dprint("len\n");
    packet.data_len = uart.peek_byte();
    PACKET_CHECK(packet.data_len);
    if(packet.data_len > 64) {
        bad_packet = true;
    }

    // If data_len is too high, we still need to consume
    // the entire bad packet. Mask the index so we don't
    // overflow.
    for(int i = 0; i < packet.data_len; i++) {
        dprint("Data %d\n", i);
        packet.data_buffer[(i & 0x3F)] = uart.peek_byte();
        PACKET_CHECK(packet.data_buffer[(i & 0x3F)]);
    }

    dprint("crc\n");
    packet.crc = uart.peek_byte();
    PACKET_CHECK(packet.crc);

    dprint("end\n");
    packet.end = uart.get_byte();
    if(packet.end != PKT_END) {
        bad_packet = true;
        dprint("Did not get END\n");
    }

exit:
    dprint("Returning packet\n");
    clint->mtimecmph = 0xFFFFFFFF;
    clint->mtimecmp = 0xFFFFFFFF;
    packet.valid = !bad_packet;
    return packet;
}

void PacketParser::send(Packet&& p) {
    p.set_crc();
    uart.send_byte(p.start);
    send_sym_escaped(p.code);
    send_sym_escaped(p.data_len);
    for(auto i = 0; i < p.data_len; i++) {
        send_sym_escaped(p.data_buffer[i]);
    }
    send_sym_escaped(p.crc);
    uart.send_byte(p.end);
}
