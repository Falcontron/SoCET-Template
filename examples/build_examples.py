#! /usr/bin/python3

import subprocess
import glob
import os
import pathlib


compile_cmd = ['riscv64-unknown-elf-gcc', '-g', '-march=rv32imc_zicsr_zifencei', '-mabi=ilp32', '-mcmodel=medany', 
                '-static', '-ffreestanding', '-nostartfiles', '-fstack-usage', '-ffunction-sections', '-fdata-sections', #'-fstack-check',
                '-Wl,--gc-sections', '-Os', '-Tlink.ld', 'AFTx07.S', 'utility.c', 'format.c']

cvt_cmd = ['riscv64-unknown-elf-objcopy', '-O', 'binary']


if not os.path.isfile('./AFTx07.S') or not os.path.isfile('link.ld'):
    print('Error: Could not find AFTx07.S or link.ld in this directory')
    exit(1)


for fname in glob.glob('./*.c'):

    if 'utility' in fname or 'format' in fname:
        print("Skipping " + fname + ": is utility");
        continue

    print('Compiling {}'.format(fname))
    basename = pathlib.Path(fname).stem

    rv = subprocess.run(compile_cmd + [fname, '-o', basename + '.elf'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
    if rv.returncode != 0:
        print('Exited with error {}, printing command, stdout, stderr!'.format(rv.returncode))
        print('Command: {}\n\n'.format(compile_cmd + [fname, '-o', basename + '.elf']))
        print('stdout:\n\n{}'.format(rv.stdout))
        print('stderr:\n\n{}'.format(rv.stderr))
        print('Skipping...')
        continue
        #print('Exiting...')
        #exit(1)

    print('Converting {} to binary'.format(fname))
    rv = subprocess.run(cvt_cmd + [basename + '.elf', basename + '.bin'])
    if rv.returncode != 0:
        print('Exited with error {}, printing command, stdout, stderr!'.format(rv.returncode))
        print('Command: {}\n\n'.format(compile_cmd + [fname, '-o', basename + '.elf']))
        print('stdout:\n\n{}'.format(rv.stdout))
        print('stderr:\n\n{}'.format(rv.stderr))
        print('Exiting...')
        exit(1)


print(
'''        
   Finished compilation. Now, pass the '.bin' file corresponding to
   the example to run as an argument to 'VbASIC_wrapper' to run an example!
''')
