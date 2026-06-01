addr = 0

with open("meminit.bin", "rb") as fbin:
    with open("fpgainit.mif", "w") as fmif:
        fmif.write("WIDTH=32;\nDEPTH=16384;\n\nADDRESS_RADIX=HEX;\nDATA_RADIX=HEX;\n\n")
        fmif.write("CONTENT BEGIN\n")
        word = fbin.read(4)
        while word:
            word_hex = word.hex()
            # little endian words
            fmif.write(str(hex(addr >> 2)[2:]) + ' : ' + word_hex[6:8] + word_hex[4:6] + word_hex[2:4] + word_hex[0:2] + ';\n')
            word = fbin.read(4)
            addr = addr + 4
        fmif.write("END;\n")
        print("meminit.bin converted to fpgainit.mif")
