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
#include "ws2812.pio.h"

//--------------------------------------------------------------------+
// MACRO CONSTANT TYPEDEF PROTYPES
//--------------------------------------------------------------------+


#define UART_ID uart0
#define BAUD_RATE 115200

// We are using pins 0 and 1, but see the GPIO function select table in the
// datasheet for information on which other pins can be used.
#define UART_TX_PIN 0
#define UART_RX_PIN 1


#define IS_RGBW false
#define NUM_PIXELS 1


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

#define WS2812_PIN PICO_DEFAULT_WS2812_PIN

#endif


uint32_t magic_word = 0x12345678;

uint32_t start_addr = 0x00008000;
uint32_t num_bytes  = 0;

uint32_t payload_data[32767];


PIO pio, pioled;
uint sm1, sm2, smled;   // sm1 = plex, sm2 = clock


//// WS2812 "Neopixel" protocol transport
//
static inline void put_pixel(uint32_t pixel_grb) {
    pio_sm_put_blocking(pioled, smled, pixel_grb << 8u);
}

static inline uint32_t urgb_u32(uint8_t r, uint8_t g, uint8_t b) {
    return
            ((uint32_t) (r) << 8) |
            ((uint32_t) (g) << 16) |
            (uint32_t) (b);
}

/// UART
//
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

void load_from_uart(uint32_t led_color)
{
uint32_t inword;
int index = 0;
int count = 0;

    inword = uart_get_magic_word();
    put_pixel(led_color);

//    start_addr = uart_get_word();  // this is not sent from PC
    start_addr = 0x00008000;

#ifdef DEBUG_IT
    printf("Start_addr = %8.8X\n", start_addr);
#endif

    num_bytes  = uart_get_word();
#ifdef DEBUG_IT
    printf("num_bytes  = %8.8X\n", num_bytes);
#endif

    count = num_bytes;

    while(count > 0) {
#ifdef DEBUG_IT
      if (count == ((count / 1000) * 1000))
         printf("count = %d\n", count);
#endif

      payload_data[index++] = uart_get_word();
      count -= 4;
    }

    sleep_ms(1000);
    put_pixel(0x00000000);
}

void read_from_pcfx(uint32_t led_color_1, uint32_t led_color_2)
{
uint32_t inword;
uint32_t indata;
int index = 0;
int count;
int i;

    put_pixel(led_color_1);

    index = 0;

    count = ~(pio_sm_get_blocking(pio, sm1));

    if (count > 32768) count = 32768;

    while(index < count) {
      inword = pio_sm_get_blocking(pio, sm1);
      indata = ~inword;
//      printf("word: %8.8X\n", indata);

      payload_data[index++] = (uint8_t)(indata & 0xff);
      payload_data[index++] = (uint8_t)((indata >> 8) & 0xff);
      payload_data[index++] = (uint8_t)((indata >> 16) & 0xff);
      payload_data[index++] = (uint8_t)((indata >> 24) & 0xff);
    }

    sleep_ms(10);
    put_pixel(led_color_2);

    putchar_raw((int)((count >> 8) & 0xff));
    putchar_raw((int)(count & 0xff));

    for (i = 0; i < count; i+=4) {
      putchar_raw((int)payload_data[i]);
      putchar_raw((int)payload_data[i+1]);
      putchar_raw((int)payload_data[i+2]);
      putchar_raw((int)payload_data[i+3]);
      sleep_us(500);
    }

    put_pixel(0x00000000);
}

void write_to_pcfx(uint32_t led_color)
{
uint32_t outword;
int index = 0;
int count = 0;

    put_pixel(led_color);
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
    }

//    put_pixel(0x00000000);    // There may not be enough time for 2 color transitions
}

void ws2812_countdown()
{
int start = 25;
int count;

    for (count = start; count >= 0; count--) {
      put_pixel(urgb_u32(count, 0, 0));  // red
      sleep_ms(10);
    }
    sleep_ms(200);

    for (count = start; count >= 0; count--) {
      put_pixel(urgb_u32(0, count, 0));  // green
      sleep_ms(10);
    }
    sleep_ms(200);

    for (count = start; count >= 0; count--) {
      put_pixel(urgb_u32(0, 0, count));  // blue
      sleep_ms(10);
    }
    sleep_ms(200);

    put_pixel(urgb_u32(10, 10, 10));  // light
}

int main() {

int a;
uint32_t outword;

int count = 0;

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

////////////////////////
// Turn off regular LEDs
//
    gpio_init(PICO_LED1);
    gpio_init(PICO_LED2);
    gpio_init(PICO_LED3);

    gpio_set_dir(PICO_LED1, GPIO_OUT);
    gpio_set_dir(PICO_LED2, GPIO_OUT);
    gpio_set_dir(PICO_LED3, GPIO_OUT);

    gpio_put(PICO_LED1, PICO_LED_OFF);
    gpio_put(PICO_LED2, PICO_LED_OFF);
    gpio_put(PICO_LED3, PICO_LED_OFF);

////////////////////////
// Setup NeoPixel LED
//
    gpio_init(PICO_DEFAULT_WS2812_POWER_PIN);
    gpio_set_dir(PICO_DEFAULT_WS2812_POWER_PIN, GPIO_OUT);
    gpio_put(PICO_DEFAULT_WS2812_POWER_PIN, 1);

    pioled = pio1;
    smled = 0;

    uint offset = pio_add_program(pioled, &ws2812_program);

    ws2812_program_init(pioled, smled, offset, WS2812_PIN, 800000, IS_RGBW);

//////////////////////////////////////

    // Both communications state machines run on one PIO processor (but LED on other)
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
    ws2812_countdown();
    sleep_ms(100);

    // Show green while data transfer (PC->MCU) is happening
    load_from_uart(urgb_u32(0,10,0));

    sleep_ms(500);

    // Show blue while data transfer (MCU->PC-FX) is happening
    write_to_pcfx(urgb_u32(0,0,10));

    // Show red while data transfer (PC-FX->MCU) is happening
    read_from_pcfx(urgb_u32(10,0,0),urgb_u32(10,10,0)); // red, then yellow

    return 0;
}
