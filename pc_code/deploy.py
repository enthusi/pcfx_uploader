#(c) 2022 Martin Wendt, David Shadoff
import serial
import sys
import time

from fx_xfer_lib import *

# Notes:
#
# This program will:
#   - load a program into PC-FX memory, and then
#   - execute at an arbitrary memory location (does not need to be in the loaded program)
#
#   Usage: deploy <input_file> <address> <exec_address> [COM port]
#
#   Example:
#     python deploy.py mandelbrot 0x8000 0x8000 COM3
#
# Note: Most programs are compiled to be loaded into 0x8000 area
#       with an entry address of 0x8000
#

if ((len(sys.argv) != 5) and (len(sys.argv) != 4)):
    print("Usage: deploy <input_file> <address> <exec address> [COM port]")
    exit()

ser = serial.Serial()
ser.baudrate = 115200

# Add override for windows-style COM ports.
if (len(sys.argv) == 5):
    ser.port = sys.argv[4]
else:
    ser.port = '/dev/ttyUSB0'

ser.open()

f = open(sys.argv[1], 'rb') 
memory = f.read()
f.close()

addr=hexdecode(sys.argv[2])
execaddr=hexdecode(sys.argv[3])
size=len(memory)

writefx(ser, addr, memory, size)

# There may be an extra read on the PC-FX side which needs to be satisfied by delay
time.sleep(1)

execfx(ser, execaddr)

ser.close()

