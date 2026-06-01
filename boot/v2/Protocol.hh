#pragma once

#include <cstdint>

#include "BufferedUART.hh"
#include "PacketParser.hh"
#include "Packet.hh"

class Packet;
class PacketParser;

class Protocol {
    uint32_t address;
    bool enter_program;
    typedef void (*entry_t)();

public:
    enum class Commands {
        Address = 0,
        Read32 = 1,
        Write32 = 2,
        ReadN = 3,
        WriteN = 4,
        Jump = 5,
        Alive = 6,
        Unknown
    };

    enum class ResponseCode {
        UnknownCommand = 0xA0,
        AddressError = 0xA1,
        UartError = 0xA2,
        ProtocolError = 0xA3,
        CrcError = 0xA4,
        TimeoutError = 0xA5,
        ExceptionInfo = 0xAD,
        Message = 0xAE,
        Ack = 0xAF
    };

private:
    Packet execute_command_packet(Packet& packet);

public:
    Protocol() : address(0), enter_program(false) {}
    [[noreturn]] void enter_protocol(PacketParser& parser);
};

