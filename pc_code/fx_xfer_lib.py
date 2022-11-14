#(c) 2022 Martin Wendt, David Shadoff
import serial
import time

BLOCKSIZE = 32768

#
# deploy a program as per initial load (magic number 0x12345678)
# (soon to be deprecated)
#
def deploy_program(port, program):
    length = len(program)

    words = length//4
    rest = length - words*4
    # print (length,words,rest)

    #send magic bytes for longan!
    #print(port.write(0x12345678.to_bytes(4,'little')))
    port.write(0x12345678.to_bytes(4,'little'))
    port.flush()
    #transfer length in bytes
    #print(port.write(length.to_bytes(4,'little')))
    port.write(length.to_bytes(4,'little'))
    port.flush()

    #transfer data
    databytes=bytearray(program)
    #print (port.write(databytes))     # write a string
    port.write(databytes)     # write a string
    port.flush()

    filler=[0x00]
    for fill in range(rest):
        databytes=bytearray(filler)
        #print (port.write(databytes))     # write a string
        port.write(databytes)     # write a string
        port.flush()
    return
 
#
# Get a value from command line and convert it if it has a hexadecimal prefix
#
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

#
# Read a 'chunk' of data from regular memory
#
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

#
# Read a 'chunk' of data from backup memory (every second byte)
#
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

# BIOS:
#addr=0xFFF00000
# Backup RAM:
#addr=0xE0000000
# External Backup RAM:
#addr=0xE8000000

#
# Read memory, while breaking it down into manageable-sized fetches:
#
def readfx(port, addr, size, blksize=BLOCKSIZE):
    remainder = size
    count = 0

    while (remainder > 0):
        if (remainder > blksize):
            chunk = blksize
        else:
            chunk = remainder

        if ((addr >= 0xE0000000) and (addr <= 0xEFFFFFFF)):
            mem = rdbr_data(port, addr, chunk)
            addr = addr + chunk + chunk     # only every second byte
        else:
            mem = read_data(port, addr, chunk)
            addr = addr + chunk

        if count == 0:
            allmem = mem
            count = count + 1
        else:
            allmem = allmem + mem

        remainder = remainder - chunk

    return allmem

#
# Write a 'chunk' of data into regular memory
#
def writ_data(port, addr, mem):
    size = len(mem)
    words = size//4
    rest = size - words*4
    print('WRIT',end=', ') 
    print('{0:0{1}X}'.format(addr,8),end=', ') 
    print('{0:0{1}X}'.format(size,8)) 
    port.write(b'WRIT')
    port.write(addr.to_bytes(4,'little'))
    port.write(size.to_bytes(4,'little'))
    port.flush()
#    mem = port.read(size)

    databytes=bytearray(mem)
    port.write(databytes)     # write a string
    port.flush()

    filler=[0x00]
    for fill in range(rest):
        databytes=bytearray(filler)
        #print (port.write(databytes))     # write a string
        port.write(databytes)     # write a string
        port.flush()
    return

#
# Write a 'chunk' of data into backup memory
#
def wrbr_data(port, addr, mem):
    size = len(mem)
    words = size//4
    rest = size - words*4
    print('WRBR',end=', ') 
    print('{0:0{1}X}'.format(addr,8),end=', ') 
    print('{0:0{1}X}'.format(size,8)) 
    port.write(b'WRBR')
    port.write(addr.to_bytes(4,'little'))
    port.write(size.to_bytes(4,'little'))
    port.flush()
#    mem = port.read(size)

    databytes=bytearray(mem)
    port.write(databytes)     # write a string
    port.flush()

    filler=[0x00]
    for fill in range(rest):
        databytes=bytearray(filler)
        #print (port.write(databytes))     # write a string
        port.write(databytes)     # write a string
        port.flush()
    return

