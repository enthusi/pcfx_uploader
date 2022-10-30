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
.equiv r_ptr,    r10
.equiv r_len,    r11
.equiv r_tmp,    r14
.equiv r_tmpptr, r15
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
    
    call mypcfxReadPad0
    mov r_keypad, r_tmp
#
# wait for user to kit a key on keypad0
#
wait_for_start:
    call mypcfxReadPad0 
    cmp r_tmp, r_keypad
    bz wait_for_start
    call wait
 
    mov 3, r_tmp	   # unlock backup RAM and external backup RAM
    out.h r_tmp, 0xc80[r0] # port for access control

#
# Send length on keypad1
#
    movw 0x00008000, r_tmp   # length = 32KB
    call send_value
    call wait

    movw 0x00008000, r_len   # length = 32KB
    movw 0xE0000000, r_ptr   # Backup memory
#    movw 0xFFF00000, r_ptr   # ROM address

send_loop:
#    call wait
#    ld.w 0[r_ptr], r_tmp
#    call send_value
#    add 4, r_ptr
#    add -4, r_len
#    bp send_loop
    call send_bram
    
    call wait
    call wait
    call wait
    call wait
    call wait
    call wait
    call wait

endloop:    
    mov 0x0000, r_tmp
    call push_value
    call wait
    br endloop

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
    call send_value
    add 8, r_ptr
    add -4, r_len
    bp send_bramloop
    ret    
sendword:
.hword  0
.hword  0

#------------------------------------
# r_ptr should hold the pointer to the data to be sent
# r_len should hold the length of data to be sent (in bytes)
send_block:
    call wait
    ld.w 0[r_ptr], r_tmp
    call send_value
    add 4, r_ptr
    add -4, r_len
    bp send_block
    ret    
#------------------------------------
# r_tmp should hold the data value to be sent
#
send_value:
    out.w r_tmp, 0xc0[r0] #set data line
    mov 1, r_keypad	# 1 = send out
	out.h r_keypad, 0x80[r0]
wait_for_send_ready:	
	in.h 0x80[r0], r_keypad
	andi 9, r_keypad, r_keypad
	cmp 1, r_keypad	
	bz wait_for_send_ready
    ret    
#-----------------------------------
push_value:
    movw 0x4F4B2000, r_tmp
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
	
