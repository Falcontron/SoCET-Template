#pragma once

#include <array>
#include <cstdint>
#include <iterator>
#include <optional>

#include "BufferedUART.hh"
#include "Protocol.hh"

#include "format.h"
#include "util.h"

class Packet {

    friend class PacketParser;


    __attribute__((aligned(16))) std::array<uint8_t, 64> data_buffer;
    bool valid;
    uint8_t start;
    uint8_t code;
    uint8_t data_len;
    //uint8_t data_buffer[64];
    uint8_t crc;
    uint8_t end;

    Packet() : valid(false), start(0xFC), code(0xAF), data_len(0), end(0xFD) {}
    uint8_t compute_crc();

public:
    static Packet ack() { return Packet(); }
    static Packet error(Protocol::ResponseCode code) {
        Packet packet;
        packet.code = static_cast<uint8_t>(code);
        packet.data_len = 0;
        packet.crc = 0;

        return packet;
    }

    uint8_t append_data(uint8_t value) {
        data_buffer[data_len] = value;
        data_len += 1;
        return data_len;
    }

    auto data_begin() {
        return data_buffer.begin();
    }

    auto data_end() {
        return data_buffer.end();
    }

    auto data_length() {
        return data_len;
    }

    bool is_valid() { return valid; }
    Protocol::Commands command() {
        if(code < static_cast<uint8_t>(Protocol::Commands::Unknown)) {
            return static_cast<Protocol::Commands>(code);
        }

        return Protocol::Commands::Unknown;
    }

    void dump() {
        dprint("Packet data:\n");
        dprint("\t%x\n\t%x\n\t%x", start, code, data_len);
        for(auto i = 0; i < data_len; i++) {
            if(i % 8 == 0) {
                dprint("\n\t");
            }

            dprint("%x ", data_buffer[i]);
        }
        dprint("\n\t%x\n\t%x\n", crc, end);
    }

    bool check_crc();
    void set_crc();
};