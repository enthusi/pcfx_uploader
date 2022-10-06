#(c) 2022 Martin Wendt
import serial
import sys

magic=[0x78,0x56,0x34,0x12] #
testdata = open(sys.argv[1],'rb').read()

length = len(testdata)

words = length//4
rest = length - words*4
print (length,words,rest)
 
a0 = length & 0xff
a1 = (length >> 8) & 0xff
a2 = (length >> 16) & 0xff
a3 = (length >> 24) & 0xff
d_length = [a0,a1,a2,a3]

ser = serial.Serial()
ser.baudrate = 115200
ser.port = '/dev/ttyUSB0'
ser.open()
print(ser)


#send magic bytes for longan!
databytes=bytearray(magic)
print (ser.write(databytes))
ser.flush()


#transfer length in bytes
databytes=bytearray(d_length)
print (ser.write(databytes))     # write a string
ser.flush()

#transfer data
databytes=bytearray(testdata)
print (ser.write(databytes))     # write a string
ser.flush()

filler=[0x00]
for fill in range(rest):
    databytes=bytearray(filler)
    print (ser.write(databytes))     # write a string
    ser.flush()
    
ser.close() 

