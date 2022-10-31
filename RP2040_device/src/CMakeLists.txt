cmake_minimum_required(VERSION 3.12)

# Pull in SDK (must be before project)
include(pico_sdk_import.cmake)

project(fxloader)

# Initialize the SDK
pico_sdk_init()

add_executable(fxloader main.c)

pico_generate_pio_header(fxloader ${CMAKE_CURRENT_LIST_DIR}/pcfxplex.pio )
pico_generate_pio_header(fxloader ${CMAKE_CURRENT_LIST_DIR}/clock.pio )
pico_generate_pio_header(fxloader ${CMAKE_CURRENT_LIST_DIR}/ws2812.pio )

target_link_libraries(fxloader 
	pico_stdlib
	hardware_pio
	)

# enable usb output, disable uart output
pico_enable_stdio_usb(fxloader 1)
pico_enable_stdio_uart(fxloader 0)

pico_add_extra_outputs(fxloader)
