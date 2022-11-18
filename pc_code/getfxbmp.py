#(c) 2022 Martin Wendt, David Shadoff
import serial
import sys
import time

from fx_xfer_lib import *

# Notes:
#
# This program will read the PC-FX's external Backup memory card (FX-BMP) into a 128KB file
#
#   Usage: getfxbmp <output_file> [COM port]
#
#   Example:
#     python getfxbmp.py pcfxbmp.bin COM3
#

if ((len(sys.argv) != 3) and (len(sys.argv) != 2)):
    print("Usage: getfxbmp <output_file> [COM port]")
    exit()

# External Backup RAM:
#addr=0xE8000000
addr=hexdecode('0xE8000000')
size=hexdecode('0x20000')

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

f = open(sys.argv[1], 'wb') 

memory = readfx(ser, addr, size)
f.write(memory)

f.close()

ser.close()

