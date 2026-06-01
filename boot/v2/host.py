import alive_progress
import argparse
import colorama
from colorama import Fore, Style
import socket
import abc
import time
import pycrc.algorithms
import serial
import more_itertools
import readline
import os

#DEFAULT_HOST = "localhost"
DEFAULT_HOST="/dev/tty.usbserial-A50285BI"
DEFAULT_PORT = 7777
DEFAULT_BAUD = 9600

debug = False
status = 0
max_attempts = 5

def dprint(msg):
    if (debug):
        print(f"[DEBUG]: {msg}")

class Sender(abc.ABC):
    @abc.abstractmethod
    def send_bytes(self, bytes):
        pass

    @abc.abstractmethod
    def recv_bytes(self):
        pass

class TCPSender(Sender):
    def __init__(self, sock: socket.socket):
        self.sock = sock
        super().__init__()

    def send_bytes(self, bytes):
        self.sock.send(bytes)

    def recv_bytes(self):
        return self.sock.recv(256)


class SerialSender(Sender):
    def __init__(self, ser: serial.Serial):
        self.ser = ser
        super().__init__()

    def send_bytes(self, bytes):
        self.ser.write(bytes)

    def recv_bytes(self):
        return self.ser.read_until(b'\xFD')


class Packet:
    PACKET_END = 0xFD
    PACKET_START = 0xFC
    PACKET_ESC = 0xFE

    RESPONSE_ACK = 0xAF
    RESPONSE_UNKCMD = 0xA0
    RESPONSE_UARTERR = 0xA2
    RESPONSE_PROTERR = 0xA3
    RESPONSE_CRCERR = 0xA4
    RESPONSE_TIMEOUT = 0xA5
    RESPONSE_EXCINFO = 0xAD
    RESPONSE_MSG = 0xAE

    def __init__(self, cmd, data: bytearray):
        self.cmd = cmd
        self.data = data

    def _needs_esc(v):
        return v == Packet.PACKET_END or v == Packet.PACKET_START or v == Packet.PACKET_ESC

    def to_bytes(self) -> bytearray:
        assert(len(self.data) < 60)
        stream = bytearray()
        stream.append(self.cmd)
        stream.append(len(self.data))
        stream += self.data

        crc = pycrc.algorithms.Crc(width=8, poly=0x07, reflect_in=False,
                                   reflect_out=False,
                                   xor_in=0x0, xor_out=0x0)

        crc_value = crc.bit_by_bit(stream)
        #print(crc_value)
        stream.append(crc_value)

        # Rebuild stream with escape characters stuffed, start/end
        final = bytearray()
        final.append(Packet.PACKET_START)
        for item in stream:
            if Packet._needs_esc(item):
                final.append(Packet.PACKET_ESC)
            final.append(item)

        final.append(Packet.PACKET_END)

        return final

    @classmethod
    def from_bytes(cls, packet: bytearray):
        assert(packet[0] == Packet.PACKET_START)
        assert(packet[-1] == Packet.PACKET_END)
        data_length = packet[2]
        data = bytearray()
        i = 3
        while i < len(packet) - 2:
            if (packet[i] == Packet.PACKET_ESC):
                i += 1
            data.append(packet[i])
            i += 1

        assert(data_length == len(data))

        # TODO: check crc
        return cls(packet[1], data)
    
    def is_ack(self):
        return self.cmd == Packet.RESPONSE_ACK

    def __str__(self):
        code = self.cmd
        if (code == Packet.RESPONSE_ACK):
            return "Successful packet"
        elif (code == Packet.RESPONSE_UNKCMD):
            return "[ERROR]: Unknown command"
        elif (code == Packet.RESPONSE_UARTERR):
            return "[ERROR]: UART error"
        elif (code == Packet.RESPONSE_PROTERR):
            return "[ERROR]: Protocol error"
        elif (code == Packet.RESPONSE_CRCERR):
            return "[ERROR]: CRC error"
        elif (code == Packet.RESPONSE_TIMEOUT):
            return "[ERROR]: Timeout error"
        elif (code == Packet.RESPONSE_EXCINFO):
            return "[ERROR]: Exception error"
        elif (code == Packet.RESPONSE_MSG):
            return "Message sent"

class Protocol:
    COMMAND_ADDRESS = 0x0
    COMMAND_READ32 = 0x1
    COMMAND_WRITE32 = 0x2
    COMMAND_READN = 0x3
    COMMAND_WRITEN = 0x4
    COMMAND_JUMP = 0x5

    def __init__(self, sender: Sender):
        self.sender = sender

    def wait_for_packet(self):
        packet = bytearray()
        while (True):
            # TODO: recv_bytes can return None. Is it possible here?
            packet += self.sender.recv_bytes()
            if (packet[-1] == Packet.PACKET_END and packet[-2] != Packet.PACKET_ESC):
                break
        dprint("Finished receiving packet")
        return Packet.from_bytes(packet)

    def complete_interaction(self, packet: Packet):
        dprint("Completing interaction")
        while (True):
            self.sender.send_bytes(packet.to_bytes())
            dprint("Sleeping")
            #time.sleep(0.1)
            dprint("Woke up!")
            response = self.wait_for_packet()
            if (response.cmd == Packet.RESPONSE_ACK):
                dprint("Finished completing interaction")
                return response
            elif (response.cmd == Packet.RESPONSE_EXCINFO):
                dprint(f"EXCEPTION ENCOUNTERED: {response.data}")
                return response

    def set_addr(self, addr):
        data = bytearray()
        for i in range(0, 4):
            data.append(addr & 0xFF)
            addr >>= 8

        packet = Packet(Protocol.COMMAND_ADDRESS, data)

        return self.complete_interaction(packet)

    def read32(self):
        packet = Packet(Protocol.COMMAND_READ32, bytearray())
        return self.complete_interaction(packet)

    def write32(self, value):
        data = bytearray()
        for i in range(0, 4):
            data.append(value & 0xFF)
            value >>= 8
        packet = Packet(Protocol.COMMAND_WRITE32, data)
        return self.complete_interaction(packet)

    def readN(self, n):
        data = bytearray()
        data.append(n)
        packet = Packet(Protocol.COMMAND_READN, data)
        return self.complete_interaction(packet)

    def writeN(self, bytes: bytearray):
        packet = Packet(Protocol.COMMAND_WRITEN, bytes)
        return self.complete_interaction(packet)

    def jump(self):
        packet = Packet(Protocol.COMMAND_JUMP, bytearray())
        return self.complete_interaction(packet)

test_program = bytearray((
    b'\xb7\x02\x00\xb0' # lui t0, 0xb0000
    + b'\x13\x03\xa0\x03' # li t1, 58
    + b'\x93\x03\x90\x02' # li t2, 41
    + b'\x29\x4e' # li t3, \n
    + b'\x23\x80\x62\x00' # sw t0, 0(t0)
    + b'\x23\x80\x72\x00' # sw t2, 0(t0)
    + b'\x23\x80\xc2\x01' # sw t3, 0(t0)
    + b'\x01\xa0' # j 0
))


# Commands
# program [addr] [file]: Write contents of [file] starting at [addr], verifying after each chunk
# enter [addr]: Jump to [addr]
def program(protocol: Protocol, address: int, file_name: str):
    try:
        with open(file_name, "rb") as bin_file:
            bin = bin_file.read()
            chunk_address = address
            nchunks = sum([1 for _ in more_itertools.chunked(bin, 58)])
            with alive_progress.alive_bar(len(bin) // 58 + 1) as bar:
                for chunk in more_itertools.chunked(bin, 58):
                    protocol.set_addr(chunk_address)
                    chunk_ok = False
                    bar.text('Sending chunk...')
                    i = 0
                    while i < max_attempts:
                        chunk = bytearray(chunk)
                        resp = protocol.writeN(chunk)
                        if not resp.is_ack():
                            # Retry write
                            bar.text(f"Write: error, retrying...({i}/{max_attempts})")
                            i += 1
                            continue
                    
                        bar.text('Verify chunk...')
                        verif = protocol.readN(len(chunk))
                        if not verif.is_ack():
                            bar.text(f"Read: error, retrying...({i}/{max_attempts})")
                            i += 1
                            continue
                        elif (verif.data != chunk):
                            #dprint(f"[ERROR]: Unable to verify data!\nWanted:\t{chunk}\nFound:\t{verif.data}")
                            top = str()
                            bottom = str()
                            for (recv, expect) in zip(chunk, verif.data):
                                if recv != expect:
                                    top += f'{Fore.RED}'
                                    bottom += f'{Fore.RED}'
                                
                                top += f'{recv:02x} '
                                bottom += f'{expect:02x} '
                                top += f'{Style.RESET_ALL}'
                                bottom += f'{Style.RESET_ALL}'

                            print(f"Expected:\n{top}\nReceived:\n{bottom}")
                            bar.text(f"Failed verification, retrying...({i}/{max_attempts})")
                            i += 1
                        else:
                            break
                    
                    if i == max_attempts:
                        status = 1
                        print("Failed to program device: maximum attempts reached")
                        return
                    
                    chunk_address += len(chunk)
                    bar()
    except FileNotFoundError:
        print(f"Could not open {file_name} to read!")
        status = 1
        return

    status = 0
    

def enter(protocol: Protocol, address: int):
    protocol.set_addr(address)
    protocol.jump()


def help() -> str:
    help_str = """\
Commands:
program [addr] [file]: Write contents of [file] starting at [addr], verifying after each chunk
enter [addr]: Jump to [addr]
"""
    return help_str

def read32(protocol: Protocol, address: int) -> (int):
    protocol.set_addr(address)
    result = protocol.read32()
    if (result.is_ack()):
        return int.from_bytes(result.data, "little")
    else:
        print(f"Error reading from {address}: {result}")
        status = 1
        return None

def write32(protocol: Protocol, address: int, data: int):
    protocol.set_addr(address)
    result = protocol.write32(data)
    if (result.is_ack()):
        status = 0
        return
    else:
        print(f"Error writing to {address}: {result}")
        status = 1

def completer(text, state):
    options = [i for i in ["program", "enter", "quit", "help"] if i.startswith(text)]
    if state < len(options):
        return options[state]
    else:
        return None


def main(sender: Sender):
    global debug


    protocol = Protocol(sender)

    colorama.init()
    histfile = os.path.join(os.path.expanduser("~"), ".aftx07_history")

    readline.set_history_length(100)
    try:
        readline.read_history_file(histfile)
    except FileNotFoundError:
        pass

    readline.parse_and_bind("tab: complete")
    readline.set_completer(completer)

    while (True):
        if status == 0:
            prompt = f"{Fore.GREEN}>> {Style.RESET_ALL}"
        else:
            prompt = f"{Fore.RED}>> {Style.RESET_ALL}"
        
        command = input(prompt)
        words = command.split()
        if (len(words) == 0):
            continue
    
        if (words[0] == "program"):
            if(len(words) != 3):
                print("Invalid number of arguments for program")
                continue
            
            filename = words[2]
            try:
                address = int(words[1], base=16)
            except ValueError:
                print(f"Could not parse {words[1]} into an integer")
                continue
            
            program(protocol, address, words[2])
        
        elif (words[0] == "enter"):
            if(len(words) != 2):
                print("Invalid number of arguments for enter")
                continue
        
            try:
                address = int(words[1], base=16)
            except ValueError:
                print(f"Could not parse {words[1]} into an integer")
                continue
            
            enter(protocol, address)
        
        elif (words[0] == 'read32'):
            if(len(words) != 2):
                print("Invalid number of arguments for read32")
                continue
        
            try:
                address = int(words[1], base=16)
            except ValueError:
                print(f"Could not parse {words[1]} into an integer")
                continue
            
            result = read32(protocol, address)
            if result is not None:
                print(f"Received: {result:08x}")
        
        elif (words[0] == 'write32'):
            if(len(words) != 3):
                print("Invalid number of arguments for write32")
                continue
            try:
                address = int(words[1], base=16)
            except ValueError:
                print(f"Could not parse {words[1]} into an integer")
                continue
            
            try:
                data = int(words[2], base=16)
            except ValueError:
                print(f"Could not parse {words[2]} into an integer")
                continue
            
            write32(protocol, address, data)
        
        elif (words[0] == 'quit'):
            break
        elif (words[0] == 'help'):
            print(help())
        else:
            print(f"Unknown command '{command}'")

    readline.write_history_file(histfile)


        #command = input(">> ")
#         command = readline.readline(">> ")
#         if (command.startswith("address ")):
#             address = command[len("address "):]
#             try:
#                 address = int(address, 0)
#                 protocol.set_addr(address)
#             except ValueError:
#                 print(f"Could not parse {address} into an integer")
#         elif (command.startswith("read32")):
#             packet = protocol.read32()
#             print(f"Received:\n{packet.data}")
#         elif (command.startswith("write32 ")):
#             data = command[len("write32 "):]
#             try:
#                 data = int(data, 0)
#                 protocol.write32(data)
#             except ValueError:
#                 print(f"Could not parse {data} into an integer")
#         elif (command.startswith("readn ")):
#             length = command[len("readn "):]
#             try:
#                 data = int(length, 0)
#                 packet = protocol.readN(data)
#                 print(f"Received:\n{packet.data}")
#             except ValueError:
#                 print(f"Could not parse {length} into an integer")
#         elif (command.startswith("writen ")):
#             file_name = command[len("writen "):]
#             try:
#                 with open(file_name, "rb") as bin_file:
#                     bin = bin_file.read()
#                     chunk_address = address
#                     for i, chunk in enumerate(more_itertools.chunked(bin, 59)):
#                         print(f"Sending chunk {i} of {len(bin)//59}")
#                         protocol.set_addr(chunk_address)
#                         chunk_ok = False;
#                         while not chunk_ok:
#                             chunk = bytearray(chunk)
#                             protocol.writeN(chunk)
#                             verif = protocol.readN(len(chunk))
#                             if (verif.data != chunk):
#                                 print(f"[ERROR]: Unable to verify data!\nWanted:\t{chunk}\nFound:\t{verif.data}")
#                             else:
#                                 chunk_ok = True
#                         chunk_address += len(chunk)
#                         print(f"Finished sending chunk {i} of {len(bin)//59}")
#                         protocol.set_addr(address)
#             except FileNotFoundError:
#                 print(f"Could not open {file_name}!")
#         elif (command.startswith("send ")):
#             bytes_str = command[len("send "):]
#             try:
#                 for byte in bytes_str.split():
#                     print(f"{byte}")
#                     b = int(byte, 0)
#                     print(f"{b}")
#                     sender.send_bytes(b.to_bytes(1, "little"))
#                     dprint(f"Sent {b}")
#             except ValueError:
#                 print(f"Could not parse {address} into an integer")
#         elif (command.startswith("jump")):
#             protocol.jump()
#         elif (command.startswith("debug ")):
#             bool_val = command[len("debug "):].lower()
#             str_bools = {True: ["1", "on", "true"], False: ["0", "off", "false"]}
#             if bool_val in str_bools[True] or bool_val in str_bools[False]:
#                 debug = bool_val in str_bools[True]
#             else:
#                 print(f"Could not parse {bool_val} into an boolean")
#         elif (command.startswith("quit")):
#             break
#         elif (command.startswith("help")):
#             print("""\
# address [addr]: Sets address to [addr]
# read32: Reads 32 bits from [addr]
# write32 [data]: Writes [data] (lower 32 bits) to [addr]
# readn [length]: Reads [length] bytes from [addr]
# writen [file]: Writes N bytes from [file] to addr
# send [bytes]: Send [bytes] as a sequence of space separated bytes
# jump: Triggers jump to [addr]
# debug [bool]: Sets whether debug messages are printed. Accepts bool-like values (0,1,true,false)
# quit: Quit
# help: Show this message\
# """)
#         else:
#             print(f"Unknown command {command}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        prog="AFTx07 Programmer",
        description="Programs AFTx07 via UART",
        
        epilog="SoCET Fall 2023"
    )

    parser.add_argument('--tcp', action="store_true", help="Use TCP instead of serial. Intended for testing with RTL simulator")
    parser.add_argument('--port', type=int, default=DEFAULT_PORT, help=f"Port to connect to. Ignored if --tcp is not specified. Default: {DEFAULT_PORT}")
    parser.add_argument('--host', type=str, default=DEFAULT_HOST, help=f"Host to connect to. Ignored if --tcp is not specified. Default: {DEFAULT_HOST}")
    parser.add_argument('--serial', type=str, help="Serial port to connect to. Ignored if --tcp is specified.")
    parser.add_argument('--baud', type=int, default=DEFAULT_BAUD, help=f"Baud rate to use. Ignored if --tcp is specified. Default: {DEFAULT_BAUD}")
    parser.add_argument('--max-attempts', type=int, default=5, help=f"Number of attempts to retry sending a packet for program/verify. Default: {max_attempts}")
    parser.add_argument('--verbose', action="store_true", help="Print debug messages")

    args = parser.parse_args()


    max_attempts = args.max_attempts

    if args.verbose:
        debug = True
    
    if args.tcp:
        print(f"Connecting to {args.host}:{args.port}")
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.connect((args.host, args.port))
            main(TCPSender(s))
    else:
        if not args.serial:
            print("Serial port not specified!")
            exit(1)
        
        print(f"Connecting to {args.serial} at {args.baud} baud")
        with serial.Serial(args.serial, args.baud) as s:
            main(SerialSender(s))
        
