#pragma once

#include <cstdint>
#include <fstream>
#include <iostream>
#include <map>
#include <sstream>

class MemoryMap {
    private:
        const uint32_t c_default_value = 0xBAD1BAD1;
        const char *dumpfile = "memsim.dump";
        std::map<uint32_t, uint32_t> mmap;
    
    protected:
        inline uint32_t expand_mask(uint8_t mask) {
            uint32_t acc = 0;
            for(int i = 0; i < 4; i++) {
                auto bit = ((mask & (1 << i)) != 0);
                if(bit) {
                    acc |= (0xFF << (i * 8));
                }
            }
    
            return acc;
        }
    
    public:
    
        MemoryMap(const char *fname) {
            uint32_t address = 0x8400;
            std::ifstream myFile(fname, std::ios::in | std::ios::binary);
            if(!myFile) {
                std::ostringstream ss;
                ss << "Couldn't open " << fname << std::endl;
                std::cout << ss.str();
                throw ss.str();
            }
    
            while(!myFile.eof()) {
                uint32_t data;
                myFile.read((char *)&data, sizeof(data));
    
                mmap.insert(std::make_pair(address, data));
    
                address += 4;
            }
        }
    
        uint32_t read(uint32_t addr) {
            auto it = mmap.find(addr);
            if(it != mmap.end()) {
                return __builtin_bswap32(it->second);
            } else {
                return c_default_value;
            }
        }
    
        void write(uint32_t addr, uint32_t value, uint8_t mask) {
            #ifdef DEBUG_MODE
            std::cout << "Write [" << std::hex << addr << "] = " << __builtin_bswap32(value) << "(Mask " << (uint32_t)mask << ")" << std::dec << std::endl;
            #endif
            // NOTE: For now, assuming that all memory is legally acessible.
            if(addr == 0x20000) {
                uint32_t swapped = __builtin_bswap32(value);
                switch(mask) {
                    // 1-byte
                    case 0x1: std::cout << (char)((swapped >> 24)& 0xFF);
                        break;
                    case 0x2: std::cout << (char)((swapped >> 16) & 0xFF);
                        break;
                    case 0x4: std::cout << (char)((swapped >> 8) & 0xFF);
                        break;
                    case 0x8: std::cout << (char)((swapped >> 0) & 0xFF);
                        break;
                    // 2-byte
                    case 0x3: std::cout << std::hex << ((uint16_t)(swapped >> 16) & 0xFFFF) << std::dec << std::endl;
                        break;
                    case 0xC: std::cout << std::hex << ((uint16_t)swapped & 0xFFFF) << std::dec << std::endl;
                        break;
                    case 0xF: std::cout << std::hex << ((uint32_t)swapped) << std::dec << std::endl;
                }
            } else {
                // TODO: This masking doesn't seem right
                auto it = mmap.find(addr);
                if(it != mmap.end()) {
                    auto mask_exp = expand_mask(mask);
                    it->second = __builtin_bswap32(value & mask_exp) | __builtin_bswap32(__builtin_bswap32(it->second) & ~mask_exp);
                } else {
                    mmap.insert(std::make_pair(addr, __builtin_bswap32(value)));
                }
            }
        }
    
        void dump() {
            std::ofstream outfile;
            outfile.open(dumpfile);
            if(!outfile) {
                std::ostringstream ss;
                ss << "Couldn't open " << dumpfile << std::endl;
                throw ss.str();
            }
    
            for(auto p : mmap) {
                char buf[80];
                snprintf(buf, 80, "%08x : %02x%02x%02x%02x", p.first, 
                        (p.second & 0xFF000000) >> 24, 
                        (p.second & 0x00FF0000) >> 16, 
                        (p.second & 0x0000FF00) >> 8, 
                        p.second & 0x000000FF);
                outfile << buf << std::endl;
            }
        }
    };
    