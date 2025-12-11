/* MAX3421E low-level functions */
#define _MAX3421E_C_

#include "stdlib.h"
#include "stdio.h"
#include "string.h"
#include "project_config.h"
#include "xparameters.h"
#include <xspi.h>
#include <xgpio.h>
#include "xintc.h"
#include "sleep.h"
#include "MAX3421E.h"

// =======================================================
// HARDWARE ID MAPPING
// =======================================================
#define SPI_DEVICE_ID      XPAR_SPI_0_DEVICE_ID
#define GPIO_DEVICE_ID     XPAR_GPIO_0_DEVICE_ID

extern BYTE usb_task_state;
static XSpi SpiInstance;
static XGpio Gpio_USB;
static int Status;

// Prototypes
void MaxIntHandler(void);

// =======================================================
// SPI INITIALIZATION
// =======================================================
void SPI_init() {
    xil_printf("Initializing SPI...\n");
    XSpi_Config *ConfigPtr = XSpi_LookupConfig(SPI_DEVICE_ID);
    if (ConfigPtr == NULL) return;

    Status = XSpi_CfgInitialize(&SpiInstance, ConfigPtr, ConfigPtr->BaseAddress);
    Status = XSpi_SetOptions(&SpiInstance, XSP_MASTER_OPTION | XSP_MANUAL_SSELECT_OPTION);
    XSpi_Start(&SpiInstance);
    XSpi_IntrGlobalDisable(&SpiInstance);
}

BYTE SPI_wr(BYTE data) { return 0; }

// =======================================================
// REGISTER READ/WRITE
// =======================================================
void MAXreg_wr(BYTE reg, BYTE val) {
    BYTE write_buffer[2];
    write_buffer[0] = (reg << 3) | 0x02;
    write_buffer[1] = val;

    XSpi_SetSlaveSelect(&SpiInstance, 1);
    XSpi_Transfer(&SpiInstance, write_buffer, NULL, 2);
    XSpi_SetSlaveSelect(&SpiInstance, 0);
}

BYTE* MAXbytes_wr(BYTE reg, BYTE nbytes, BYTE* data) {
    BYTE command = (reg << 3) | 0x02;
    XSpi_SetSlaveSelect(&SpiInstance, 1);
    XSpi_Transfer(&SpiInstance, &command, NULL, 1);
    XSpi_Transfer(&SpiInstance, data, NULL, nbytes);
    XSpi_SetSlaveSelect(&SpiInstance, 0);
    return (data + nbytes);
}

BYTE MAXreg_rd(BYTE reg) {
    BYTE command = (reg << 3);
    BYTE read_byte;
    XSpi_SetSlaveSelect(&SpiInstance, 1);
    XSpi_Transfer(&SpiInstance, &command, NULL, 1);
    XSpi_Transfer(&SpiInstance, &command, &read_byte, 1);
    XSpi_SetSlaveSelect(&SpiInstance, 0);
    return read_byte;
}

BYTE* MAXbytes_rd(BYTE reg, BYTE nbytes, BYTE* data) {
    BYTE command = (reg << 3);
    XSpi_SetSlaveSelect(&SpiInstance, 1);
    XSpi_Transfer(&SpiInstance, &command, NULL, 1);
    XSpi_Transfer(&SpiInstance, NULL, data, nbytes);
    XSpi_SetSlaveSelect(&SpiInstance, 0);
    return (data + nbytes);
}

// =======================================================
// INITIALIZATION & RESET
// =======================================================
void MAX3421E_reset(void) {
    // Initialize GPIO
    XGpio_Initialize(&Gpio_USB, GPIO_DEVICE_ID);
    XGpio_SetDataDirection(&Gpio_USB, 1, 1); // Input
    XGpio_SetDataDirection(&Gpio_USB, 2, 0); // Output

    // 1. Hardware Reset (Toggle Pin)
    xil_printf("Resetting USB...\n");
    XGpio_DiscreteWrite(&Gpio_USB, 2, 0); // Low (Reset)
    usleep(20000);
    XGpio_DiscreteWrite(&Gpio_USB, 2, 1); // High (Run)
    usleep(20000);

    // 2. CRITICAL: Enable Full-Duplex Mode Immediately
    // After reset, chip defaults to Half-Duplex. We must write PINCTL first.
    MAXreg_wr(rPINCTL, (bmFDUPSPI | bmINTLEVEL | bmGPXB));
    usleep(10000); // Give it a moment to latch

    // 3. Now we can safely read registers
    BYTE revision = MAXreg_rd(rREVISION);
    xil_printf("MAX3421E Revision: %d\n", revision);

    // 4. Start Oscillator
    MAXreg_wr(rUSBCTL, bmCHIPRES); // Chip reset bit
    MAXreg_wr(rUSBCTL, 0x00);      // Clear reset bit

    // 5. Wait for PLL
    int attempts = 0;
    while (!(MAXreg_rd(rUSBIRQ) & bmOSCOKIRQ)) {
        usleep(1000);
        attempts++;
        if (attempts > 2000) {
            xil_printf("Error: PLL Oscillator timeout. (Check VBUS/Power)\n");
            break;
        }
    }
}

void MAX3421E_init(void) {
    SPI_init();
    MAX3421E_reset(); // Now handles the PINCTL setup internally

    // Configure Host Mode
    MAXreg_wr(rMODE, bmDPPULLDN | bmDMPULLDN | bmHOST | bmSEPIRQ);
    MAXreg_wr(rHIEN, bmCONDETIE);
    MAXreg_wr(rHCTL, bmSAMPLEBUS);

    MAX_busprobe();

    MAXreg_wr(rHIRQ, bmCONDETIRQ);
    MAXreg_wr(rCPUCTL, 0x01);
}

// =======================================================
// UTILS
// =======================================================
BOOL Vbus_power(BOOL action) {
    BYTE tmp = MAXreg_rd(rIOPINS1);
    if (action) tmp |= bmGPOUT0;
    else        tmp &= ~bmGPOUT0;
    MAXreg_wr(rIOPINS1, tmp);
    usleep(10000);
    return TRUE;
}

void MAX_busprobe(void) {
    BYTE bus_sample;
    bus_sample = MAXreg_rd(rHRSL);
    bus_sample &= (bmJSTATUS | bmKSTATUS);

    switch (bus_sample) {
        case bmJSTATUS:
            if (usb_task_state != 0x40) { // Check against WAIT_RESET
                if (!(MAXreg_rd(rMODE) & bmLOWSPEED)) {
                    MAXreg_wr(rMODE, MODE_FS_HOST);
                    xil_printf("Detected: Full Speed Device\n");
                } else {
                    MAXreg_wr(rMODE, MODE_LS_HOST);
                    xil_printf("Detected: Low Speed Device\n");
                }
                usb_task_state = 0x60; // ATTACHED
            }
            break;
        case bmKSTATUS:
            if (usb_task_state != 0x40) {
                if (!(MAXreg_rd(rMODE) & bmLOWSPEED)) {
                    MAXreg_wr(rMODE, MODE_LS_HOST);
                    xil_printf("Detected: Low Speed Device\n");
                } else {
                    MAXreg_wr(rMODE, MODE_FS_HOST);
                    xil_printf("Detected: Full Speed Device\n");
                }
                usb_task_state = 0x60; // ATTACHED
            }
            break;
        case bmSE1:
            usb_task_state = 0x13; // ILLEGAL
            break;
        case bmSE0:
            if ((usb_task_state & 0xF0) != 0x10) // Not DETACHED
                usb_task_state = 0x11; // INIT
            break;
    }
}

void MAX3421E_Task(void) {
    if ((XGpio_DiscreteRead(&Gpio_USB, 1) & 0x01) == 0) {
        MaxIntHandler();
    }
}

void MaxIntHandler(void) {
    BYTE HIRQ = MAXreg_rd(rHIRQ);
    BYTE HIRQ_sendback = 0x00;

    if (HIRQ & bmFRAMEIRQ)   HIRQ_sendback |= bmFRAMEIRQ;
    if (HIRQ & bmCONDETIRQ) {
        MAX_busprobe();
        HIRQ_sendback |= bmCONDETIRQ;
    }
    if (HIRQ & bmSNDBAVIRQ) MAXreg_wr(rSNDBC, 0x00);
    if (HIRQ & bmBUSEVENTIRQ) {
        usb_task_state++;
        HIRQ_sendback |= bmBUSEVENTIRQ;
    }
    MAXreg_wr(rHIRQ, HIRQ_sendback);
}

void MaxGpxHandler(void) {}
