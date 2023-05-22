#(c) 2022 Martin Wendt, David Shadoff
import serial
import sys
import time

from fx_xfer_lib import *

# Notes:
#
# This program will:
#   - load a program into PC-FX memory, and then execute at the starting memory location
#
#   Usage: exec <address> [COM port]
#
#   Example:
#     python exec.py 0x8000 COM3
#
# Note: Most programs are compiled to be loaded into 0x8000 area
#       with an entry address of 0x8000
#

if ((len(sys.argv) != 3) and (len(sys.argv) != 2)):
    print("Usage: exec <address> [COM port]")
    exit()

addr=hexdecode(sys.argv[1])

ser = serial.Serial()
ser.baudrate = 115200

# Add override for windows-style COM ports.
if (len(sys.argv) == 3):
    ser.port = sys.argv[2]
else:
    ser.port = '/dev/ttyUSB0'

ser.open()

memory = execfx(ser, addr)

ser.close()

