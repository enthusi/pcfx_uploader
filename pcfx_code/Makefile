#(c) 2022 Martin Wendt
SOURCE=loader.s
EMU=mednafen

getram2: getram2.s version.s
	v810-as getram2.s -a=getram2.lst -o getram2.o
	v810-ld getram2.o -o getram2.linked
	v810-objcopy  getram2.linked -O binary getram2
	
loader_gfx: loader_gfx.o version.s
	v810-ld loader_gfx.o -o loader_gfx.linked
	v810-objcopy  loader_gfx.linked -O binary loader_gfx
	
version.s: getram2.s set_version.py
	python set_version.py

loader: loader.o
	v810-ld loader.o -o loader.linked
	v810-objcopy  loader.linked -O binary loader

sender: sender.s
	v810-as sender.s -a=sender.lst -o sender.o
	v810-ld sender.o -o sender.linked
	v810-objcopy  sender.linked -O binary sender
	
getram: getram.s
	v810-as getram.s -a=getram.lst -o getram.o
	v810-ld getram.o -o getram.linked
	v810-objcopy  getram.linked -O binary getram

loader.o:  $(SOURCE) 
	v810-as $(SOURCE) -o loader.o
	
loader_gfx.o: loader_gfx.s
	v810-as loader_gfx.s -o loader_gfx.o
	
cd: loader.cue sender.cue

getram2.cue: cdlink_getram2.txt getram2 
	pcfx-cdlink cdlink_getram2.txt getram2
	
loader_gfx.cue: cdlink_gfx.txt loader_gfx 
	pcfx-cdlink cdlink_gfx.txt loader_gfx

loader.cue: cdlink.txt loader 
	pcfx-cdlink cdlink.txt loader
	
sender.cue: cdlinksender.txt sender
	pcfx-cdlink cdlinksender.txt sender	
	
run: loader.cue
	$(EMU) loader.cue

run_getram2: getram2.cue
	$(EMU) getram2.cue
		
run_gfx: loader_gfx.cue
	$(EMU) loader_gfx.cue
	
dump: loader.o
	v810-objdump -d loader.o
