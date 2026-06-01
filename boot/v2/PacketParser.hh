#pragma once

#include <cstdint>

#include "Packet.hh"
#include "BufferedUART.hh"

#define PKT_START 0xFC
#define PKT_END 0xFD
#define PKT_ESC 0xFE

class Packet;

class PacketParser {
    BufferedUART& uart;

    void send_sym_escaped(uint8_t sym);
    uint8_t recv_sym_escaped();
    bool crc_check();

public:
    PacketParser(BufferedUART& uart) : uart(uart) {}
    Packet next_incoming();
    void send(Packet&& p);
};