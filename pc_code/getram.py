#(c) 2022 Martin Wendt, David Shadoff
import serial
import sys
import time

from fx_xfer_lib import *

# Notes:
# This program currently:
# - communicates to the loader program (loaded by CDROM)
# - READ and RDBR (read BRAM) functions are implemented and tested
#
#   Usage: getram <start_addr> <length> <output_file> [COM port]
#
#   Example:
#     python getram.py 0xfff00000 0x100000 pcfxbios.bin COM3
#

if ((len(sys.argv) != 5) and (len(sys.argv) != 4)):
    print("Usage: getram <start_addr> <length> <output_file> [COM port]")
    exit()

addr=hexdecode(sys.argv[1])
size=hexdecode(sys.argv[2])

if (size < 1):
    print("length of data fetch must be greater than zero")
    exit()


ser = serial.Serial()
ser.baudrate = 115200

# Add override for windows-style COM ports.
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

remainder = size
f = open(sys.argv[3], 'wb') 

memory = readfx(ser, addr, size)
f.write(memory)

f.close()

ser.close()

