#(c) 2022 Martin Wendt, David Shadoff
import serial
import sys
import time

# Notes:
# - Functions will soon be pulled out into an importable module
# - print functions in the program-deploy section were commented out; these comments can be removed
#
# This program currently:
# - deploys a program to the FX (via the 'loader' protocol)
# - then communicates to the deployed program (according to its slightly-different protocol)
# - READ and RDBR (read BRAM) function are implemented and tested
# - WRIT, WRBR, and EXEC functions are roughed-in on the microcontroller but not implemented here
#
#   Usage: getram <pcfxprog> <start_addr> <length> <output_file> [COM port]
#
#   Example:
#     python getram.py getram 0xfff00000 0x100000 pcfxbios.bin COM3
#

def deploy_program(port, program):
    length = len(program)

    words = length//4
    rest = length - words*4
    # print (length,words,rest)

    #send magic bytes for longan!
    #print(ser.write(0x12345678.to_bytes(4,'little')))
    ser.write(0x12345678.to_bytes(4,'little'))
    ser.flush()
    #transfer length in bytes
    #print(ser.write(length.to_bytes(4,'little')))
    ser.write(length.to_bytes(4,'little'))
    ser.flush()

    #transfer data
    databytes=bytearray(program)
    #print (ser.write(databytes))     # write a string
    ser.write(databytes)     # write a string
    ser.flush()

    filler=[0x00]
    for fill in range(rest):
        databytes=bytearray(filler)
        #print (ser.write(databytes))     # write a string
        ser.write(databytes)     # write a string
        ser.flush()
    return
    
def hexdecode(input):
    hexadecimal = 0
    num = 0
    if input[0] == "$":
        hexadecimal = 1
        hexnum = input[1:]
    elif input[0:2] == "0x" or input[0:2] == "0X":
        hexadecimal = 1
        hexnum = input[2:]

    if hexadecimal == 1:
        num = int(hexnum, 16)
    else:
        num = int(input)
    return num

def read_data(port, addr, size):
    print('READ',end=', ') 
    print('{0:0{1}X}'.format(addr,8),end=', ') 
    print('{0:0{1}X}'.format(size,8)) 
    port.write(b'READ')
    port.write(addr.to_bytes(4,'little'))
    port.write(size.to_bytes(4,'little'))
    port.flush()
    mem = port.read(size)
    return mem 

def rdbr_data(port, addr, size):
    print('RDBR',end=', ') 
    print('{0:0{1}X}'.format(addr,8),end=', ') 
    print('{0:0{1}X}'.format(size,8)) 
    port.write(b'RDBR')
    port.write(addr.to_bytes(4,'little'))
    port.write(size.to_bytes(4,'little'))
    port.flush()
    mem = port.read(size)
    return mem 



if ((len(sys.argv) != 6) and (len(sys.argv) != 5)):
    print("Usage: getram <pcfxprog> <start_addr> <length> <output_file> [COM port]")
    exit()

addr=hexdecode(sys.argv[2])
size=hexdecode(sys.argv[3])

blocksize=0x8000

if (size < 1):
    print("length of data fetch must be greater than zero")
    exit()

fx_program = open(sys.argv[1],'rb').read()

ser = serial.Serial()
ser.baudrate = 115200

# Add override for windows-style COM ports.
# Usage:
#   python send.py mandelbrot COM24
if (len(sys.argv) == 6):
    ser.port = sys.argv[5]
else:
    ser.port = '/dev/ttyUSB0'

ser.open()
# print(ser)

deploy_program(ser, fx_program)

# BIOS:
#addr=0xFFF00000
# Backup RAM:
#addr=0xE0000000
# External Backup RAM:
#addr=0xE8000000

remainder = size
f = open(sys.argv[4], 'wb') 

while (remainder > 0):
    if (remainder > blocksize):
        chunk = blocksize
    else:
        chunk = remainder

    if ((addr >= 0xE0000000) and (addr <= 0xEFFFFFFF)):
        mem = rdbr_data(ser, addr, chunk)
        addr = addr + chunk + chunk     # only every second byte
    else:
        mem = read_data(ser, addr, chunk)
        addr = addr + chunk

    remainder = remainder - chunk
    f.write(mem)

    time.sleep(0.3)

f.close()

ser.close()

