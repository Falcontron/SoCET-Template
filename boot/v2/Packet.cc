#include <cstdint>

#include "crc.h"

#include "Packet.hh"
#include "BufferedUART.hh"

uint8_t Packet::compute_crc() {
    crc_t crc;
    crc = crc_init();
    crc = crc_update(crc, &code, 1);
    crc = crc_update(crc, &data_len, 1);
    crc = crc_update(crc, data_buffer.begin(), data_len);
    crc = crc_finalize(crc);
    return (uint8_t)crc;
}

bool Packet::check_crc() {
    return compute_crc() == crc;
}

void Packet::set_crc() {
    crc = compute_crc();
}