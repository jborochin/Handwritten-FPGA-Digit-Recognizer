/*
 * Platform Configuration Helper
 * 
 * This file helps verify your platform settings.
 * Include this AFTER xparameters.h to see what device IDs Vivado generated.
 * 
 * In main.c, add:
 *   #include "xparameters.h"
 *   #include "platform_check.h"
 */

#ifndef PLATFORM_CHECK_H
#define PLATFORM_CHECK_H

#include "xparameters.h"

/*
 * Print platform configuration at startup
 * Call this from main() to verify settings
 */
static inline void print_platform_config(void)
{
    xil_printf("\r\n=== Platform Configuration ===\r\n");
    
#ifdef XPAR_AXI_QUAD_SPI_0_DEVICE_ID
    xil_printf("SPI Device ID: %d\r\n", XPAR_AXI_QUAD_SPI_0_DEVICE_ID);
    xil_printf("SPI Base Addr: 0x%08X\r\n", XPAR_AXI_QUAD_SPI_0_BASEADDR);
#else
    xil_printf("WARNING: SPI device not found!\r\n");
#endif

#ifdef XPAR_AXI_GPIO_0_DEVICE_ID
    xil_printf("GPIO Device ID: %d\r\n", XPAR_AXI_GPIO_0_DEVICE_ID);
    xil_printf("GPIO Base Addr: 0x%08X\r\n", XPAR_AXI_GPIO_0_BASEADDR);
#else
    xil_printf("WARNING: GPIO device not found!\r\n");
#endif

#ifdef XPAR_AXI_UARTLITE_0_DEVICE_ID
    xil_printf("UART Device ID: %d\r\n", XPAR_AXI_UARTLITE_0_DEVICE_ID);
    xil_printf("UART Base Addr: 0x%08X\r\n", XPAR_AXI_UARTLITE_0_BASEADDR);
#else
    xil_printf("WARNING: UART device not found!\r\n");
#endif

#ifdef XPAR_AXI_TIMER_0_DEVICE_ID
    xil_printf("Timer Device ID: %d\r\n", XPAR_AXI_TIMER_0_DEVICE_ID);
#endif

    xil_printf("=================================\r\n\r\n");
}

/*
 * If your device IDs differ from the defaults in main.c,
 * you can override them here:
 */

/* Uncomment and modify if needed:
#undef MY_SPI_DEVICE_ID
#define MY_SPI_DEVICE_ID XPAR_AXI_QUAD_SPI_0_DEVICE_ID

#undef MY_GPIO_DEVICE_ID  
#define MY_GPIO_DEVICE_ID XPAR_AXI_GPIO_0_DEVICE_ID
*/

#endif /* PLATFORM_CHECK_H */
