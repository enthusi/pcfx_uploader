# PCFX Uploader
transmitting data from PC to a NEC PC-FX via microcontroller in GPL v3 licence.

## Build
*microcontroller_code* contains the firmware in assembly for the LonganNano.\
*pc_code* with the python script to upload data via UART connection.\
*pcfx_code* contains the client on NEC PC-FX side in v810 assembly (`make cd` will build an CD bin/cue image).

To build just type ```make``` in the corresponding folder, or launch the script, given that you have the following tools in your path:\
[RV32 Assembler Bronzebeard](https://github.com/theandrew168/bronzebeard)\
[v810 binutils](https://github.com/jbrandwood/v810-gcc)\
[pcfx-tools](https://github.com/jbrandwood/pcfxtools)

## Summary
- the code on the PCFX side expects a magic word, start-address, execution-address and data length
- the code on the microcontroller mimics a PC-FX controller and sends all 32 keypad bits in the PC-FX specific protocol
- the code on the PC side simply connects to the microcontroller via UART
- The overall transmission speed is close to the UART limit despite a couple of extended wait loops on the PC-FX side. That could be optimized for speed if one really wanted to.

## Setup
The Longan Nano is hooked up to Port2 of the PC-FX via 3V-5V level shifts (though it _should_ be 5V tolerant)\
It uses 5 lines: GND, VCC, CLOCK, LATCH and DATA.\
The PC-FX pulls the LATCH line to low (0 Volts) when it wants more data to come in.
Then it sends a quick clock signal HIGH,LOW,HIGH,...\
The microcontroller senses that LATCH line, if it gets low, waits for it to get high then senses the CLOCK line and makes sure to put the proper
signal on the output DATA depending on the state of your data bit (0 or 1). Initially, I tested that in C on the raspberry PI with _some_ success.
But it became clear that it would be too instable. Then I went for a microcontroller (with only ~100 Mhz) in C. That worked but I wasn't totally happy.
Then I recoded the microcontroller in plain assembly (32bit RiscV, not too different from the PC-FX's native v810 CPU btw).
The PC connects via UART to the native UART lines of the Longan Nano.



YouTube recording:\
[![NEC PC-FX uploader by PriorArt](http://img.youtube.com/vi/flS91IILcIk/0.jpg)](https://www.youtube.com/watch?v=flS91IILcIk "NEC PC-FX uploader by PriorArt")

## Credits
- code: *Martin 'enthusi' Wendt* [PriorArt](https://priorartgames.eu)

the folder *pc_code* contains the PC-FX binary `mandelbrot` from
[PC-FX Mandelbrot](https://github.com/enthusi/pcfx_fractal) which you can use to send as an example `python pysend.py mandelbrot`.\
See also: [PriorArt website](https://priorartgames.eu/2022/10/03/demo-mandelbrot-for-nec-pc-fx/)

## Research
David Shadoff tested the signals from '[test data line release'](https://github.com/enthusi/pcfx_uploader/releases/tag/testing_output) based on a RP2040 setup with his logic analyzer and confirms our expectation, that the data line is indeed bidirectional. Also the OE signal change flags the used direction.\
[![Logic analyzer](https://github.com/enthusi/pcfx_uploader/blob/main/findings/PC-FX_Controller_Send_Data.png)]

