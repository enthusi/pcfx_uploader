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

#define LED_UART_TO_MCU   urgb_u32(0,10,0)   // green
#define LED_MCU_TO_PCFX   urgb_u32(0,0,10)   // blue
#define LED_PCFX_TO_MCU   urgb_u32(10,0,0)   // red
#define LED_MCU_TO_UART   urgb_u32(10,10,0)  // yellow
#define LED_EXEC          urgb_u32(3,0,3)    // purple
#define LED_IDLE          urgb_u32(5,5,5)    // light white


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


uint32_t magic_word = 0x12345678; // for deploying initial program

uint32_t read_word = 0x44414552;  // READ
uint32_t rdbr_word = 0x52424452;  // RDBR
uint32_t writ_word = 0x54495257;  // WRIT
uint32_t wrbr_word = 0x52425257;  // WRBR
uint32_t exec_word = 0x43455845;  // EXEC
uint32_t call_word = 0x4C4C4143;  // CALL

uint32_t start_addr = 0x00008000;
uint32_t num_bytes  = 0;

uint32_t payload_data[32768];


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

uint32_t uart_get_cmd(void)
{
uint32_t uart_word = 0;
uint8_t  uart_byte = 0;
bool     word_match = false;

   while (!word_match)
   {
     uart_byte = uart_get_char();

     uart_word = ((uart_word >> 8) & 0xffffff) | (uart_byte << 24);

     if ((uart_word == read_word) ||
         (uart_word == rdbr_word) ||
         (uart_word == writ_word) ||
         (uart_word == wrbr_word) ||
         (uart_word == exec_word) ||
         (uart_word == call_word))
     {
        word_match = true;
     }
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


void __not_in_flash_func(write_type_cmd)(uint32_t fx_command)
{
uint32_t start_addr;
uint32_t num_bytes;
uint32_t outword;
uint32_t junk;
int index = 0;
int count;

    put_pixel(LED_UART_TO_MCU);
    sleep_ms(10);

    start_addr  = uart_get_word();
    num_bytes   = uart_get_word();

    count = num_bytes;

    while(count > 0) {
      payload_data[index++] = uart_get_word();
      count -= 4;
    }

    put_pixel(LED_MCU_TO_PCFX);
    sleep_ms(10);

    // drain RX FIFO in case it has residual junk
    //
    while (!pio_sm_is_rx_fifo_empty(pio, sm1)) {
       junk = pio_sm_get_blocking(pio, sm1);
    }
    
    // note that PC-FX inverts on input, so we need to send all data as 1's complement
    outword = ~fx_command;
    pio_sm_put_blocking(pio, sm1, outword);

    outword = ~start_addr;
    pio_sm_put_blocking(pio, sm1, outword);

    outword = ~num_bytes;
    pio_sm_put_blocking(pio, sm1, outword);

    count = (num_bytes / 4);
    if ((num_bytes & 3) != 0)
       count++;

    for (index = 0; index < count; index++) {
       outword = ~payload_data[index];
       pio_sm_put_blocking(pio, sm1, outword);
    }

    // Output acknowledgement "word"
    putchar_raw((int)0);

    sleep_ms(10);

    // clear FIFOs in case of junk
    pio_sm_clear_fifos(pio, sm1);
}

void __not_in_flash_func(read_type_cmd)(uint32_t fx_command)
{
uint32_t start_addr;
uint32_t num_bytes;
uint32_t outword;
uint32_t inword, indata;
uint32_t junk;
uint32_t count = 0;
uint32_t index = 0;
int i = 0;

    start_addr  = uart_get_word();
    num_bytes   = uart_get_word();

    put_pixel(LED_PCFX_TO_MCU);
    sleep_ms(10);

    // drain RX FIFO in case it has residual junk
    //
    while (!pio_sm_is_rx_fifo_empty(pio, sm1)) {
       junk = pio_sm_get_blocking(pio, sm1);
    }
    
    // ------------
    // send request
    // ------------

    // note that PC-FX inverts on input, so we need to send all data as 1's complement
    outword = ~fx_command;
    pio_sm_put_blocking(pio, sm1, outword);

    outword = ~start_addr;
    pio_sm_put_blocking(pio, sm1, outword);

    outword = ~num_bytes;
    pio_sm_put_blocking(pio, sm1, outword);

    // ----------------
    // receive response
    // ----------------

    // Ignore first word returned from PC-FX; for some reason the PC-FX side has
    // an issue with the first word written after reading data; it occasionally
    // retains and sends out the lower half-word of the last inbound word.
    //
    // So, we send a dummy word to 'flush' the potentially bad data.
    //
    junk = pio_sm_get_blocking(pio, sm1);

    count = num_bytes/4;
    index = 0;

    while(index < count) {
      inword = pio_sm_get_blocking(pio, sm1);
      indata = ~inword;

      if ((index == 0) && (indata & 0x0000ffff) == (num_bytes & 0x0000ffff))
         gpio_put(PICO_LED2, PICO_LED_ON);

      payload_data[index++] = indata;
    }

    sleep_ms(10);
    put_pixel(LED_MCU_TO_UART);

    for (i = 0; i < count; i++) {
      putchar_raw((int)(payload_data[i] & 0xff));
      putchar_raw((int)((payload_data[i] >> 8) & 0xff));
      putchar_raw((int)((payload_data[i] >> 16) & 0xff));
      putchar_raw((int)((payload_data[i] >> 24) & 0xff));
      sleep_us(100);
    }

    sleep_ms(10);

    // clear FIFOs in case of junk
    pio_sm_clear_fifos(pio, sm1);
}

void __not_in_flash_func(exec_type_cmd)(uint32_t fx_command)
{
uint32_t exec_addr;
uint32_t outword;
uint32_t junk;

    put_pixel(LED_EXEC);
    exec_addr  = uart_get_word();

    // drain RX FIFO in case it has residual junk
    //
    while (!pio_sm_is_rx_fifo_empty(pio, sm1)) {
       junk = pio_sm_get_blocking(pio, sm1);
    }
    
    // note that PC-FX inverts on input, so we need to send all data as 1's complement
    outword = ~fx_command;
    pio_sm_put_blocking(pio, sm1, outword);

    outword = ~exec_addr;
    pio_sm_put_blocking(pio, sm1, outword);

    sleep_ms(10);

    // clear FIFOs in case of junk
    pio_sm_clear_fifos(pio, sm1);
}

void __not_in_flash_func(get_cmd_from_uart)(void)
{
uint32_t fx_command;

    put_pixel(LED_IDLE);
    sleep_ms(10);

    fx_command = uart_get_cmd();

    pio_sm_clear_fifos(pio, sm1);  // in case startup placed junk in FIFOs
    pio_sm_clear_fifos(pio, sm1);  // in case it was blocked on PUSH (one last word to drain)

    if ((fx_command == read_word) || (fx_command == rdbr_word))
    {
       read_type_cmd(fx_command);
    }
    else if ((fx_command == writ_word) || (fx_command == wrbr_word))
    {
       write_type_cmd(fx_command);
    }
    else if ((fx_command == exec_word) || (fx_command == call_word))
    {
       exec_type_cmd(fx_command);
    }
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

    put_pixel(LED_IDLE);  // light white
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
    gpio_init(PICO_LED1);  // red   LED
    gpio_init(PICO_LED2);  // green LED
    gpio_init(PICO_LED3);  // blue  LED

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
    sleep_ms(1500);

    pio_sm_clear_fifos(pio, sm1);  // in case startup placed junk in FIFOs
    pio_sm_clear_fifos(pio, sm1);  // in case it was blocked on PUSH (one last word to drain)

    outword = ~0;
    pio_sm_put_blocking(pio, sm1, outword);

// Now flash LED(s) to signify all is well
//
    ws2812_countdown();

    sleep_ms(200);

    while(1) {
      get_cmd_from_uart();
    }

    return 0;
}
