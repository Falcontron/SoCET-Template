import re
import numpy as np

filename_1 = 'dump3.txt'    # disassembly file created by: riscv64-unknown-elf-objdump -d examples/dma_interrupt_test.elf >> dump3.txt
filename_2 = 'inf_loop_trace.log'   # execution trace created by cpu_tracker inside RISCVBUISINESS
numbers = np.array(['8420', '843a'], [])

with open(filename_1, 'r') as f:
    lines = f.readlines()

# Create an empty list to hold the integer strings
addr_strings = []

addr_strings = np.zeros(shape=(1, 4))
addr_strings_row = []
count = 0

# Iterate over the lines in the file
for line in lines:
    # Check if the line contains "addi sp,sp"
    if "addi\tsp,sp" in line:
        # Split the line into words
        words = line.split()
        # print(words)
        # Get the first word (which should be the integer string)
        int_string = str(words[0]).rstrip(':')
        # Append the integer string to the list
        count = count + 1
        if(count % 2 == 1):
            addr_strings_row.append(int(count/2))
        addr_strings_row.append(int_string)
        #addr_strings_row.append(0)
        if(count % 2 == 0):
            addr_strings_row.append(int(0))
            addr_strings = np.vstack((addr_strings, np.array(addr_strings_row)))
            addr_strings_row = []

# Print the resulting array
addr_strings = np.delete(addr_strings, 0, 0)
print(addr_strings)

numbers = []

with open(filename_2, 'r') as f:
    for line in f:
        if 'addi sp, sp,' in line:
            match = re.search(r'addi sp, sp, *(?P<number>-?\d+)', line)
            match_2 = re.search(r'0x[\da-fA-F]+', line)
            if match:
                # extract the number and add it to the list
                number_string = match.group('number')
                match_addr_pre = match_2.group()
                match_addr = match_addr_pre[-4:]
                print(match_addr)
                if(match_addr != '8404' and match_addr != '8ca6'): # excluding initial sp move and final ret instruction
                    number = int(number_string)
                    numbers.append(number)

                    # update
                    matching_rows = np.where(addr_strings.astype(str) == match_addr)
                    if(matching_rows[1][0] == 2):
                        addr_strings[matching_rows[0][0], 3] = str(int(addr_strings[matching_rows[0][0], 3]) + 1)
                    else:
                        addr_strings[matching_rows[0][0], 3] = str(int(addr_strings[matching_rows[0][0], 3]) - 1)


# convert the list of numbers to a numpy array
numbers_array = np.array(numbers)

# print the resulting array
print(numbers_array)
N = len(numbers_array)
sp_values = np.zeros(N)
for i in range(0, N):
    sp_values[i] = np.sum(numbers_array[0:i])


print(sp_values)
print('addr_strings (final) = ', addr_strings)