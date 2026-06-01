import sys
import os
import argparse
import binascii
import subprocess


sv_header = \
"""
module rom(
    bus_protocol_if.peripheral_vital busif
);
    localparam ADDR_MAX = {};
    assign busif.request_stall = 0;
    assign busif.error = (busif.wen || (busif.addr >> 2) >= ADDR_MAX);
    logic [31:0] pre_swap;
    assign busif.rdata = bswap32(pre_swap);

    always_comb begin
        casez(busif.addr >> 2)
"""

sv_footer = \
"""
            default: pre_swap = 32'hBAD1BAD1;
        endcase
    end

    function logic [31:0] bswap32(input [31:0] data);
        return {data[7:0], data[15:8], data[23:16], data[31:24]};
    endfunction
endmodule
"""

subprocess.run(["make", "-C", "./v3"])

with open('v3/meminit.bin', 'rb') as fp:
    data = bytearray(fp.read())
    size = len(data)
    out = sv_header.format((size // 2) + 1)

    # TODO: Does this need to be fixed?
    while size % 4 != 0:
        data.append(0)
        size = len(data)

    chunks = [data[i:i+4] for i in range(0, len(data), 4)]
    addr_count = 0

    for chunk in chunks:
        st = binascii.hexlify(chunk)
        st = st.decode()
        st = "32'h" + st
        line = f"'h{addr_count:x}: pre_swap = {st};\n"
        out += line
        addr_count += 1
    
    out += sv_footer

with open("rom.sv", "w") as fp:
    fp.write(out)
