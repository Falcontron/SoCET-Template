#include <cstdint>

#include "Packet.hh"
#include "PacketParser.hh"
#include "Protocol.hh"

#include "format.h"

extern "C" void entry_point(uint32_t addr);

Packet Protocol::execute_command_packet(Packet& packet) {
    dprint("Protocol:\n");
    packet.dump();
    switch(packet.command()) {
        case Commands::Address: {
            if(packet.data_length() < 4) {
                return Packet::error(ResponseCode::ProtocolError);
            }

            address = 0;
            auto datap = packet.data_begin();
            for(auto i = 0; i < 4; i++) {
                address |= (*datap << (8*i));
                ++datap;
            }

            dprint("Address = %x", address);

            return Packet::ack();
        } break;

        case Commands::Read32: {
            if((address & 0x3) != 0) {
                return Packet::error(ResponseCode::AddressError);
            }

            dprint("Reading address %x\n", address);
            auto response = Packet::ack();
            uint32_t *ptr = (uint32_t *)address;
            uint32_t value = *ptr;
            for(auto i = 3; i >= 0; i--) {
                response.append_data((value >> (8*i)) & 0xFF);
            }

            return response;
        } break;

        case Commands::Write32: {
            if((address & 0x3) != 0) {
                return Packet::error(ResponseCode::AddressError);
            }
            auto response = Packet::ack();
            uint32_t *ptr = (uint32_t *)address;
            uint32_t value = 0;
            auto datap = packet.data_begin();
            for(auto i = 0; i < 4; i++) {
                value |= (*datap << (8*i));
                ++datap;
            }

            *ptr = value;
            return response;
        } break;

        case Commands::ReadN: {
            // READN/WRITEN: First data byte is # of bytes to return
            // Must be <= 63
            auto datap = packet.data_begin();
            auto response = Packet::ack();
            uint8_t *ptr = (uint8_t *)address;
            auto n = *datap;
            datap++;
            for(auto i = 0; i < n; i++) {
                response.append_data(ptr[i]);
            }

            return response;
        } break;

        case Commands::WriteN: {
            auto n = packet.data_length();
            auto datap = packet.data_begin();
            uint8_t *ptr = (uint8_t *)address;
            for(auto i = 0; i < n; i++) {
                dprint("%x = %x\n", &ptr[i], datap[i]);
                ptr[i] = datap[i];
            }

            return Packet::ack();
        } break;

        case Commands::Jump: {
            if((address & 0x1) != 0) { // RV32C alignment OK
                return Packet::error(ResponseCode::AddressError);
            }
            enter_program = true;
            return Packet::ack();
        } break;

        case Commands::Alive: {
            auto response = Packet::error(ResponseCode::Message);
            response.append_data('A');  // static message for Alive response
            return response;
        }

        default: return Packet::error(ResponseCode::UnknownCommand);
    }

    dprint("Protocol: cmd success\n");
}

[[noreturn]] void Protocol::enter_protocol(PacketParser& parser) {
    while(1) {
        auto packet = parser.next_incoming();
        if(!packet.is_valid()) {
            dprint("Invalid packet\n");
            auto response = Packet::error(ResponseCode::ProtocolError);
            parser.send(std::move(response));
            continue;
        } else if(!packet.check_crc()) {
            dprint("CRC Failure\n");
            auto response = Packet::error(ResponseCode::CrcError);
            parser.send(std::move(response));
            continue;
        }

        auto response = execute_command_packet(packet);
        dprint("Sending response\n");
        parser.send(std::move(response));

        if(enter_program) {
            //entry_point(address);
            asm volatile("jr %0" : : "r"(address));
        }
    }
}
