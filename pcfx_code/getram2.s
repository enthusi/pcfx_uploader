#(c) 2022 Martin Wendt

.include "macros.s"
.include "defines.s"
.include "version.s"

#===============================
.equiv r_register, r6    
.equiv r_value,    r7    
.equiv r_ptr,    r10
.equiv r_len,    r11
.equiv r_tmp,    r14
.equiv r_tmpptr, r15
.equiv r_screenx, r16
.equiv r_screeny, r17
.equiv r_tmp_loop, r20
.equiv r_tmp_adr,  r21
.equiv r_tmp_data, r22
.equiv r_keypad, r29


#===============================
.globl _start
.org = 0x8000
_start = 0x8000
.equiv relocate_to, 0x0000
Start:

    movw 0x200000, sp
    movw 0x1000, gp
    
    #disable, clear, enable cache
    #hint from Elmer: CD-DMA during boot may have invalidated it!
    ldsr    r0,chcw
    movea   0x8001,r0,r1
    ldsr    r1,chcw
    mov     2,r1
    ldsr    r1,chcw
    
    call setup_display #that part of the code requires no-relocation
                       #there is PLENTY of RAM at 0x1000 but still :)
    
    call  plot_logo
relocate_and_launch_full_client:
    movw client_code, r10
    movw relocate_to, r11
    movea (client_code_end - client_code),r0, r12
   
1:
    ld.w 0[r10],r13
    st.w r13,0[r11]
    add 4, r10
    add 4, r11
    add -4, r12
    bp 1b
    
    #disable interrupts
    stsr	PSW, r_tmp /*current sys reg */
    movw	(1<<12),  r_tmp_data /*1<<12 = 0x1000*/
    or	r_tmp, r_tmp_data /*keep formerly set bits*/
    ldsr	r_tmp_data, PSW
	
	mov SUP_CTRL, r_register	/*; DMA control*/
	out.h r_register, SUPA_reg[r0]
	out.h r0, SUPA_dat[r0]
	
	
	#clear irq vectors HARD
	movw 16, r_tmp_loop
	movw 0x7FC0, r_tmp_adr
	
1:
	st.w r0, 0[r_tmp_adr]
	add 4, r_tmp_adr
	add -1, r_tmp_loop
	bne 1b
	
	 movw relocate_to, r14
    jmp [r14]
#====================================
plot_logo:
    movw 25, r_tmp_loop
    shl 5, r_tmp_loop #only *32 as KING_KRAM_ADR_write is in half-words!
    mov KING_KRAM_ADR_write, r_register
	movw ((0x010000)| (1 << KING_b_inc)) , r_tmp_data
	add r_tmp_loop, r_tmp_data
	out.h r_register, KING_reg[r0]
	out.w r_tmp_data, KING_dat[r0]
	
	mov KING_KRAM_rw, r_register
    out.h r_register, KING_reg[r0]
    movw 12, r_tmp_loop
    movw 256, r_tmp_data
1:
	out.h r_tmp_data, (KING_dat)[r0]
	add 1, r_tmp_data
	add -1, r_tmp_loop
	bne 1b
	ret
#-------------------------------------	
setup_display:
    /* 	; KING BG0/1 palette offsets */

    mov HuC6261_SCREENMODE, r_register	
	movw ( HuC6261_line262 | HuC6261_intsync | HuC6261_256px | HuC6261_KingBG0_on), r_value
	out.h r_register, HuC6261_reg[r0]
	out.h r_value   , HuC6261_dat[r0]
	
	/* Tetsu palette */
	mov HuC6261_PAL_NR, r_register	
	mov 0, r_value
	out.h r_register, HuC6261_reg[r0]
	out.h r_value   , HuC6261_dat[r0]
	
	call put_palette
	call push_charset
    	
    /* Tetsu palette */
	mov HuC6261_PAL_NR, r_register	
	mov 0, r_value
	out.h r_register, HuC6261_reg[r0]
	out.h r_value   , HuC6261_dat[r0]
	
    #clear BAT
    
	movw 0x1000, r_tmp_loop
	
	mov KING_KRAM_ADR_write, r_register/*	; KRAM write address*/
	movw 0x10000, r_value/*	; Address = 0x000 here*/
	mov 1, r_tmp  /*increase by 1*/ 
	shl KING_b_inc, r_tmp
	or r_tmp, r_value
	out.h r_register, KING_reg[r0]
	out.w r_value, KING_dat[r0]
		
	movw 0x01000100,r_value
	mov KING_KRAM_rw, r_register/*	; KRAM R/W*/
	out.h r_register, KING_reg[r0]
.nextKRAMWrite1:	
	out.w r_value, KING_dat[r0]
	add -2, r_tmp_loop
	bnz .nextKRAMWrite1
	
	mov HuC6261_PAL_KING_01, r_register/*; KING BG0/1 palette offsets*/
	mov 0, r_value	/*; Both offsets = 0*/
	out.h r_register, HuC6261_reg[r0]
	out.h r_value   , HuC6261_dat[r0]
	
	mov HuC6261_PRIO_0, r_register	/*; 7up/Rainbow priority*/
	movw 0x010, r_value	/*; 7up spr = 3*/
	out.h r_register, HuC6261_reg[r0]
	out.h r_value   , HuC6261_dat[r0]
	
	mov HuC6261_PRIO_1, r_register	/*; KING priority*/
	movw 0x0023, r_value	/*; BG0 = 2, BG1 = 1*/
	out.h r_register, HuC6261_reg[r0]
	out.h r_value   , HuC6261_dat[r0]

/* 	; Cellophane control: disable */
	movw HuC6261_CTRL_CELL, r_register	/*; Cellophane control*/
	mov 0,r_value	/*; Disable*/
	out.h r_register, HuC6261_reg[r0]
	out.h r_value   , HuC6261_dat[r0]
	
/* 	; KRAM page setup: use page 0 for everything */
/* 	; (we only use backgrounds anyway) */
	mov KING_KRAM_page, r_register/*	; KRAM page setup*/
	mov 0, r_value	/*; Everything = page 0*/
/*      0	KRAM page for SCSI */
/*      8	KRAM page for BG */
/*     16	KRAM page for RAINBOW */
/*     24	KRAM page for ADPCM */
	out.h r_register, KING_reg[r0]
	out.w r_value, KING_dat[r0]

	movw KING_BG_MODE, r_register	/*; BG mode*/
	movw (KING_mode_4block<<0 | 0<<4 | 0<<8 | 0<<12), r_value /*= 0x11*/
    out.h r_register, KING_reg[r0]
	out.h r_value, KING_dat[r0]

	movw KING_BG_PRIO, r_register	/*; BG priority*/
	movw (KING_prio_first | KING_prio_hidden<<3 | KING_prio_hidden<<6 | KING_prio_hidden<<9), r_value  /*; (binary 001 010)*/
    out.h r_register, KING_reg[r0]
	out.h r_value, KING_dat[r0]

	movw KING_MICRO_CTRL, r_register	/*; Microprogram control*/
	mov 0, r_value	/*; Running = off*/
	out.h r_register, KING_reg[r0]
	out.h r_value, KING_dat[r0]
	
	movw KING_MICRO_ADR, r_register	/*; Microprogram write address*/
	mov 0, r_value	/*; Address*/
	out.h r_register, KING_reg[r0]
	out.h r_value, KING_dat[r0]
	
	movw .kingMicroprogram, r_tmp_adr
	movw 16, r_tmp_loop
.microprogramLoop:
	movw KING_MICRO_DATA, r_register	/*; Microprogram data*/
	ld.h 0[r_tmp_adr], r_value
	out.h r_register, KING_reg[r0]
	out.h r_value, KING_dat[r0]
	
	add 2, r_tmp_adr
	add -1, r_tmp_loop
	bnz .microprogramLoop
	
	movw KING_MICRO_CTRL, r_register	/*; Microprogram control*/
	mov 1, r_value/*	; Running = on*/
	out.h r_register, KING_reg[r0]
	out.h r_value, KING_dat[r0]
	
	movw KING_BG_SCROLL, r_register	/*; BG scroll mode*/
	mov 0b0000, r_value	/*; BG0/1 = single background area*/
	out.h r_register, KING_reg[r0]
	out.h r_value, KING_dat[r0]

	movw KING_BG0_CG, r_register/*	; BG0 CG address*/
	mov 0, r_value# * 1024
	out.h r_register, KING_reg[r0]
	out.h r_value, KING_dat[r0]
 	
 	movw KING_BG0_BAT, r_register	
 	movw 0x40, r_value # * 1024
 	out.h r_register, KING_reg[r0]
	out.h r_value, KING_dat[r0]

	movw KING_BG0_size, r_register	/*; BG0 size*/
	movw ((KING_size_256 << KING_b_height) | (KING_size_256 << KING_b_width)) , r_value	/*; 512*512*/
	out.h r_register, KING_reg[r0]
	out.h r_value, KING_dat[r0]

	movw KING_BG0_X, r_register	/*; BG0 X scroll*/
	mov -5, r_value
	out.h r_register, KING_reg[r0]
	out.h r_value, KING_dat[r0]
	
	movw KING_BG0_Y, r_register	/*; BG0 Y scroll*/
	movw -5, r_value
	out.h r_register, KING_reg[r0]
	out.h r_value, KING_dat[r0]
	
	#actually, the BIOS should have set all of these already
	mov SUP_HSYNC, r_register
	movw 0x0202, r_value/*	; Eris and MagicKit say 0x202*/
	out.h r_register, SUPA_reg[r0]
	out.h r_value, SUPA_dat[r0]
	
	mov SUP_HDISP, r_register
	movw 0x041f, r_value	/*; Eris says 0x41F, MagicKit says 0x31F*/
	out.h r_register, SUPA_reg[r0]
	out.h r_value, SUPA_dat[r0]
	
	mov SUP_VSYNC, r_register
	movw 0x1102, r_value	/*; Eris says 0x1102, MagicKit says 0xF02*/
	out.h r_register, SUPA_reg[r0]
	out.h r_value, SUPA_dat[r0]
	
	mov SUP_VDISP, r_register
	movw 0xEF, r_value	/*; Eris and MagicKit say 0xEF*/
	out.h r_register, SUPA_reg[r0]
	out.h r_value, SUPA_dat[r0]
	
	mov SUP_VDISPEND, r_register
	mov 2, r_value/*	; Eris says 2, MagicKit says 3*/
	out.h r_register, SUPA_reg[r0]
	out.h r_value, SUPA_dat[r0]

    ret
#====================================		
push_charset:
    movw 0x10c0, r_tmp_loop
	movw data_charset, r_tmp_adr

	mov KING_KRAM_ADR_write, r_register
	movw (0x00000 | (1 << KING_b_inc)) , r_value
	out.h r_register, KING_reg[r0]
	out.w r_value, KING_dat[r0]
	
	mov KING_KRAM_rw, r_register
    out.h r_register, KING_reg[r0]
.tloop3:
	ld.w 0x0[r_tmp_adr], r_value
	out.w r_value, (KING_dat)[r0]
	add 4, r_tmp_adr 
	add -4, r_tmp_loop
	bnz .tloop3
	ret
#====================================
put_palette:    
    movw 2, r_tmp_loop	
	movw data_palette, r_tmp_adr
	mov HuC6261_PAL_DATA, r_register	
	out.h r_register, HuC6261_reg[r0]
.nextTetsuPaletteEntry:
	ld.h 0[r_tmp_adr], r_value
	out.h r_value, HuC6261_dat[r0]
	add 2, r_tmp_adr
	add -1, r_tmp_loop
	bnz .nextTetsuPaletteEntry    
	ret
#====================================	
.align 2    
#=====================
client_code:
    #plot version number
    movw 26, r_screenx
    movw 25, r_screeny #start on line 1 because of over/underscan
    #consecutive blocks can simply add 1 to this register!
    movw VERSION, r_value
    call plot_r_value
    mov 1, r_screeny #start on line 1 because of over/underscan
    
cmd_loop:
    movw 20, r_tmp
    cmp  r_tmp, r_screeny   
    blt 1f                 # TODO: does this work? We will see :)
    mov 1, r_screeny
1:
    
    call ReadPad1          # get possible command into r_keypad
    mov 1, r_screenx
    mov r_keypad, r_value
    call plot_r_value              # plot last KEYPAD input, will be the last command during running it
                                   # TODO: use an actual written command word here later
    
    movw 0x44414552 r_tmp          # READ (endian-reversed)
    cmp r_keypad, r_tmp
    bz  read_command

    movw 0x52424452 r_tmp          # RDBR (read BRAM type) (endian-reversed)
    cmp r_keypad, r_tmp
    bz  readbram_command

    movw 0x54495257 r_tmp          # WRIT (endian-reversed)
    cmp r_keypad, r_tmp
    bz  write_command

    movw 0x52425257 r_tmp          # WRBR (read BRAM type) (endian-reversed)
    cmp r_keypad, r_tmp
    bz  writebram_command

    movw 0x43455845 r_tmp          # EXEC (Execute) (endian-reversed)
    cmp r_keypad, r_tmp
    bz  exec_command
    
    br  cmd_loop


#=====================
exec_command:
    call ReadPad1          # get address
    ldsr    r0,chcw
    movea   0x8001,r0,r1
    ldsr    r1,chcw
    mov     2,r1 #re-enable
    ldsr    r1,chcw
    ldsr    r0,chcw #disable

    #disable all interrupts
    stsr	PSW, r_tmp /*current sys reg */
    movw	(1<<12),  r_tmp_data /*1<<12 = 0x1000*/
	or	r_tmp, r_tmp_data /*keep formerly set bits*/
	ldsr	r_tmp_data, PSW
   
    mov HuC6261_SCREENMODE, r_register	
	movw ( HuC6261_line262 | HuC6261_intsync | HuC6261_256px ), r_value
	out.h r_register, HuC6261_reg[r0]
	out.h r_value   , HuC6261_dat[r0]
	
    mov r_keypad, r6
    movw 0xfff0016c, r_keypad
    jmp [r_keypad]

#=====================
read_command:
    call ReadPad1          # get address
    mov r_keypad, r_ptr
    
    mov 8, r_screenx       # plot address
    mov r_keypad, r_value
    call plot_r_value
    
    call ReadPad1          # get length
    mov r_keypad, r_len
    mov 14, r_screenx       # plot address
    mov r_keypad, r_value
    call plot_r_value
    
    call send_block
    add 1, r_screeny        #next block displays next line
    br  cmd_loop
#=====================
readbram_command:
    call ReadPad1          # get address
    mov r_keypad, r_ptr

    call ReadPad1          # get length
    mov r_keypad, r_len

# unlock BRAM
    mov 3, r_tmp	   # unlock backup RAM and external backup RAM
    out.h r_tmp, 0xc80[r0] # port for access control

    call send_bram

    br  cmd_loop
#=====================
write_command:
    call ReadPad1          # get address
    mov r_keypad, r_ptr

    mov 8, r_screenx       # plot address
    mov r_keypad, r_value
    call plot_r_value
    
    call ReadPad1          # get length
    mov r_keypad, r_len

    mov 14, r_screenx       # plot address
    mov r_keypad, r_value
    call plot_r_value
    
    call recv_block
    add 1, r_screeny        #next block displays next line
    br  cmd_loop
#=====================
writebram_command:
    call ReadPad1          # get address
    mov r_keypad, r_ptr

    call ReadPad1          # get length
    mov r_keypad, r_len

# unlock BRAM
    mov 3, r_tmp	   # unlock backup RAM and external backup RAM
    out.h r_tmp, 0xc80[r0] # port for access control

    call recv_bram

    br  cmd_loop
#=====================

#------------------------------------
# r_ptr should hold the pointer to the data to be sent
# r_len should hold the length of data to be sent (in bytes)
send_bram:
    movw sendword, r_tmpptr

send_bramloop:
    call wait
    ld.b 0[r_ptr], r_tmp
    st.b r_tmp, 0[r_tmpptr]
    ld.b 2[r_ptr], r_tmp
    st.b r_tmp, 1[r_tmpptr]
    ld.b 4[r_ptr], r_tmp
    st.b r_tmp, 2[r_tmpptr]
    ld.b 6[r_ptr], r_tmp
    st.b r_tmp, 3[r_tmpptr]

    ld.w 0[r_tmpptr], r_tmp
    call send_value_pad1
    add 8, r_ptr
    add -4, r_len
    bp send_bramloop
    ret    

.align 4
sendword:
.word  0

#------------------------------------
# r_ptr should hold the pointer to the data to be sent
# r_len should hold the length of data to be sent (in bytes)
send_block:
    call wait
    ld.w 0[r_ptr], r_tmp
    call send_value_pad1
    add 4, r_ptr
    add -4, r_len
    bp send_block
    ret    
#------------------------------------
# r_tmp should hold the data value to be sent
#
send_value_pad1:
    out.w r_tmp, 0xc0[r0] #set data line
    mov 1, r_keypad	# 1 = send out
    out.h r_keypad, 0x80[r0]
    call wait_for_pad1_ready
    ret    
#-----------------------------------
# r_ptr should hold the pointer to where the data is to be sent
# r_len should hold the length of data to be sent (in bytes)
#
recv_bram:
    cmp r0,r_len
    bz rcvbrm_done
    movw sendword, r_tmpptr

rcvbrm_loop:
    call wait
    call ReadPad1

    st.w r_keypad, 0[r_tmpptr]

    ld.b 0[r_tmpptr], r_tmp
    st.b r_tmp, 0[r_ptr]
    ld.b 1[r_tmpptr], r_tmp
    st.b r_tmp, 2[r_ptr]
    ld.b 2[r_tmpptr], r_tmp
    st.b r_tmp, 4[r_ptr]
    ld.b 3[r_tmpptr], r_tmp
    st.b r_tmp, 6[r_ptr]

    add 8, r_ptr
    add -4, r_len
    bz rcvbrm_done
    bp rcvbrm_loop

rcvbrm_done:
    ret
#-----------------------------------
# r_ptr should hold the pointer to where the data is to be sent
# r_len should hold the length of data to be sent (in bytes)
#
recv_block:
    cmp r0,r_len
    bz recv_done

rcvblk_loop:
    call wait
    call ReadPad1
    st.w r_keypad, 0[r_ptr]
    add 4, r_ptr
    add -4, r_len
    bz recv_done
    bp rcvblk_loop

recv_done:
    ret
#-----------------------------------
#------------------------------------    
ReadPad1:
    mov 5, r_keypad	# 5 = Transmit enable + receive enable*/
	out.h r_keypad, 0x80[r0]
1:	
	in.h 0x80[r0], r_keypad
	andi 9, r_keypad, r_keypad
	cmp 1, r_keypad	
	bz 1b
	in.w 0xc0[r0], r_keypad
	ret
#---------------------------------
oldReadPad1:
    mov 5, r_keypad	# 5 = Transmit enable + receive enable*/
    out.h r_keypad, 0x80[r0]
    call wait_for_pad1_ready
    in.w 0xc0[r0], r_keypad
    ret
#------------------------------------
wait_for_pad1_ready:	
    in.h 0x80[r0], r_keypad
    andi 9, r_keypad, r_keypad
    cmp 1, r_keypad	
    bz wait_for_pad1_ready
    ret    
#-----------------------------------
wait:
    #this could be significantly shorter or even omitted but 
    #but also it doesn't cost much either
    movw 0x100, r_tmp
wloop:
    add -1, r_tmp
    bne wloop
    ret
#------------------------------------    
ReadPad0:	
    mov 5, r_keypad	# 5 = Transmit enable + receive enable*/
	out.h r_keypad, 0x00[r0]
wait_for_pad0_ready:	
	in.h 0x00[r0], r_keypad
	andi 9, r_keypad, r_keypad
	cmp 1, r_keypad	
	bz wait_for_pad0_ready
	in.w 0x40[r0], r_keypad
	ret

#------------------------------------
plot_r_value:  
    #movw 0x12345678, r_value
    mov r_screeny, r_tmp_loop
    shl 5, r_tmp_loop #only *32 as KING_KRAM_ADR_write is in half-words!
    
    mov r_value, r_tmp_adr
    #separate 4 bytes of value and output one by one
 
    mov KING_KRAM_ADR_write, r_register
	movw ((0x010000)| (1 << KING_b_inc)) , r_tmp_data
	add r_tmp_loop, r_tmp_data
	add r_screenx, r_tmp_data
	
	out.h r_register, KING_reg[r0]
	out.w r_tmp_data, KING_dat[r0]
	
	mov KING_KRAM_rw, r_register
    out.h r_register, KING_reg[r0]
    
    mov r_tmp_adr, r_tmp_loop
    shr 24, r_tmp_loop
    andi 0xff, r_tmp_loop, r_tmp_loop
    out.h r_tmp_loop, (KING_dat)[r0]
    
    mov r_tmp_adr, r_tmp_loop
    shr 16, r_tmp_loop
    andi 0xff, r_tmp_loop, r_tmp_loop
    out.h r_tmp_loop, (KING_dat)[r0]
    
    mov r_tmp_adr, r_tmp_loop
    shr 8, r_tmp_loop
    andi 0xff, r_tmp_loop, r_tmp_loop
    out.h r_tmp_loop, (KING_dat)[r0]
    
    andi 0xff, r_tmp_adr, r_tmp_loop
    out.h r_tmp_loop, (KING_dat)[r0]
    
    ret	

	
.hword 0x55aa
.hword 0x77bb
.hword 0x55aa
.hword 0x77bb

client_code_end:
#===================================
.align 2
.kingMicroprogram:
.hword 0x0010 #+1<<6	#+0 from BAT read
.hword 0x0100 	#NOP
.hword 0x0008 #+1<<6	#+0 from BAT CG is accessed
.hword 0x0100 	#NOP
.hword 0x0100 	#NOP
.hword 0x0100	/*; NOP                           */
.hword 0x0100	/*; NOP                           */
.hword 0x0100	/*; NOP                           */
.hword 0x0100	/*; NOP                           */
.hword 0x0100	/*; NOP                           */
.hword 0x0100	/*; NOP                           */
.hword 0x0100	/*; NOP                           */
.hword 0x0100	/*; NOP                           */
.hword 0x0100	/*; NOP                           */
.hword 0x0100	/*; NOP                           */
.hword 0x0100	/*; NOP                           */

#===================================================
.align 2
data_charset:
.incbin "hexfont4.dat"

.align 2
data_palette:
.hword 0x0088 
.hword 0xff0f #font color

.hword 0x55aa
.hword 0x77bb
#==================================================
		
