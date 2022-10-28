#(c) 2022 Martin Wendt
.macro  push reg1
        add     -4, sp
        st.w    \reg1, 0x0[sp]
.endm

.macro  pop reg1
        
        ld.w    0x0[sp], \reg1
        add     4, sp
.endm

.macro  movw data, reg1
        movhi   hi(\data),r0,\reg1
        movea   lo(\data),\reg1,\reg1
        
        /* could be made smarter to omit if not required */
.endm

.macro  call target
        push r31
        jal \target
        pop r31
.endm

.macro  ret
        jmp [r31]
.endm

.macro  jump target
        movw    \target, r30
        jmp     [r30]
.endm
#===============================
.equiv r_keypad, r29
.equiv r_dest,   r10
.equiv r_len ,   r11
.equiv r_exec ,  r12
.equiv r_magic,  r13
.equiv r_tmp,    r14
#===============================
.globl _start
.org = 0x8000
_start = 0x8000
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
.align 2
loader_code:    
    
    movw 0x12345678, r_magic
  
wait_for_start:
    jal mypcfxReadPad2 
    cmp r_magic, r_keypad
    bne wait_for_start
    
    call wait
    jal mypcfxReadPad2
    mov r_keypad, r_dest

    call wait
    jal mypcfxReadPad2 
    mov r_keypad, r_exec
    
block_loop:
    call wait
    jal mypcfxReadPad2 
    mov r_keypad, r_len
    cmp r0,r_len
    bz blocks_done
    
load_loop:
    call wait
    jal mypcfxReadPad2 
    st.w r_keypad, 0[r_dest]
    add 4, r_dest
    add -4, r_len
    bp load_loop
#get next length until length = 0
    #br block_loop
    #for now, only load a single block, limited to ~25kb MC RAM
    
blocks_done:    
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
wait_for_input_ready:	
	in.h 0x80[r0], r_keypad
	andi 9, r_keypad, r_keypad
	cmp 1, r_keypad	
	bz wait_for_input_ready
	in.w 0xc0[r0], r_keypad
	ret
	
.hword 0x55aa
.hword 0x77bb
loader_code_end:    
	
