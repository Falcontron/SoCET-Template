#!/usr/bin/python3

width=4
signed=True

for i in range(width*2-1):
    if i < width:
        for a_i in range(i + 1):
            print(f"weight {2**i}: partial[{i}][{a_i}] = a[{a_i}] & b[{i - a_i}]")
    else:
        for a_i in range(2*width - i - 1):
            print(f"weight {2**i}: partial[{i}][{a_i}] = a[{a_i + i - width + 1}] & b[{width - a_i - 1}]")

        if signed and i == width:
            print(f"weight {2**i}: partial[{i}][{width-1}] = 1")
    print()

for i in range(1, width*2):
    if i < width:
        print(f"weight {2**(i - 1)}: len {i}")
    else:
        print(f"weight {2**(i - 1)}: len {2 * width - i}")

for i in range(width*2-1):
    if i < width:
        for j in range(i + 1, width):
            print(f"partial_prods[{i}][{j}] = 0")
    elif i >= width:
        for j in range(i - width + 1):
            if signed and i != width and j != width - 1:
                print(f"partial_prods[{i}][{j + 2*width - i - 1}] = 0")
    print()
