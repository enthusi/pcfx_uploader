#(c) 2022 Martin Wendt
.include "macros.s"
.include "defines.s"
.include "version.s"

#READ + start addr + length + { block }
#WRIT + start addr + length + { block }
#RDBR (same as read, but every second byte)
#WRBR (same as writ, but every second byte)
#EXEC + address (edited)

#===============================
.equiv r_keypad, r29
.equiv r_dest,   r10
.equiv r_len ,   r11
.equiv r_exec ,  r12
.equiv r_magic,  r13
.equiv r_tmp,    r14
.equiv r_register, r6    
.equiv r_value,    r7    
.equiv r_tmp_loop, r20
.equiv r_tmp_adr,  r21
.equiv r_tmp_data, r22

.equiv r_screenx, r15
.equiv r_screeny, r16


#===============================
.globl _start
.org = 0x8000
_start = 0x8000
Start:

    movw 0x200000, sp
    movw 0x8000, gp
    
    #disable, clear, enable cache
    #hint from Elmer: CD-DMA during boot may have invalidated it!
    ldsr    r0,chcw
    movea   0x8001,r0,r1
    ldsr    r1,chcw
    mov     2,r1
    ldsr    r1,chcw
    
    call setup_display
    
    movw loader_code, r10
    movw 0x1000, r11
    movea (loader_code_end - loader_code),r0, r12
    movw 0x1000, r14
    
loop:
    ld.w 0[r10],r13
    st.w r13,0[r11]
    add 4, r10
    add 4, r11
    add -4, r12
    bp loop
    jmp [r14]
    
#====================================
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
    movw 0x1040, r_tmp_loop
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
loader_code:    
     #plot version number
    mov 0, r_screenx
    mov 1, r_screeny #start on line 1 because of over/underscan
    #consecutive blocks can simply add 1 to this register!
    movw VERSION, r_value
    call plot_r_value

block_loop:    
	add 1, r_screeny
    movw 0x12345678, r_magic
  
wait_for_start:
    jal mypcfxReadPad1 
    mov 0, r_screenx
    mov r_keypad, r_value
    call plot_r_value
    
    jal mypcfxReadPad2 
    mov 8, r_screenx
    #mov 0, r_screeny
    mov r_keypad, r_value
    call plot_r_value
    
    cmp r_magic, r_keypad
    bne wait_for_start
    
    call wait
    jal mypcfxReadPad2
    mov r_keypad, r_dest

    mov 0, r_screenx
    #mov 0, r_screeny
    mov r_dest, r_value
    call plot_r_value
    
    call wait
    jal mypcfxReadPad2 
    mov r_keypad, r_exec
    
    mov 8, r_screenx
    #mov 0, r_screeny
    mov r_exec, r_value
    call plot_r_value

    call wait
    jal mypcfxReadPad2 
    mov r_keypad, r_len
    
    movw 16, r_screenx
    #mov 0, r_screeny
    mov r_len, r_value
    call plot_r_value
    
    #for later multi block load
    cmp r0,r_len
    bz blocks_done
    
load_loop:
    call wait
    jal mypcfxReadPad2 
    st.w r_keypad, 0[r_dest]
    
    movw 24, r_screenx
    #mov 0, r_screeny
    mov r_dest, r_value
    call plot_r_value
    
    add 4, r_dest
    add -4, r_len
    bp load_loop
    
    #get next length until length = 0
    #br block_loop
    #for now, only load a single block, limited to MC RAM!
    
blocks_done:
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

	mov r_exec, r6
	movw 0xfff0016c, r_exec
    jmp [r_exec]
#------------------------------------    
wait:
    #this could be significantly shorter or even omitted but 
    #but also it doesn't cost much either
    movw 0x100, r_tmp
wloop:
    add -1, r_tmp
    bne wloop
    ret
#------------------------------------    
mypcfxReadPad2:	
    mov 5, r_keypad	# 5 = Transmit enable + receive enable*/
	out.h r_keypad, 0x80[r0]
1:	
	in.h 0x80[r0], r_keypad
	andi 9, r_keypad, r_keypad
	cmp 1, r_keypad	
	bz 1b
	in.w 0xc0[r0], r_keypad
	ret
#------------------------------------    
mypcfxReadPad1:	
    mov 5, r_keypad	# 5 = Transmit enable + receive enable*/
	out.h r_keypad, 0x00[r0]
1:	
	in.h 0x00[r0], r_keypad
	andi 9, r_keypad, r_keypad
	cmp 1, r_keypad	
	bz 1b
	in.w 0x40[r0], r_keypad
	ret
#------------------------------------  
#============================    
plot_r_value:  
    #movw 0x12345678, r_value
    mov r_screeny,r_tmp_loop
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

#===================================
.hword 0x55aa
.hword 0x77bb
loader_code_end:  
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
.space 64 , 0x00

.align 2
data_palette:
.hword 0x0088 
.hword 0xff0f #font color

.hword 0x55aa
.hword 0x77bb
#==================================================

  
	
