/*
 * USB HID Mouse Driver
 * For Spartan-7 Urbana Board USB Mouse Test Project
 */

#include "usb_mouse.h"
#include "max3421e.h"
#include "xil_printf.h"
#include "sleep.h"

/* Mouse state */
static usb_mouse_t mouse_state = {0};
static u8 mouse_addr = 0;
static u8 mouse_ep = 1;          /* Default interrupt endpoint */
static u8 mouse_toggle = 0;
static int mouse_initialized = 0;

/* =============================================================================
 * Device Enumeration
 * =============================================================================
 */

static void print_device_descriptor(u8 *desc)
{
    xil_printf("\r\n--- Device Descriptor ---\r\n");
    xil_printf("  bLength:            %d\r\n", desc[0]);
    xil_printf("  bDescriptorType:    %d\r\n", desc[1]);
    xil_printf("  bcdUSB:             %d.%02d\r\n", desc[3], desc[2]);
    xil_printf("  bDeviceClass:       0x%02X\r\n", desc[4]);
    xil_printf("  bDeviceSubClass:    0x%02X\r\n", desc[5]);
    xil_printf("  bDeviceProtocol:    0x%02X\r\n", desc[6]);
    xil_printf("  bMaxPacketSize0:    %d\r\n", desc[7]);
    xil_printf("  idVendor:           0x%02X%02X\r\n", desc[9], desc[8]);
    xil_printf("  idProduct:          0x%02X%02X\r\n", desc[11], desc[10]);
    xil_printf("  bcdDevice:          %d.%02d\r\n", desc[13], desc[12]);
    xil_printf("  bNumConfigurations: %d\r\n", desc[17]);
}

static int parse_configuration(u8 *config, int len)
{
    int i = 0;
    int found_hid_mouse = 0;
    
    xil_printf("\r\n--- Configuration Descriptor ---\r\n");
    
    while (i < len) {
        u8 desc_len = config[i];
        u8 desc_type = config[i + 1];
        
        if (desc_len == 0) break;
        
        switch (desc_type) {
            case USB_DESCRIPTOR_CONFIGURATION:
                xil_printf("  Configuration: %d interfaces\r\n", config[i + 4]);
                break;
                
            case USB_DESCRIPTOR_INTERFACE:
                xil_printf("  Interface %d: Class=0x%02X SubClass=0x%02X Protocol=0x%02X\r\n",
                           config[i + 2], config[i + 5], config[i + 6], config[i + 7]);
                /* Check for HID Mouse: Class=3, SubClass=1 (Boot), Protocol=2 (Mouse) */
                if (config[i + 5] == 0x03 && config[i + 7] == 0x02) {
                    xil_printf("    -> HID Mouse detected!\r\n");
                    found_hid_mouse = 1;
                }
                break;
                
            case USB_DESCRIPTOR_ENDPOINT:
                xil_printf("  Endpoint: Addr=0x%02X Attr=0x%02X MaxPkt=%d Interval=%dms\r\n",
                           config[i + 2], config[i + 3], 
                           config[i + 4] | (config[i + 5] << 8),
                           config[i + 6]);
                /* Save interrupt IN endpoint for mouse */
                if ((config[i + 2] & 0x80) && (config[i + 3] & 0x03) == 0x03) {
                    mouse_ep = config[i + 2] & 0x0F;
                    xil_printf("    -> Using endpoint %d for mouse data\r\n", mouse_ep);
                }
                break;
                
            case USB_DESCRIPTOR_HID:
                xil_printf("  HID Descriptor: Version=%d.%02d\r\n",
                           config[i + 3], config[i + 2]);
                break;
        }
        
        i += desc_len;
    }
    
    return found_hid_mouse;
}

int usb_mouse_enumerate(void)
{
    u8 buffer[256];
    int len;
    int speed;
    
    xil_printf("\r\n========================================\r\n");
    xil_printf("USB Mouse Enumeration\r\n");
    xil_printf("========================================\r\n");
    
    mouse_initialized = 0;
    
    /* Check for device connection */
    if (!max3421e_device_connected()) {
        xil_printf("No device connected\r\n");
        return XST_FAILURE;
    }
    
    /* Detect device speed */
    speed = max3421e_detect_speed();
    if (speed == USB_SPEED_NONE) {
        xil_printf("Failed to detect device speed\r\n");
        return XST_FAILURE;
    }
    
    /* Perform bus reset */
    if (max3421e_bus_reset() != XST_SUCCESS) {
        xil_printf("Bus reset failed\r\n");
        return XST_FAILURE;
    }
    
    /* Re-detect speed after reset */
    speed = max3421e_detect_speed();
    xil_printf("Device speed after reset: %s\r\n", 
               speed == USB_SPEED_LOW ? "Low" : "Full");
    
    /* Give device time to stabilize */
    usleep(100000);
    
    /* Get device descriptor (first 8 bytes to get max packet size) */
    xil_printf("\r\nGetting device descriptor...\r\n");
    if (max3421e_get_descriptor(0, USB_DESCRIPTOR_DEVICE, 0, buffer, &len, 18) != XST_SUCCESS) {
        xil_printf("Failed to get device descriptor\r\n");
        max3421e_print_status();
        return XST_FAILURE;
    }
    
    print_device_descriptor(buffer);
    
    /* Set device address */
    xil_printf("\r\nSetting device address to 1...\r\n");
    if (max3421e_set_address(0, 1) != XST_SUCCESS) {
        xil_printf("Failed to set address\r\n");
        return XST_FAILURE;
    }
    mouse_addr = 1;
    usleep(10000);  /* Address change settle time */
    xil_printf("Address set successfully\r\n");
    
    /* Get full device descriptor at new address */
    xil_printf("\r\nRe-reading device descriptor at new address...\r\n");
    if (max3421e_get_descriptor(mouse_addr, USB_DESCRIPTOR_DEVICE, 0, buffer, &len, 18) != XST_SUCCESS) {
        xil_printf("Failed to get device descriptor at new address\r\n");
        return XST_FAILURE;
    }
    xil_printf("Device descriptor OK (%d bytes)\r\n", len);
    
    /* Get configuration descriptor */
    xil_printf("\r\nGetting configuration descriptor...\r\n");
    if (max3421e_get_descriptor(mouse_addr, USB_DESCRIPTOR_CONFIGURATION, 0, buffer, &len, 64) != XST_SUCCESS) {
        xil_printf("Failed to get configuration descriptor\r\n");
        return XST_FAILURE;
    }
    
    /* Parse configuration to find HID mouse interface */
    if (!parse_configuration(buffer, len)) {
        xil_printf("WARNING: No HID mouse interface found, proceeding anyway\r\n");
    }
    
    /* Set configuration 1 */
    xil_printf("\r\nSetting configuration 1...\r\n");
    if (max3421e_set_configuration(mouse_addr, 1) != XST_SUCCESS) {
        xil_printf("Failed to set configuration\r\n");
        return XST_FAILURE;
    }
    xil_printf("Configuration set successfully\r\n");
    
    /* Set boot protocol for simpler mouse reports */
    xil_printf("\r\nSetting boot protocol...\r\n");
    if (max3421e_set_protocol(mouse_addr, 0, 0) != XST_SUCCESS) {
        xil_printf("WARNING: Failed to set boot protocol\r\n");
        /* Continue anyway - some mice work without this */
    } else {
        xil_printf("Boot protocol set successfully\r\n");
    }
    
    /* Initialize mouse state */
    mouse_state.x = 0;
    mouse_state.y = 0;
    mouse_state.buttons = 0;
    mouse_toggle = 0;
    mouse_initialized = 1;
    
    xil_printf("\r\n========================================\r\n");
    xil_printf("Mouse enumeration complete!\r\n");
    xil_printf("Address: %d, Endpoint: %d\r\n", mouse_addr, mouse_ep);
    xil_printf("========================================\r\n\r\n");
    
    return XST_SUCCESS;
}

/* =============================================================================
 * Mouse Data Polling
 * =============================================================================
 */

int usb_mouse_poll(usb_mouse_t *mouse)
{
    u8 report[8];
    int len;
    
    if (!mouse_initialized) {
        return XST_FAILURE;
    }
    
    /* Poll the interrupt endpoint */
    if (max3421e_interrupt_in(mouse_addr, mouse_ep, report, &len, 8, &mouse_toggle) != XST_SUCCESS) {
        return XST_FAILURE;
    }
    
    /* If we got data, parse it */
    if (len >= 3) {
        /* Boot protocol mouse report format:
         * Byte 0: Button state (bit0=left, bit1=right, bit2=middle)
         * Byte 1: X movement (signed)
         * Byte 2: Y movement (signed)
         * Byte 3: Wheel (optional)
         */
        mouse_state.buttons = report[0];
        
        /* Update position with signed movement values */
        mouse_state.x += (s8)report[1];
        mouse_state.y += (s8)report[2];
        
        /* Clamp to screen bounds */
        if (mouse_state.x < 0) mouse_state.x = 0;
        if (mouse_state.x > MOUSE_MAX_X) mouse_state.x = MOUSE_MAX_X;
        if (mouse_state.y < 0) mouse_state.y = 0;
        if (mouse_state.y > MOUSE_MAX_Y) mouse_state.y = MOUSE_MAX_Y;
        
        /* Wheel if present */
        if (len >= 4) {
            mouse_state.wheel = (s8)report[3];
        }
        
        /* Copy to output */
        *mouse = mouse_state;
        return XST_SUCCESS;
    }
    
    /* No new data (NAK), return current state */
    *mouse = mouse_state;
    return XST_SUCCESS;
}

int usb_mouse_is_initialized(void)
{
    return mouse_initialized;
}

void usb_mouse_get_state(usb_mouse_t *mouse)
{
    *mouse = mouse_state;
}

void usb_mouse_reset_position(void)
{
    mouse_state.x = MOUSE_MAX_X / 2;
    mouse_state.y = MOUSE_MAX_Y / 2;
}
