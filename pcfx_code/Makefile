#(c) 2022 Martin Wendt
SOURCE=loader.s
EMU=mednafen

loader: loader.o
	v810-ld loader.o -o loader.linked
	v810-objcopy  loader.linked -O binary loader

sender: sender.s
	v810-as sender.s -a=sender.lst -o sender.o
	v810-ld sender.o -o sender.linked
	v810-objcopy  sender.linked -O binary sender
	
getbram: getbram.s
	v810-as getbram.s -a=getbram.lst -o getbram.o
	v810-ld getbram.o -o getbram.linked
	v810-objcopy  getbram.linked -O binary getbram

loader.o:  $(SOURCE) 
	v810-as $(SOURCE) -o loader.o
	
cd: loader.cue sender.cue

loader.cue: cdlink.txt loader 
	pcfx-cdlink cdlink.txt loader
	
sender.cue: cdlinksender.txt sender
	pcfx-cdlink cdlinksender.txt sender	
	
run: loader.cue
	$(EMU) loader.cue
	
dump: loader.o
	v810-objdump -d loader.o
