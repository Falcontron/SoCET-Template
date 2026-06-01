#!/usr/bin/python3

import os
import contextlib

def reduction_done(d):
    return all([i <= 2 for i in d])

def reduce(width, signed):
    depth = [i for i in range(1, width + 1)] + [i for i in range(width - 1, -1, -1)]
    if signed:
        depth[width] += 1
    print(depth)
    assert(len(depth) == 2 * width)

    num_reductions = 0
    while not reduction_done(depth):
        print(f"after {num_reductions} reductions: {depth}")
        seen_carry = False
        next_depth = [0 for _ in range(len(depth))]
        saved_depth = 0
        for i in range(len(depth)):
            # print(f"next_depth: {next_depth}")
            saved_depth = depth[i]
            # Add in all previous bits, we'll reduce them using half and full
            # adders in the next step
            next_depth[i] += depth[i]

            if (saved_depth < 2):
                seen_carry = False
            elif (saved_depth == 2):
                if (seen_carry and (depth[i + 1] == 1 or depth[i + 1] == 2)): # Use a half adder
                    print(f"added half adder to index {i}")
                    next_depth[i] -= 1
                    next_depth[i + 1] += 1
                    seen_carry = True
            elif (saved_depth == 3):
                if (not seen_carry): # Use a half adder
                    print(f"added half adder to index {i}")
                    next_depth[i] -= 1
                    next_depth[i + 1] += 1
                else: # Use a full adder
                    print(f"added full adder to index {i}")
                    next_depth[i] -= 2
                    next_depth[i + 1] += 1
                seen_carry = True
            else:
                while (saved_depth > 1):
                    seen_carry = True
                    if (saved_depth > 2): # Use a full adder
                        print(f"added full adder to index {i}")
                        next_depth[i] -= 2
                        next_depth[i + 1] += 1
                        saved_depth -= 3
                    else: # Use a half adder
                        print(f"added half adder to index {i}")
                        next_depth[i] -= 1;
                        next_depth[i + 1] += 1;
                        saved_depth -= 2;
        depth = next_depth
        num_reductions += 1

    print(f"after {num_reductions} reductions: {depth}")
    assert(depth[-1] <= 1)
    return num_reductions

if __name__ == '__main__':
    old_unsigned = 0
    old_signed = 0
    previous_width = 0

    max_width = 64
    for i in range(1, max_width + 1):
        with open(os.devnull, "w") as f, contextlib.redirect_stdout(f):
            unsigned = reduce(i, False)
            signed = reduce(i, True)
        if unsigned != old_unsigned:
            print(f"{'end else ' if previous_width != 0 else ''}if (width < {i}) begin")
            if old_unsigned != old_signed:
                print(f"    return (width == {i - 1} && sign) ? {old_signed} : {old_unsigned};")
                assert(old_unsigned + 1 == old_signed)
            else:
                print(f"    return {old_unsigned};")
            previous_width = i
        old_unsigned = unsigned
        old_signed = signed
    print(f"end else if (width < {max_width + 1}) begin")
    print(f"    return {unsigned};")
    assert unsigned == signed
    print("end else begin")
    print(f"    assert(width <= {max_width}) else $error(\"max_width should be less than {max_width}\");")
    print("end")
