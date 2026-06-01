#pragma once

#include <atomic>
#include "UARTDataBuffer.hh"

void tcp_server(UARTDataBuffer& rx_buf, UARTDataBuffer& tx_buf, const char *port, std::atomic_bool&);