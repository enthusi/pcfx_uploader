#(c) 2022 Martin Wendt, David Shadoff
import serial
import sys
import time

from fx_xfer_lib import *

# Notes:
# - Functions will soon be pulled out into an importable module
# - print functions in the program-deploy section were commented out; these comments can be removed
#
# This program currently:
# - deploys a program to the FX (via the 'loader' protocol)
# - then communicates to the deployed program (according to its slightly-different protocol)
# - WRIT and WRBR (read BRAM) function are implemented and tested
#
#   Usage: putram <start_addr> <length> <output_file> [COM port]
#
#   Example:
#     python putram.py 0xfff00000 0x100000 pcfxbios.bin COM3
#

if ((len(sys.argv) != 5) and (len(sys.argv) != 4)):
    print("Usage: putram <start_addr> <length> <input_file> [COM port]")
    exit()

addr=hexdecode(sys.argv[1])
size=hexdecode(sys.argv[2])

if (size < 1):
    print("length of data save must be greater than zero")
    exit()


ser = serial.Serial()
ser.baudrate = 115200

# Add override for windows-style COM ports.
# Usage:
#   python send.py mandelbrot COM24
if (len(sys.argv) == 5):
    ser.port = sys.argv[4]
else:
    ser.port = '/dev/ttyUSB0'

ser.open()
# print(ser)

# BIOS:
#addr=0xFFF00000
# Backup RAM:
#addr=0xE0000000
# External Backup RAM:
#addr=0xE8000000

f = open(sys.argv[3], 'rb') 
memory = f.read(size)
f.close()

writefx(ser, addr, memory, size)

ser.close()

