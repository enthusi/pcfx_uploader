#(c) 2022 Martin Wendt, David Shadoff
import serial
import sys
import time

from fx_xfer_lib import *

# Notes:
#
# This program will write the PC-FX's Backup memory from a 32KB file
#
#   Usage: putbram <input_file> [COM port]
#
#   Example:
#     python putbram.py pcfxbkp.bin COM3
#

if ((len(sys.argv) != 3) and (len(sys.argv) != 2)):
    print("Usage: putbram <input_file> [COM port]")
    exit()

# Backup RAM:
#addr=0xE0000000
addr=hexdecode('0xE0000000')
size=hexdecode('0x8000')

ser = serial.Serial()
ser.baudrate = 115200

# Add override for windows-style COM ports.
# Usage:
#   python send.py mandelbrot COM24
if (len(sys.argv) == 3):
    ser.port = sys.argv[2]
else:
    ser.port = '/dev/ttyUSB0'

ser.open()

f = open(sys.argv[1], 'rb') 
memory = f.read()

writefx(ser, addr, memory, size)

f.close()

ser.close()

