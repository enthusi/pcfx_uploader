#(c) 2022 Martin Wendt, David Shadoff
import serial
import sys
import time

from fx_xfer_lib import *

# Notes:
# This program currently:
# - communicates to the loader program (loaded by CDROM)
# - WRIT and WRBR (write BRAM) functions are implemented and tested
#
#   Usage: putram <start_addr> <length> <input_file> [COM port]
#
#   Example:
#     python putram.py 0x10000 0x10000 test.bin COM3
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

