/**
 * Copyright (c) 2020 Raspberry Pi (Trading) Ltd.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include <stdio.h>

#include "pico/stdlib.h"
#include "hardware/pio.h"
#include "hardware/uart.h"
#include "pcfxplex.pio.h"
#include "clock.pio.h"

//--------------------------------------------------------------------+
// MACRO CONSTANT TYPEDEF PROTYPES
//--------------------------------------------------------------------+


#define UART_ID uart0
#define BAUD_RATE 115200

// We are using pins 0 and 1, but see the GPIO function select table in the
// datasheet for information on which other pins can be used.
#define UART_TX_PIN 0
#define UART_RX_PIN 1


#ifdef SEEED_XIAO_RP2040         // else assignments for Seed XIAO RP2040 board

#define DATAIN_PIN      6
#define CLKIN_PIN       DATAIN_PIN + 1
#define DATAOUT_PIN     26
#define LATCHIN_PIN     27
#define READWRITE_PIN   28       // determines data direction

#define PICO_LED1       17
#define PICO_LED2       16
#define PICO_LED3       25
#define PICO_LED_ON     0
#define PICO_LED_OFF    1

#endif



uint32_t magic_word = 0x12345678;

uint32_t start_addr = 0x00008000;
uint32_t num_bytes  = 0;

uint32_t payload_data[32767];


PIO pio;
uint sm1, sm2;   // sm1 = plex, sm2 = clock


uint8_t uart_get_char(void)
{
int inchar;

   inchar = getchar_timeout_us(0);
//   inchar = uart_getc(UART_ID);

   while (inchar == PICO_ERROR_TIMEOUT)
      inchar = getchar_timeout_us(0);

   return((uint8_t)inchar);
}

//
// Find the 'magic word' by scanning the UART stream first for the initial byte,
// and then checking whether the next 3 bytes form the word; if not, then start over
//
uint32_t uart_get_magic_word(void)
{
uint32_t uart_word = 0;
uint8_t  uart_byte = 0;

   while (uart_word != magic_word) {
      uart_word = 0;

      while (uart_byte != (uint8_t)(magic_word & 0xff))
         uart_byte = uart_get_char();

      uart_word |= uart_byte;

      uart_byte = uart_get_char();
      uart_word |= (uart_byte << 8);

      uart_byte = uart_get_char();
      uart_word |= (uart_byte << 16);

      uart_byte = uart_get_char();
      uart_word |= (uart_byte << 24);
   }

   return(uart_word);
}

uint32_t uart_get_word(void)
{
uint32_t uart_word = 0;
uint8_t  uart_byte = 0;

   uart_byte = uart_get_char();
   uart_word |= uart_byte;

   uart_byte = uart_get_char();
   uart_word |= (uart_byte << 8);

   uart_byte = uart_get_char();
   uart_word |= (uart_byte << 16);

   uart_byte = uart_get_char();
   uart_word |= (uart_byte << 24);

   return(uart_word);
}

void load_from_uart(int led)
{
uint32_t inword;
int index = 0;
int count = 0;

    inword = uart_get_magic_word();
    gpio_put(led, PICO_LED_ON); // start of transmission

//    start_addr = uart_get_word();  // this is not sent from PC
    start_addr = 0x00008000;
    printf("Start_addr = %8.8X\n", start_addr);

    num_bytes  = uart_get_word();
    printf("num_bytes  = %8.8X\n", num_bytes);

    count = num_bytes;
    //count = 2;
    while(count > 0) {
      if (count == ((count / 1000) * 1000))
         printf("count = %d\n", count);

      payload_data[index++] = uart_get_word();
      count -= 4;
    }

    gpio_put(led, PICO_LED_OFF);
}

void read_from_pcfx(int led)
{
uint32_t inword;
uint32_t indata;

    gpio_put(led, PICO_LED_ON); // start of transmission

    while(1) {
      inword = pio_sm_get_blocking(pio, sm1);
      indata = ~inword;
      printf("word: %8.8X\n", indata);
    }
}

void write_to_pcfx(int led)
{
uint32_t outword;
int index = 0;
int count = 0;

    gpio_put(led, PICO_LED_ON); // start of transmission
    sleep_ms(1000);
    // note that PC-FX inverts on input, so we need to send all data as 1's complement
    outword = ~magic_word;
    pio_sm_put_blocking(pio, sm1, outword);

    outword = ~start_addr;
    pio_sm_put_blocking(pio, sm1, outword);

    outword = ~start_addr;   // this instance is the execution address
    pio_sm_put_blocking(pio, sm1, outword);

    outword = ~num_bytes;
    pio_sm_put_blocking(pio, sm1, outword);

    count = (num_bytes / 4) + 1;
    for (index = 0; index < count; index++) {
       outword = ~payload_data[index];
       pio_sm_put_blocking(pio, sm1, outword);
       gpio_put(PICO_LED1, PICO_LED_ON);
    }
    gpio_put(led, PICO_LED_OFF);
}

int main() {

int a;
uint32_t outword;

    stdio_init_all();

//// UART
    // Set up our UART with the required speed.
    uart_init(UART_ID, BAUD_RATE);
    uart_set_translate_crlf(UART_ID, false);

    // Set the TX and RX pins by using the function select on the GPIO
    // Set datasheet for more information on function select
    gpio_set_function(UART_TX_PIN, GPIO_FUNC_UART);
    gpio_set_function(UART_RX_PIN, GPIO_FUNC_UART);
////

    gpio_init(PICO_LED1);
    gpio_init(PICO_LED2);
    gpio_init(PICO_LED3);

    gpio_set_dir(PICO_LED1, GPIO_OUT);
    gpio_set_dir(PICO_LED2, GPIO_OUT);
    gpio_set_dir(PICO_LED3, GPIO_OUT);

    gpio_put(PICO_LED1, PICO_LED_OFF);
    gpio_put(PICO_LED2, PICO_LED_OFF);
    gpio_put(PICO_LED3, PICO_LED_OFF);

    // Both state machines can run on the same PIO processor
    pio = pio0;


    sleep_ms(200);  // allow GPIO values to settle before initating PIOs

    // Load the plex (multiplex output) program, and configure a free state machine
    // to run the program.

    uint offset1 = pio_add_program(pio, &pcfxplex_program);
    sm1 = pio_claim_unused_sm(pio, true);
    pcfxplex_program_init(pio, sm1, offset1, DATAIN_PIN, DATAOUT_PIN, READWRITE_PIN);

    uint offset2 = pio_add_program(pio, &clock_program);
    sm2 = pio_claim_unused_sm(pio, true);
    clock_program_init(pio, sm2, offset2, LATCHIN_PIN);


// wait at startup
//
    sleep_ms(3000);

    pio_sm_clear_fifos(pio, sm1);  // in case startup placed junk in FIFOs
    pio_sm_clear_fifos(pio, sm1);  // in case it was blocked on PUSH (one last word to drain)

    outword = ~0;
    pio_sm_put_blocking(pio, sm1, outword);

// Now flash LED(s) to signify all is well
//
    gpio_put(PICO_LED1, PICO_LED_ON); // signal ready  (RED)
    sleep_ms(500);
    gpio_put(PICO_LED1, PICO_LED_OFF); // signal ready

    gpio_put(PICO_LED2, PICO_LED_ON); // signal ready
    sleep_ms(500);
    gpio_put(PICO_LED2, PICO_LED_OFF);

    gpio_put(PICO_LED3, PICO_LED_ON); // signal ready (BLUE)
    sleep_ms(500);
    gpio_put(PICO_LED3, PICO_LED_OFF); // signal ready

    // Show green while data transfer (PC->MCU) is happening
    load_from_uart(PICO_LED2);

    sleep_ms(1000);

    // Show blue while data transfer (MCU->PC-FX) is happening
    write_to_pcfx(PICO_LED3);

    // Show red while data transfer (PC-FX->MCU) is happening
//    printf("READY\n");
//    read_from_pcfx(PICO_LED1);

    return 0;
}
