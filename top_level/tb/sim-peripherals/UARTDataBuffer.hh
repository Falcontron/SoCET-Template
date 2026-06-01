#pragma once

#include <queue>
#include <mutex>

class UARTDataBuffer {
    std::queue<uint8_t> buffer;
    std::mutex data_buffer_mutex;

public:
    UARTDataBuffer() {}
    bool data_avail() {
        std::lock_guard<std::mutex> guard(data_buffer_mutex);
        return (buffer.size() > 0);
    }

    void push(uint8_t value) {
        std::lock_guard<std::mutex> guard(data_buffer_mutex);
        buffer.push(value);
    }

    uint8_t pop() {
        std::lock_guard<std::mutex> guard(data_buffer_mutex);
        auto rv = buffer.front();
        buffer.pop();
        return rv;
    }
};