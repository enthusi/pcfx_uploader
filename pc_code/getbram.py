#(c) 2022 Martin Wendt, David Shadoff
import serial
import sys
import time

from fx_xfer_lib import *

# Notes:
#
# This program will read the PC-FX's Backup memory into a 32KB file
#
#   Usage: getbram <output_file> [COM port]
#
#   Example:
#     python getbram.py pcfxbkp.bin COM3
#

if ((len(sys.argv) != 3) and (len(sys.argv) != 2)):
    print("Usage: getbram <output_file> [COM port]")
    exit()

# Backup RAM:
#addr=0xE0000000
addr=hexdecode('0xE0000000')
size=hexdecode('0x8000')

ser = serial.Serial()
ser.baudrate = 115200

# Add override for windows-style COM ports.
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

