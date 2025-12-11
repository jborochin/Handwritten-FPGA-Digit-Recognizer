// USB Mouse Driver for Digit Recognition Project
// Fixed version - handles hrSTALL error properly
//
// GPIO Data Format (matches digit_recognizer_top.sv):
//   [9:0]   = X position (0-639)
//   [19:10] = Y position (0-479)
//   [20]    = Draw enable (left button)
//   [21]    = Clear canvas (right button)
//   [22]    = Predict (middle button)

#include <stdio.h>
#include "platform.h"
#include "lw_usb/GenericMacros.h"
#include "lw_usb/GenericTypeDefs.h"
#include "lw_usb/MAX3421E.h"
#include "lw_usb/USB.h"
#include "lw_usb/usb_ch9.h"
#include "lw_usb/transfer.h"
#include "lw_usb/HID.h"

#include "xparameters.h"
#include <xgpio.h>

extern HID_DEVICE hid_device;

// GPIO instance
static XGpio Gpio_mouse;

static BYTE addr = 1;
const char* const devclasses[] = { " Uninitialized", " HID Keyboard", " HID Mouse", " Mass storage" };

// USB error codes for reference
#define hrSUCCESS   0x00
#define hrBUSY      0x01
#define hrBADREQ    0x02
#define hrUNDEF     0x03
#define hrNAK       0x04
#define hrSTALL     0x05
// Note: Error 6 might be hrTOGERR or similar depending on library version

// ============================================
// Canvas/Screen Parameters
// ============================================
#define SCREEN_WIDTH   640
#define SCREEN_HEIGHT  480

#define CANVAS_X       40
#define CANVAS_Y       100
#define CANVAS_W       280
#define CANVAS_H       280

// Mouse position - absolute coordinates
static int mouse_x;
static int mouse_y;

#define MOUSE_SENSITIVITY 2

// ============================================
// USB Initialization with Boot Protocol Setup
// ============================================
BYTE GetDriverandReport() {
    BYTE i;
    BYTE rcode;
    BYTE device = 0xFF;
    BYTE tmpbyte;

    DEV_RECORD* tpl_ptr;
    xil_printf("Reached USB_STATE_RUNNING (0x40)\n");

    for (i = 1; i < USB_NUMDEVICES; i++) {
        tpl_ptr = GetDevtable(i);
        if (tpl_ptr->epinfo != NULL) {
            xil_printf("Device: %d", i);
            xil_printf("%s \n", devclasses[tpl_ptr->devclass]);
            device = tpl_ptr->devclass;
        }
    }

    // CRITICAL: Set boot protocol for mouse
    // Protocol 0 = Boot Protocol, Protocol 1 = Report Protocol
    xil_printf("Setting boot protocol...\n");
    rcode = XferSetProto(addr, 0, hid_device.interface, 0);  // 0 = boot protocol
    if (rcode) {
        xil_printf("SetProto Error: 0x%02X\n", rcode);
    } else {
        xil_printf("Boot protocol set successfully\n");
    }

    // Verify protocol setting
    rcode = XferGetProto(addr, 0, hid_device.interface, &tmpbyte);
    if (rcode) {
        xil_printf("GetProto Error: 0x%02X\n", rcode);
    } else {
        xil_printf("Protocol: %d (0=boot, 1=report)\n", tmpbyte);
    }

    // Check idle rate
    rcode = XferGetIdle(addr, 0, hid_device.interface, 0, &tmpbyte);
    if (rcode) {
        xil_printf("GetIdle Error: 0x%02X\n", rcode);
    } else {
        xil_printf("Idle rate: %d\n", tmpbyte);
    }

    return device;
}

// ============================================
// Mouse Position Update
// ============================================
void updateMousePosition(signed char dx, signed char dy) {
    mouse_x += dx * MOUSE_SENSITIVITY;
    mouse_y += dy * MOUSE_SENSITIVITY;

    // Clamp to screen bounds
    if (mouse_x < 0) mouse_x = 0;
    if (mouse_x >= SCREEN_WIDTH) mouse_x = SCREEN_WIDTH - 1;
    if (mouse_y < 0) mouse_y = 0;
    if (mouse_y >= SCREEN_HEIGHT) mouse_y = SCREEN_HEIGHT - 1;
}

// ============================================
// GPIO Output
// ============================================
void outputMouseData(BYTE buttons) {
    u32 packed_data = 0;

    BYTE left_btn   = (buttons & 0x01) ? 1 : 0;
    BYTE right_btn  = (buttons & 0x02) ? 1 : 0;
    BYTE middle_btn = (buttons & 0x04) ? 1 : 0;

    packed_data = (mouse_x & 0x3FF)              |
                  ((mouse_y & 0x3FF) << 10)      |
                  (left_btn << 20)               |
                  (right_btn << 21)              |
                  (middle_btn << 22);

    XGpio_DiscreteWrite(&Gpio_mouse, 1, packed_data);
}

// ============================================
// Main Program
// ============================================
int main() {
    int status;

    init_platform();

    xil_printf("\n\n================================\n");
    xil_printf("Digit Recognition Mouse Driver\n");
    xil_printf("        (Fixed Version)\n");
    xil_printf("================================\n");

    // Initialize GPIO
#ifdef XPAR_GPIO_USB_KEYCODE_DEVICE_ID
    xil_printf("GPIO ID: XPAR_GPIO_USB_KEYCODE_DEVICE_ID = %d\n", XPAR_GPIO_USB_KEYCODE_DEVICE_ID);
    status = XGpio_Initialize(&Gpio_mouse, XPAR_GPIO_USB_KEYCODE_DEVICE_ID);
#else
    #ifdef XPAR_AXI_GPIO_0_DEVICE_ID
        xil_printf("GPIO ID: XPAR_AXI_GPIO_0_DEVICE_ID = %d\n", XPAR_AXI_GPIO_0_DEVICE_ID);
        status = XGpio_Initialize(&Gpio_mouse, XPAR_AXI_GPIO_0_DEVICE_ID);
    #else
        xil_printf("ERROR: No GPIO device found!\n");
        status = XST_FAILURE;
    #endif
#endif

    if (status != XST_SUCCESS) {
        xil_printf("GPIO Init FAILED!\n");
        return XST_FAILURE;
    }
    xil_printf("GPIO OK\n");

    // Set GPIO as output
    XGpio_SetDataDirection(&Gpio_mouse, 1, 0x00000000);
    XGpio_SetDataDirection(&Gpio_mouse, 2, 0x00000000);

    // Initialize mouse at canvas center
    mouse_x = CANVAS_X + CANVAS_W / 2;
    mouse_y = CANVAS_Y + CANVAS_H / 2;

    xil_printf("Mouse start: (%d, %d)\n", mouse_x, mouse_y);

    // Output initial position
    outputMouseData(0);

    xil_printf("\nControls:\n");
    xil_printf("  Left = Draw, Right = Clear, Middle = Predict\n");
    xil_printf("================================\n\n");

    // Initialize USB
    xil_printf("Init MAX3421E...\n");
    MAX3421E_init();
    xil_printf("Init USB...\n");
    USB_init();

    xil_printf("Waiting for mouse...\n");

    BYTE rcode;
    BOOT_MOUSE_REPORT buf;
    BOOT_KBD_REPORT kbdbuf;
    BYTE runningdebugflag = 0;
    BYTE errorflag = 0;
    BYTE device;
    BYTE stall_count = 0;
    int poll_count = 0;

    while (1) {
        MAX3421E_Task();
        USB_Task();

        if (GetUsbTaskState() == USB_STATE_RUNNING) {
            if (!runningdebugflag) {
                runningdebugflag = 1;
                device = GetDriverandReport();
                xil_printf("\n*** MOUSE READY ***\n\n");
                stall_count = 0;
            }
            else if (device == 1) {
                // Keyboard
                rcode = kbdPoll(&kbdbuf);
            }
            else if (device == 2) {
                // Mouse
                rcode = mousePoll(&buf);

                if (rcode == hrNAK) {
                    // NAK = no new data, this is normal
                    poll_count++;
                    if (poll_count >= 5000) {
                        // Periodically output position even without movement
                        outputMouseData(0);
                        poll_count = 0;
                    }
                    continue;
                }
                else if (rcode == hrSTALL || rcode == 0x06) {
                    // STALL error - try to recover
                    stall_count++;
                    if (stall_count < 5) {
                        xil_printf("STALL %d - retrying...\n", stall_count);
                    }
                    if (stall_count == 10) {
                        xil_printf("Resetting boot protocol...\n");
                        XferSetProto(addr, 0, hid_device.interface, 0);
                        stall_count = 0;
                    }
                    continue;
                }
                else if (rcode) {
                    // Other error
                    xil_printf("Poll err: 0x%02X\n", rcode);
                    continue;
                }

                // SUCCESS! We got valid mouse data
                stall_count = 0;  // Reset stall counter on success

                signed char dx = (signed char) buf.Xdispl;
                signed char dy = (signed char) buf.Ydispl;

                if (dx != 0 || dy != 0) {
                    updateMousePosition(dx, dy);
                }

                // Always output to FPGA
                outputMouseData(buf.button);

                // Debug output on button change
                static BYTE last_button = 0;
                if (buf.button != last_button) {
                    xil_printf("BTN:0x%02X @ (%d,%d)\n", buf.button, mouse_x, mouse_y);
                    last_button = buf.button;
                }

                // Periodic position output
                static int move_cnt = 0;
                if (dx != 0 || dy != 0) {
                    move_cnt++;
                    if (move_cnt >= 50) {
                        xil_printf("POS:(%d,%d)\n", mouse_x, mouse_y);
                        move_cnt = 0;
                    }
                }
            }
        }
        else if (GetUsbTaskState() == USB_STATE_ERROR) {
            if (!errorflag) {
                errorflag = 1;
                xil_printf("USB Error!\n");
            }
        }
        else {
            if (runningdebugflag) {
                runningdebugflag = 0;
                xil_printf("USB disconnected, reinit...\n");
                MAX3421E_init();
                USB_init();
            }
            errorflag = 0;
        }
    }

    cleanup_platform();
    return 0;
}
