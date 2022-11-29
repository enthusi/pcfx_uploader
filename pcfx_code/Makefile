#(c) 2022 Martin Wendt
SOURCE=loader.s
EMU=mednafen

client: client.s version.s
	v810-as client.s -a=client.lst -o client.o
	v810-ld client.o -o client.linked
	v810-objcopy  client.linked -O binary client
	
version.s: client.s set_version.py
	python set_version.py

	
cd: client.cue 

client.cue: cdlink_client.txt client 
	pcfx-cdlink cdlink_client.txt client
	
run: client.cue
	$(EMU) client.cue
		
	
dump: client.o
	v810-objdump -d client.o
