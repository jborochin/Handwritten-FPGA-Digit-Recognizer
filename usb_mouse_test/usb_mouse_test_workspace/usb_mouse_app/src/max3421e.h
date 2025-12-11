/*
 * MAX3421E USB Host Controller Driver - Header
 * For Spartan-7 Urbana Board USB Mouse Test Project
 */

#ifndef MAX3421E_H
#define MAX3421E_H

#include "xil_types.h"
#include "max3421e_regs.h"

/* USB Speed constants */
#define USB_SPEED_NONE  0
#define USB_SPEED_LOW   1
#define USB_SPEED_FULL  2

/* =============================================================================
 * Low-level SPI Functions
 * =============================================================================
 */

/**
 * Write a single byte to a MAX3421E register
 * @param reg Register address
 * @param val Value to write
 */
void max3421e_write_reg(u8 reg, u8 val);

/**
 * Read a single byte from a MAX3421E register
 * @param reg Register address
 * @return Register value
 */
u8 max3421e_read_reg(u8 reg);

/**
 * Write multiple bytes to MAX3421E (for FIFO writes)
 * @param reg Register address
 * @param data Data buffer
 * @param len Number of bytes
 */
void max3421e_write_bytes(u8 reg, u8 *data, int len);

/**
 * Read multiple bytes from MAX3421E (for FIFO reads)
 * @param reg Register address
 * @param data Data buffer
 * @param len Number of bytes to read
 */
void max3421e_read_bytes(u8 reg, u8 *data, int len);

/* =============================================================================
 * Initialization Functions
 * =============================================================================
 */

/**
 * Initialize SPI and GPIO interfaces for MAX3421E
 * @param spi_device_id SPI device ID from xparameters.h
 * @param gpio_device_id GPIO device ID from xparameters.h
 * @return XST_SUCCESS or XST_FAILURE
 */
int max3421e_spi_init(u16 spi_device_id, u16 gpio_device_id);

/**
 * Initialize MAX3421E chip and configure for USB host mode
 * @return XST_SUCCESS or XST_FAILURE
 */
int max3421e_chip_init(void);

/**
 * Perform hardware reset of MAX3421E
 */
void max3421e_hw_reset(void);

/* =============================================================================
 * USB Bus Control
 * =============================================================================
 */

/**
 * Check if interrupt is pending (INT_N pin low)
 * @return 1 if interrupt pending, 0 otherwise
 */
int max3421e_int_pending(void);

/**
 * Perform USB bus reset
 * @return XST_SUCCESS or XST_FAILURE
 */
int max3421e_bus_reset(void);

/**
 * Detect connected device speed
 * @return USB_SPEED_NONE, USB_SPEED_LOW, or USB_SPEED_FULL
 */
int max3421e_detect_speed(void);

/**
 * Check if a device is connected
 * @return 1 if connected, 0 otherwise
 */
int max3421e_device_connected(void);

/* =============================================================================
 * USB Transfer Functions
 * =============================================================================
 */

/**
 * Perform control SETUP stage
 * @param addr Device address
 * @param setup_data 8-byte SETUP packet
 * @return XST_SUCCESS or XST_FAILURE
 */
int max3421e_control_setup(u8 addr, u8 *setup_data);

/**
 * Perform control IN transfer (data stage)
 * @param addr Device address
 * @param data Buffer for received data
 * @param len Pointer to receive actual length
 * @param maxlen Maximum bytes to receive
 * @return XST_SUCCESS or XST_FAILURE
 */
int max3421e_control_in(u8 addr, u8 *data, int *len, int maxlen);

/**
 * Perform control STATUS OUT stage (after IN data)
 * @param addr Device address
 * @return XST_SUCCESS or XST_FAILURE
 */
int max3421e_control_status_out(u8 addr);

/**
 * Perform control STATUS IN stage (after OUT data or no data)
 * @param addr Device address
 * @return XST_SUCCESS or XST_FAILURE
 */
int max3421e_control_status_in(u8 addr);

/**
 * Perform interrupt IN transfer
 * @param addr Device address
 * @param ep Endpoint number
 * @param data Buffer for received data
 * @param len Pointer to receive actual length
 * @param maxlen Maximum bytes to receive
 * @param toggle Pointer to data toggle state (preserved between calls)
 * @return XST_SUCCESS or XST_FAILURE
 */
int max3421e_interrupt_in(u8 addr, u8 ep, u8 *data, int *len, int maxlen, u8 *toggle);

/* =============================================================================
 * USB Standard Request Helpers
 * =============================================================================
 */

/**
 * Get descriptor from device
 * @param addr Device address
 * @param type Descriptor type
 * @param index Descriptor index
 * @param buffer Buffer for descriptor
 * @param len Pointer to receive actual length
 * @param maxlen Maximum bytes to receive
 * @return XST_SUCCESS or XST_FAILURE
 */
int max3421e_get_descriptor(u8 addr, u8 type, u8 index, u8 *buffer, int *len, int maxlen);

/**
 * Set device address
 * @param old_addr Current address (typically 0)
 * @param new_addr New address to assign
 * @return XST_SUCCESS or XST_FAILURE
 */
int max3421e_set_address(u8 old_addr, u8 new_addr);

/**
 * Set device configuration
 * @param addr Device address
 * @param config Configuration value
 * @return XST_SUCCESS or XST_FAILURE
 */
int max3421e_set_configuration(u8 addr, u8 config);

/**
 * Set HID protocol (boot or report)
 * @param addr Device address
 * @param interface Interface number
 * @param protocol 0=Boot protocol, 1=Report protocol
 * @return XST_SUCCESS or XST_FAILURE
 */
int max3421e_set_protocol(u8 addr, u8 interface, u8 protocol);

/**
 * Print MAX3421E status registers for debugging
 */
void max3421e_print_status(void);

#endif /* MAX3421E_H */
