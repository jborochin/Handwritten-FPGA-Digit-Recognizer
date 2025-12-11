/*
 * USB HID Mouse Driver - Header
 * For Spartan-7 Urbana Board USB Mouse Test Project
 */

#ifndef USB_MOUSE_H
#define USB_MOUSE_H

#include "xil_types.h"
#include "xstatus.h"

/* Screen bounds - adjust for your display */
#define MOUSE_MAX_X 639
#define MOUSE_MAX_Y 479

/* Mouse button masks */
#define MOUSE_BTN_LEFT   0x01
#define MOUSE_BTN_RIGHT  0x02
#define MOUSE_BTN_MIDDLE 0x04

/* Mouse state structure */
typedef struct {
    s32 x;          /* Absolute X position */
    s32 y;          /* Absolute Y position */
    u8 buttons;     /* Button state */
    s8 wheel;       /* Scroll wheel delta */
} usb_mouse_t;

/**
 * Enumerate and initialize USB mouse
 * This performs the full USB enumeration sequence:
 * - Device detection
 * - Bus reset
 * - Get descriptors
 * - Set address
 * - Set configuration
 * - Set boot protocol
 * 
 * @return XST_SUCCESS if mouse initialized, XST_FAILURE otherwise
 */
int usb_mouse_enumerate(void);

/**
 * Poll mouse for new data
 * Should be called periodically (e.g., every 10ms)
 * 
 * @param mouse Pointer to receive current mouse state
 * @return XST_SUCCESS on success, XST_FAILURE on error
 */
int usb_mouse_poll(usb_mouse_t *mouse);

/**
 * Check if mouse has been initialized
 * @return 1 if initialized, 0 otherwise
 */
int usb_mouse_is_initialized(void);

/**
 * Get current mouse state without polling
 * @param mouse Pointer to receive current state
 */
void usb_mouse_get_state(usb_mouse_t *mouse);

/**
 * Reset mouse position to center of screen
 */
void usb_mouse_reset_position(void);

#endif /* USB_MOUSE_H */
