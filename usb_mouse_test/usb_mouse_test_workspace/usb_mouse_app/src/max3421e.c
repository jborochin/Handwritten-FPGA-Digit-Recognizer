/*
 * MAX3421E USB Host Controller Driver
 * For Spartan-7 Urbana Board USB Mouse Test Project
 * 
 * UPDATED: Removed GPX signal dependency (not available on Urbana Board)
 */

#include "max3421e.h"
#include "xspi.h"
#include "xgpio.h"
#include "xil_printf.h"
#include "sleep.h"

/* Static instances */
static XSpi SpiInstance;
static XGpio GpioInstance;

/* SPI transfer buffer */
static u8 spi_buf[68];

/* =============================================================================
 * Low-level SPI Functions
 * =============================================================================
 */

/* Write a single byte to a MAX3421E register */
void max3421e_write_reg(u8 reg, u8 val)
{
    spi_buf[0] = reg | MAX_REG_WRITE;
    spi_buf[1] = val;
    
    XSpi_SetSlaveSelect(&SpiInstance, 0x01);
    XSpi_Transfer(&SpiInstance, spi_buf, NULL, 2);
}

/* Read a single byte from a MAX3421E register */
u8 max3421e_read_reg(u8 reg)
{
    spi_buf[0] = reg | MAX_REG_READ;
    spi_buf[1] = 0x00;  /* Dummy byte for clock generation */
    
    XSpi_SetSlaveSelect(&SpiInstance, 0x01);
    XSpi_Transfer(&SpiInstance, spi_buf, spi_buf, 2);
    
    return spi_buf[1];
}

/* Write multiple bytes to MAX3421E (for FIFO writes) */
void max3421e_write_bytes(u8 reg, u8 *data, int len)
{
    spi_buf[0] = reg | MAX_REG_WRITE;
    for (int i = 0; i < len && i < 64; i++) {
        spi_buf[i + 1] = data[i];
    }
    
    XSpi_SetSlaveSelect(&SpiInstance, 0x01);
    XSpi_Transfer(&SpiInstance, spi_buf, NULL, len + 1);
}

/* Read multiple bytes from MAX3421E (for FIFO reads) */
void max3421e_read_bytes(u8 reg, u8 *data, int len)
{
    spi_buf[0] = reg | MAX_REG_READ;
    for (int i = 0; i < len + 1; i++) {
        spi_buf[i + 1] = 0x00;
    }
    
    XSpi_SetSlaveSelect(&SpiInstance, 0x01);
    XSpi_Transfer(&SpiInstance, spi_buf, spi_buf, len + 1);
    
    for (int i = 0; i < len; i++) {
        data[i] = spi_buf[i + 1];
    }
}

/* =============================================================================
 * GPIO Control Functions
 * =============================================================================
 */

/* Assert hardware reset to MAX3421E (active low) */
void max3421e_hw_reset(void)
{
    /* Pull RST_N low (GPIO Channel 2 is output) */
    XGpio_DiscreteWrite(&GpioInstance, 2, 0x00);
    usleep(100000);  /* 100ms reset pulse */
    
    /* Release RST_N high */
    XGpio_DiscreteWrite(&GpioInstance, 2, 0x01);
    usleep(100000);  /* Wait for oscillator startup */
}

/* Read interrupt pin state (GPIO Channel 1 is input) */
int max3421e_int_pending(void)
{
    u32 gpio_val = XGpio_DiscreteRead(&GpioInstance, 1);
    return (gpio_val & 0x01) == 0;  /* INT is active low */
}

/* =============================================================================
 * Initialization Functions
 * =============================================================================
 */

int max3421e_spi_init(u16 spi_device_id, u16 gpio_device_id)
{
    XSpi_Config *spi_config;
    XGpio_Config *gpio_config;
    int status;
    
    /* Initialize SPI */
    spi_config = XSpi_LookupConfig(spi_device_id);
    if (spi_config == NULL) {
        xil_printf("ERROR: SPI config lookup failed\r\n");
        return XST_FAILURE;
    }
    
    status = XSpi_CfgInitialize(&SpiInstance, spi_config, spi_config->BaseAddress);
    if (status != XST_SUCCESS) {
        xil_printf("ERROR: SPI initialization failed\r\n");
        return XST_FAILURE;
    }
    
    /* Configure SPI: Master mode, manual slave select, CPOL=0, CPHA=0 */
    status = XSpi_SetOptions(&SpiInstance, 
                             XSP_MASTER_OPTION | 
                             XSP_MANUAL_SSELECT_OPTION);
    if (status != XST_SUCCESS) {
        xil_printf("ERROR: SPI set options failed\r\n");
        return XST_FAILURE;
    }
    
    /* Start SPI */
    XSpi_Start(&SpiInstance);
    XSpi_IntrGlobalDisable(&SpiInstance);
    
    /* Initialize GPIO */
    gpio_config = XGpio_LookupConfig(gpio_device_id);
    if (gpio_config == NULL) {
        xil_printf("ERROR: GPIO config lookup failed\r\n");
        return XST_FAILURE;
    }
    
    status = XGpio_CfgInitialize(&GpioInstance, gpio_config, gpio_config->BaseAddress);
    if (status != XST_SUCCESS) {
        xil_printf("ERROR: GPIO initialization failed\r\n");
        return XST_FAILURE;
    }
    
    /* Configure GPIO directions */
    /* Channel 1: Input (INT_N) - set direction bits to 1 for input */
    XGpio_SetDataDirection(&GpioInstance, 1, 0x01);
    /* Channel 2: Output (RST_N) - set direction bits to 0 for output */
    XGpio_SetDataDirection(&GpioInstance, 2, 0x00);
    
    /* Initialize RST_N high (not in reset) */
    XGpio_DiscreteWrite(&GpioInstance, 2, 0x01);
    
    xil_printf("SPI and GPIO initialized successfully\r\n");
    return XST_SUCCESS;
}

int max3421e_chip_init(void)
{
    u8 revision;
    int timeout;
    
    xil_printf("\r\n=== MAX3421E Initialization ===\r\n");
    
    /* Hardware reset */
    xil_printf("Performing hardware reset...\r\n");
    max3421e_hw_reset();
    
    /* Read revision - should be 0x13 for MAX3421E */
    revision = max3421e_read_reg(rREVISION);
    xil_printf("MAX3421E Revision: 0x%02X ", revision);
    if (revision == 0x13) {
        xil_printf("(OK)\r\n");
    } else if (revision == 0x00 || revision == 0xFF) {
        xil_printf("(ERROR - no communication!)\r\n");
        return XST_FAILURE;
    } else {
        xil_printf("(WARNING - unexpected value)\r\n");
    }
    
    /* Software reset */
    xil_printf("Performing chip reset...\r\n");
    max3421e_write_reg(rUSBCTL, bmCHIPRES);
    usleep(10000);
    max3421e_write_reg(rUSBCTL, 0x00);
    
    /* Wait for oscillator to stabilize */
    xil_printf("Waiting for oscillator...\r\n");
    timeout = 1000;
    while (timeout > 0) {
        if (max3421e_read_reg(rUSBIRQ) & bmOSCOKIRQ) {
            break;
        }
        usleep(1000);
        timeout--;
    }
    
    if (timeout == 0) {
        xil_printf("ERROR: Oscillator timeout!\r\n");
        return XST_FAILURE;
    }
    xil_printf("Oscillator OK\r\n");
    
    /* Clear the OSCOKIRQ flag */
    max3421e_write_reg(rUSBIRQ, bmOSCOKIRQ);
    
    /* Configure pin control:
     * - Full duplex SPI
     * - INT pin active low (default)
     */
    max3421e_write_reg(rPINCTL, bmFDUPSPI);
    
    /* Enable host mode with:
     * - D+/D- pulldowns enabled (detect device connect)
     * - Low-speed support enabled
     */
    max3421e_write_reg(rMODE, bmDPPULLDN | bmDMPULLDN | bmHOST);
    
    /* Enable interrupts we care about */
    max3421e_write_reg(rHIEN, bmCONDETIRQ | bmFRAMEIRQ | bmBUSEVENTIRQ);
    max3421e_write_reg(rCPUCTL, bmIE);
    
    xil_printf("MAX3421E configured for host mode\r\n");
    
    return XST_SUCCESS;
}

/* =============================================================================
 * USB Bus Control
 * =============================================================================
 */

int max3421e_bus_reset(void)
{
    int timeout;
    
    xil_printf("Performing USB bus reset...\r\n");
    
    /* Start bus reset */
    max3421e_write_reg(rHCTL, bmBUSRST);
    
    /* Wait for reset to complete */
    timeout = 500;
    while (timeout > 0) {
        if (!(max3421e_read_reg(rHCTL) & bmBUSRST)) {
            break;
        }
        usleep(1000);
        timeout--;
    }
    
    if (timeout == 0) {
        xil_printf("ERROR: Bus reset timeout!\r\n");
        return XST_FAILURE;
    }
    
    xil_printf("Bus reset complete\r\n");
    usleep(200000);  /* Post-reset recovery time */
    
    return XST_SUCCESS;
}

/* Detect device speed after connection */
int max3421e_detect_speed(void)
{
    u8 hrsl;
    
    /* Sample the bus */
    max3421e_write_reg(rHCTL, bmSAMPLEBUS);
    usleep(10000);
    
    hrsl = max3421e_read_reg(rHRSL);
    
    if (hrsl & bmJSTATUS) {
        xil_printf("Full-speed device detected (J state)\r\n");
        /* Clear low-speed bit */
        u8 mode = max3421e_read_reg(rMODE);
        max3421e_write_reg(rMODE, mode & ~bmLOWSPEED);
        return USB_SPEED_FULL;
    } else if (hrsl & bmKSTATUS) {
        xil_printf("Low-speed device detected (K state)\r\n");
        /* Set low-speed bit */
        u8 mode = max3421e_read_reg(rMODE);
        max3421e_write_reg(rMODE, mode | bmLOWSPEED);
        return USB_SPEED_LOW;
    } else {
        xil_printf("No device detected (SE0 state)\r\n");
        return USB_SPEED_NONE;
    }
}

/* Check if device is connected */
int max3421e_device_connected(void)
{
    u8 hrsl = max3421e_read_reg(rHRSL);
    return (hrsl & (bmJSTATUS | bmKSTATUS)) != 0;
}

/* =============================================================================
 * USB Transfer Functions
 * =============================================================================
 */

/* Wait for transfer to complete */
static int wait_transfer_complete(void)
{
    int timeout = 5000;
    u8 hirq;
    
    while (timeout > 0) {
        hirq = max3421e_read_reg(rHIRQ);
        if (hirq & bmHXFRDNIRQ) {
            /* Clear the interrupt flag */
            max3421e_write_reg(rHIRQ, bmHXFRDNIRQ);
            return XST_SUCCESS;
        }
        usleep(10);
        timeout--;
    }
    
    return XST_FAILURE;
}

/* Get transfer result */
static u8 get_transfer_result(void)
{
    return max3421e_read_reg(rHRSL) & 0x0F;
}

/* Perform a control transfer (SETUP stage) */
int max3421e_control_setup(u8 addr, u8 *setup_data)
{
    u8 result;
    int retries = 3;
    
    /* Set peripheral address */
    max3421e_write_reg(rPERADDR, addr);
    
    /* Load SETUP data into SUDFIFO */
    max3421e_write_bytes(rSUDFIFO, setup_data, 8);
    
    while (retries > 0) {
        /* Dispatch SETUP token */
        max3421e_write_reg(rHXFR, tokSETUP);
        
        if (wait_transfer_complete() != XST_SUCCESS) {
            xil_printf("SETUP timeout\r\n");
            return XST_FAILURE;
        }
        
        result = get_transfer_result();
        if (result == hrSUCCESS) {
            return XST_SUCCESS;
        } else if (result == hrNAK) {
            usleep(1000);
            retries--;
        } else {
            xil_printf("SETUP error: 0x%02X\r\n", result);
            return XST_FAILURE;
        }
    }
    
    return XST_FAILURE;
}

/* Perform a control IN transfer */
int max3421e_control_in(u8 addr, u8 *data, int *len, int maxlen)
{
    u8 result;
    int total = 0;
    int retries;
    u8 bc;
    u8 toggle = 1;  /* DATA1 for first packet */
    
    /* Set peripheral address */
    max3421e_write_reg(rPERADDR, addr);
    
    while (total < maxlen) {
        /* Set data toggle */
        max3421e_write_reg(rHCTL, toggle ? bmRCVTOG1 : bmRCVTOG0);
        
        retries = 100;
        while (retries > 0) {
            /* Dispatch IN token */
            max3421e_write_reg(rHXFR, tokIN);
            
            if (wait_transfer_complete() != XST_SUCCESS) {
                xil_printf("IN timeout\r\n");
                return XST_FAILURE;
            }
            
            result = get_transfer_result();
            if (result == hrSUCCESS) {
                break;
            } else if (result == hrNAK) {
                usleep(100);
                retries--;
            } else {
                xil_printf("IN error: 0x%02X\r\n", result);
                return XST_FAILURE;
            }
        }
        
        if (retries == 0) {
            xil_printf("IN NAK timeout\r\n");
            return XST_FAILURE;
        }
        
        /* Read received data */
        bc = max3421e_read_reg(rRCVBC);
        if (bc > 0) {
            max3421e_read_bytes(rRCVFIFO, data + total, bc);
            total += bc;
        }
        
        /* Toggle for next packet */
        toggle = !toggle;
        
        /* Short packet means end of data */
        if (bc < 8) {
            break;
        }
    }
    
    *len = total;
    return XST_SUCCESS;
}

/* Perform a control OUT transfer (status stage, no data) */
int max3421e_control_status_out(u8 addr)
{
    u8 result;
    int retries = 100;
    
    max3421e_write_reg(rPERADDR, addr);
    max3421e_write_reg(rSNDBC, 0);  /* Zero-length packet */
    max3421e_write_reg(rHCTL, bmSNDTOG1);  /* DATA1 for status */
    
    while (retries > 0) {
        max3421e_write_reg(rHXFR, tokOUTHS);
        
        if (wait_transfer_complete() != XST_SUCCESS) {
            return XST_FAILURE;
        }
        
        result = get_transfer_result();
        if (result == hrSUCCESS) {
            return XST_SUCCESS;
        } else if (result == hrNAK) {
            usleep(100);
            retries--;
        } else {
            return XST_FAILURE;
        }
    }
    
    return XST_FAILURE;
}

/* Status IN (after control OUT data stage) */
int max3421e_control_status_in(u8 addr)
{
    u8 result;
    int retries = 100;
    
    max3421e_write_reg(rPERADDR, addr);
    max3421e_write_reg(rHCTL, bmRCVTOG1);
    
    while (retries > 0) {
        max3421e_write_reg(rHXFR, tokINHS);
        
        if (wait_transfer_complete() != XST_SUCCESS) {
            return XST_FAILURE;
        }
        
        result = get_transfer_result();
        if (result == hrSUCCESS) {
            return XST_SUCCESS;
        } else if (result == hrNAK) {
            usleep(100);
            retries--;
        } else {
            return XST_FAILURE;
        }
    }
    
    return XST_FAILURE;
}

/* Perform an interrupt IN transfer (for HID reports) */
int max3421e_interrupt_in(u8 addr, u8 ep, u8 *data, int *len, int maxlen, u8 *toggle)
{
    u8 result;
    int retries = 10;
    u8 bc;
    
    max3421e_write_reg(rPERADDR, addr);
    max3421e_write_reg(rHCTL, *toggle ? bmRCVTOG1 : bmRCVTOG0);
    
    while (retries > 0) {
        max3421e_write_reg(rHXFR, tokIN | ep);
        
        if (wait_transfer_complete() != XST_SUCCESS) {
            *len = 0;
            return XST_FAILURE;
        }
        
        result = get_transfer_result();
        if (result == hrSUCCESS) {
            bc = max3421e_read_reg(rRCVBC);
            if (bc > maxlen) bc = maxlen;
            max3421e_read_bytes(rRCVFIFO, data, bc);
            *len = bc;
            *toggle = !(*toggle);
            return XST_SUCCESS;
        } else if (result == hrNAK) {
            *len = 0;
            return XST_SUCCESS;  /* NAK is normal for interrupt endpoints */
        } else if (result == hrTOGERR) {
            /* Toggle error - flip and retry */
            *toggle = !(*toggle);
            max3421e_write_reg(rHCTL, *toggle ? bmRCVTOG1 : bmRCVTOG0);
            retries--;
        } else {
            xil_printf("INT IN error: 0x%02X\r\n", result);
            *len = 0;
            return XST_FAILURE;
        }
    }
    
    *len = 0;
    return XST_FAILURE;
}

/* =============================================================================
 * USB Standard Request Helpers
 * =============================================================================
 */

int max3421e_get_descriptor(u8 addr, u8 type, u8 index, u8 *buffer, int *len, int maxlen)
{
    u8 setup[8];
    
    setup[0] = bmREQ_DIR_IN | bmREQ_TYPE_STANDARD | bmREQ_RECIP_DEVICE;
    setup[1] = USB_REQUEST_GET_DESCRIPTOR;
    setup[2] = index;           /* Descriptor Index */
    setup[3] = type;            /* Descriptor Type */
    setup[4] = 0x00;            /* Language ID low */
    setup[5] = 0x00;            /* Language ID high */
    setup[6] = maxlen & 0xFF;   /* Length low */
    setup[7] = (maxlen >> 8);   /* Length high */
    
    if (max3421e_control_setup(addr, setup) != XST_SUCCESS) {
        return XST_FAILURE;
    }
    
    if (max3421e_control_in(addr, buffer, len, maxlen) != XST_SUCCESS) {
        return XST_FAILURE;
    }
    
    return max3421e_control_status_out(addr);
}

int max3421e_set_address(u8 old_addr, u8 new_addr)
{
    u8 setup[8];
    
    setup[0] = bmREQ_TYPE_STANDARD | bmREQ_RECIP_DEVICE;
    setup[1] = USB_REQUEST_SET_ADDRESS;
    setup[2] = new_addr;
    setup[3] = 0x00;
    setup[4] = 0x00;
    setup[5] = 0x00;
    setup[6] = 0x00;
    setup[7] = 0x00;
    
    if (max3421e_control_setup(old_addr, setup) != XST_SUCCESS) {
        return XST_FAILURE;
    }
    
    return max3421e_control_status_in(old_addr);
}

int max3421e_set_configuration(u8 addr, u8 config)
{
    u8 setup[8];
    
    setup[0] = bmREQ_TYPE_STANDARD | bmREQ_RECIP_DEVICE;
    setup[1] = USB_REQUEST_SET_CONFIGURATION;
    setup[2] = config;
    setup[3] = 0x00;
    setup[4] = 0x00;
    setup[5] = 0x00;
    setup[6] = 0x00;
    setup[7] = 0x00;
    
    if (max3421e_control_setup(addr, setup) != XST_SUCCESS) {
        return XST_FAILURE;
    }
    
    return max3421e_control_status_in(addr);
}

int max3421e_set_protocol(u8 addr, u8 interface, u8 protocol)
{
    u8 setup[8];
    
    setup[0] = bmREQ_TYPE_CLASS | bmREQ_RECIP_INTERFACE;
    setup[1] = HID_REQUEST_SET_PROTOCOL;
    setup[2] = protocol;  /* 0=Boot protocol, 1=Report protocol */
    setup[3] = 0x00;
    setup[4] = interface;
    setup[5] = 0x00;
    setup[6] = 0x00;
    setup[7] = 0x00;
    
    if (max3421e_control_setup(addr, setup) != XST_SUCCESS) {
        return XST_FAILURE;
    }
    
    return max3421e_control_status_in(addr);
}

/* Print HRSL status for debugging */
void max3421e_print_status(void)
{
    u8 hirq = max3421e_read_reg(rHIRQ);
    u8 hrsl = max3421e_read_reg(rHRSL);
    u8 mode = max3421e_read_reg(rMODE);
    u8 usbirq = max3421e_read_reg(rUSBIRQ);
    
    xil_printf("HIRQ=0x%02X HRSL=0x%02X MODE=0x%02X USBIRQ=0x%02X\r\n",
               hirq, hrsl, mode, usbirq);
}
