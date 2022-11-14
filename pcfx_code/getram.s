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
    
#=====================

cmd_loop:
    call ReadPad1          # get possible command

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
    jmp [r_keypad]

#=====================
read_command:
    call ReadPad1          # get address
    mov r_keypad, r_ptr

    call ReadPad1          # get length
    mov r_keypad, r_len

    call send_block

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

    call ReadPad1          # get length
    mov r_keypad, r_len

    call recv_block

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
ReadPad1:
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
	
.hword 0x55aa
.hword 0x77bb
loader_code_end:    
	
