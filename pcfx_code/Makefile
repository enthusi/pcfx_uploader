SOURCE=loader.s
EMU=mednafen

loader: loader.o
	v810-ld loader.o -o loader.linked
	v810-objcopy  loader.linked -O binary loader
	
loader.o:  $(SOURCE) 
	v810-as $(SOURCE) -o loader.o
	
cd: loader.cue

loader.cue: cdlink.txt loader 
	pcfx-cdlink cdlink.txt loader
	
run: loader.cue
	$(EMU) loader.cue
	
dump: loader.o
	v810-objdump -d loader.o
