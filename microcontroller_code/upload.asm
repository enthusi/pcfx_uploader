#(c) 2022 Martin Wendt
include gd32vf103.asm

RAM = 0x20000000
MEM_SIZE = 0x8000
STACK = RAM + MEM_SIZE
STACK_SIZE = 0x200
VAR_BUFFER_SIZE = 0x100
VARIABLES = RAM + MEM_SIZE - STACK_SIZE - VAR_BUFFER_SIZE

VAR_VALUE = 0

DATA_BUFFER = RAM + 0x0000

CLOCK_FREQ = 108000000  # NON default GD32BF103 clock freq
USART_BAUD = 115200   # desired USART baud rate

#PORT B now
PCFX_CLOCK = 0 
PCFX_LATCH = 1
PCFX_DATA  = 10

#----------------------------------
    li sp, STACK
    li gp, VARIABLES
    
    call rcu_init2
    # enable RCU (GPIO ports A and B!)
    li a0, RCU_BASE_ADDR
    li a1, RCU_APB2EN_USART0EN | RCU_APB2EN_PAEN | RCU_APB2EN_AFEN | RCU_APB2EN_PBEN | RCU_APB2EN_PCEN
    call rcu_init
    
#configure the 3 GPIO pins
#using port B for PC-FX and A for UART (since port A uses AF mode)

    li s2, GPIO_BASE_ADDR_B
    li a1, GPIO_MODE_IN_FLOAT
    li s5, PCFX_CLOCK
    jal gpio_pin_config
    
    li s2, GPIO_BASE_ADDR_B
    li a1, GPIO_MODE_IN_FLOAT
    li s5, PCFX_LATCH
    jal gpio_pin_config
    
    li s2, GPIO_BASE_ADDR_B
    li a1, GPIO_MODE_PP_50MHZ
    li s5, PCFX_DATA
    jal gpio_pin_config
   
#configure the UART part:
# enable TX pin
    li s2, GPIO_BASE_ADDR_A
    li a1, GPIO_MODE_AF_PP_50MHZ
    li s5, 9
    call gpio_pin_config

    # enable RX pin
    li s2, GPIO_BASE_ADDR_A
    li a1, GPIO_MODE_IN_FLOAT
    li s5, 10
    call gpio_pin_config

    # enable USART0
    li a0, USART_BASE_ADDR_0
    li a1, CLOCK_FREQ // USART_BAUD
    call usart_init
    
#=============================================    
begin:
   li, s4,0x12345678
transfer_loop:    
    call fetch_word #to a1
    bne a1,s4,transfer_loop #wait for magic word from PC
    
    call fetch_word #length in a1
    sw a1,VAR_VALUE(gp)
    beqz a1, transfer_done #if length of block=0 we are done
    
    call load_to_ram #fetch #LENGTH bytes from PC
    
    #buffer is filled, we can now send
    call send_header #3 header words (magic, start, exec)
    #those are hardcoded for convenience but
    #could as well be fetched from PC every time

    call send_to_pcfx #send all including LENGTH header
    
    #j transfer_loop #enable for multi-block loads
transfer_done:
    j transfer_done
#==========================================
load_to_ram: #a1 is length
    addi sp,sp,-16
    sw ra,0(sp)
    
    mv s5, a1 #length counter
    li a4, DATA_BUFFER
    sw a1, 0(a4) #first entry in buffer is LENGTH
    addi a4,a4,4 #first word is the block length!
    
fetch_loop:
    call fetch_word #uses a1,a2,s3 and in getc a0,a1,t0
    sw a1, 0(a4)
    addi a4,a4,4
    addi s5,s5,-4
    bgtz s5, fetch_loop
    
    lw ra, 0(sp)
    addi sp, sp, 16    
    ret
#==========================================
send_header:
    addi sp,sp,-16
    sw ra,0(sp)
    li s5, 3*4
    li s3, header_data
    call send_s5_bytes_from_s3
    lw ra, 0(sp)
    addi sp, sp, 16    
    ret
#==========================================    
send_to_pcfx: #a1 is length
    addi sp,sp,-16
    sw ra,0(sp)
    
    lw s5,VAR_VALUE(gp) #fetch length
    addi s5,s5,4 #the LENGTH word counts too
    li s3, DATA_BUFFER
    call send_s5_bytes_from_s3
    lw ra, 0(sp)
    addi sp, sp, 16    
    ret
#==================================
send_s5_bytes_from_s3: #no sub calls inside
    li a1, GPIO_BASE_ADDR_B
    li a2, (1 << PCFX_LATCH)
    li a3, (1 << PCFX_CLOCK)
    li s2, GPIO_BASE_ADDR_B
send_loop:    
wait_for_latch_low:    
    lw a4, GPIO_ISTAT_OFFSET(a1)
    and a5,a4,a2 
    bnez a5, wait_for_latch_low
wait_for_latch_highagain:    
    lw a4, GPIO_ISTAT_OFFSET(a1)
    and a5,a4,a2 
    beqz a5, wait_for_latch_highagain

#------------------------    
    lw s1, 0(s3) #this loads payload etc
    li a6,32
    li a7,0
word_loop:
    sra a5,s1,a7
    andi s0,a5,1
    beqz s0, data_low
data_high:    
    lw a5, GPIO_BC_OFFSET(s2)
    ori a5,a5, ( (1<<PCFX_DATA) )
    sw a5, GPIO_BC_OFFSET(s2)
    j both
data_low:
    lw a5, GPIO_BOP_OFFSET(s2)
    ori a5,a5, ( (1<<PCFX_DATA) )
    sw a5, GPIO_BOP_OFFSET(s2)
both:
wait_for_clock_low:    
    lw a4, GPIO_ISTAT_OFFSET(a1)
    and a5,a4,a3
    bnez a5, wait_for_clock_low
wait_for_clock_highagain:    
    lw a4, GPIO_ISTAT_OFFSET(a1)
    and a5,a4,a3
    beqz a5, wait_for_clock_highagain
    addi a7,a7,1
    addi a6,a6,-1
    bnez a6,word_loop
    addi s3, s3, 4 #move along the data buffer
    addi s5, s5, -4
    bgtz s5, send_loop
    ret
#===============================================
gpio_pin_config:
    # Func: gpio_init
    # Arg: s2 = GPIO port base addr
    # Arg: s5 = GPIO pin number
    # Arg: a1 = GPIO config (4 bits)

    # advance to CTL0
    addi t0, s2, GPIO_CTL0_OFFSET
    # if pin number is less than 8, CTL0 is correct
    slti t1, s5, 8
    bnez t1, gpio_config
    # else we need CTL1 and then subtract 8 from the pin number
    addi t0, t0, 4
    addi s5, s5, -8
gpio_config:
    # multiply pin number by 4 to get shift amount
    slli s5,s5,2
    # load current config
    lw t1, 0(t0)
    # align and clear existing pin config
    li t2, 0b1111
    sll t2, t2, s5
    not t2, t2
    and t1, t1, t2
    # align and apply new pin config
    sll a1, a1, s5
    or t1, t1, a1
    # store updated config
    sw t1, 0(t0)
    ret    
#========================

# Func: rcu_init
# Arg: a0 = RCU base addr
# Arg: a1 = RCU config
# Ret: none
rcu_init: #set clock to full 108 Mhz!
    # store config
    sw a1, RCU_APB2EN_OFFSET(a0)
rcu_init_done:
    ret
    
rcu_init2:
    li a5, RCU_BASE_ADDR
    lw a4, RCU_CFG0_OFFSET(a5)

    #first mask out relevant bits
    li a3, ~( RCU_CFG0_PLLMF_Msk | RCU_CFG0_PLLSEL | RCU_CFG0_AHBPSC_Msk | RCU_CFG0_APB2PSC_Msk | RCU_CFG0_APB1PSC_Msk)
    and	a4, a4, a3
    
    #set core clock!
    li a0, (RCU_CFG0_PLLMF_MUL27 | RCU_CFG0_APB1PSC_DIV2) 
    or a0, a4, a0
    sw a0, RCU_CFG0_OFFSET(a5)
    
    #in 2022
    #whats happening here
    #-The PLL clock multiplication factor set to x27
    #APB1 prescaler selection to /2
    
    lw a4, RCU_CTL_OFFSET(a5)
    li a3, RCU_CTL_PLLEN
    or a4, a4, a3
    sw a4, RCU_CTL_OFFSET(a5)
       
rcu_sysclk_pll_irc8m_loop1:
    lw a4, RCU_CTL_OFFSET(a5)
    slli a3, a4, 6 #while (!(RCU->CTL & RCU_CTL_PLLSTB))
    bgez a3, rcu_sysclk_pll_irc8m_loop1 #wait until PLL is stable
    
    #RCU->CFG0 = (RCU->CFG0 & ~RCU_CFG0_SCS_Msk) | RCU_CFG0_SCS_PLL;
    lw a4, RCU_CFG0_OFFSET(a5)
    andi a4, a4, ~RCU_CFG0_SCS_Msk
    ori a4, a4, RCU_CFG0_SCS_PLL
    sw a4, RCU_CFG0_OFFSET(a5)
    
    li a4, RCU_CFG0_SCSS_PLL
rcu_sysclk_pll_irc8m_loop2:
    lw a3, RCU_CFG0_OFFSET(a5) #wait until PLL is selected as system clock
    andi a3, a3, RCU_CFG0_SCSS_Msk #while ((RCU->CFG0 & RCU_CFG0_SCSS_Msk) != RCU_CFG0_SCSS_PLL)
    bne a3, a4, rcu_sysclk_pll_irc8m_loop2
    ret    
#===============================================
# Func: usart_init
# Arg: a0 = USART base addr
# Arg: a1 = USART clkdiv
# Ret: none
usart_init:
    # store clkdiv
    sw a1, USART_BAUD_OFFSET(a0)
    # enable USART (enable RX, enable TX, enable USART)
    li t0, USART_CTL0_UEN | USART_CTL0_TEN | USART_CTL0_REN
    sw t0, USART_CTL0_OFFSET(a0)
usart_init_done:
    ret

# Func: getc
# Arg: a0 = USART base addr
# Ret: a1 = character received (a1 here for simpler getc + putc loops)
getc:
   li a0, USART_BASE_ADDR_0
getcloop:    
    lw t0, USART_STAT_OFFSET(a0)  # load status into t0
    andi t0, t0, USART_STAT_RBNE  # isolate read buffer not empty (RBNE) bit
    beqz t0, getcloop                 # keep looping until ready to recv
    lw a1, USART_DATA_OFFSET(a0)  # load char into a1
getc_done:
    ret

# Func: putc
# Arg: a0 = USART base addr
# Arg: a1 = character to send
# Ret: none
putc:
    li a0, USART_BASE_ADDR_0
putcloop:
    lw t0, USART_STAT_OFFSET(a0)  # load status into t0
    andi t0, t0, USART_STAT_TBE   # isolate transmit buffer empty (TBE) bit
    beqz t0, putcloop             # keep looping until ready to send
    sw a1, USART_DATA_OFFSET(a0)  # write char from a1
putc_done:
    ret
#================================================
fetch_word:
    addi sp,sp,-16
    sw ra,0(sp)
    call getc
       
    mv s3,a1
    call getc
    slli a2,a1,8
    or s3,s3,a2
    
    call getc
    slli a2,a1,16
    or s3,s3,a2
    
    call getc
    slli a2,a1,24
    or s3,s3,a2
    mv a1,s3
    lw ra, 0(sp)
    addi sp, sp, 16
    ret
#===============================================
align 4
header_data:
dw 0x12345678 #magic header
dw 0x00008000 #destination
dw 0x00008000 #execute
