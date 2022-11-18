#(c) 2022 Martin Wendt, David Shadoff
import serial
import sys
import time

from fx_xfer_lib import *

# Notes:
#
# This program currentlyll read the PC-FX's BIOS ROM into a 1MB file
#
#   Usage: exec <address> [COM port]
#
#   Example:
#     python exec.py 0x10000 COM3
#

if ((len(sys.argv) != 3) and (len(sys.argv) != 2)):
    print("Usage: exec <address> [COM port]")
    exit()

addr=hexdecode(sys.argv[1])

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

memory = execfx(ser, addr)

ser.close()

