#(c) 2022 Martin Wendt
#Test sender for dshadoff 10.10.2022

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
.equiv r_tmp,    r14
#===============================

.org = 0x1000
_start = 0x1000
Start:

    movw 0x200000, sp
    movw 0x1000, gp
    
    mov     2, r22 #enable cache
    ldsr    r22, 24
    
    jal mypcfxReadPad0
    mov r_keypad, r_tmp
wait_for_start:
    jal mypcfxReadPad0 
    cmp r_tmp, r_keypad
    bz wait_for_start
    
    jal wait
loop:    
    jal push_value
    jal wait
    br loop
#------------------------------------
push_value:
    movw 0x10ccaa55, r_tmp
    out.w r_tmp, 0xc0[r0] #set data line
    mov 1, r_keypad	# 1 = send out
	out.h r_keypad, 0x80[r0]
    ret    
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
mypcfxReadPad0:	
    mov 5, r_keypad	# 5 = Transmit enable + receive enable*/
	out.h r_keypad, 0x00[r0]
wait_for_input_ready:	
	in.h 0x00[r0], r_keypad
	andi 9, r_keypad, r_keypad
	cmp 1, r_keypad	
	bz wait_for_input_ready
	in.w 0x40[r0], r_keypad
	ret
	
.hword 0x55aa
.hword 0x77bb
loader_code_end:    
	
