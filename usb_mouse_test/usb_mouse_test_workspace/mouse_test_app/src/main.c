#include <stdio.h>
#include "xparameters.h"
#include "xil_printf.h"
#include "xgpio.h"
#include "xspi.h"
#include "sleep.h"

// Point to the files inside the lw_usb folder
#include "lw_usb/GenericMacros.h"
#include "lw_usb/GenericTypeDefs.h"
#include "lw_usb/MAX3421E.h"
#include "lw_usb/USB.h"
#include "lw_usb/usb_ch9.h"
#include "lw_usb/transfer.h"
#include "lw_usb/HID.h"

// =========================================================
// Configuration
// =========================================================

// Check xparameters.h if your ID is different
#define GPIO_MOUSE_BRIDGE_ID XPAR_GPIO_0_DEVICE_ID

// Screen Boundaries
#define MAX_X 639
#define MAX_Y 479

#define USB_STATE_RUNNING 0x41

// Global Variables for Cursor Position
int cursor_x = 320; // Start in center
int cursor_y = 240;

extern HID_DEVICE hid_device;
static XGpio Gpio_Bridge; // Renamed for clarity (talks to FPGA logic)

static BYTE addr = 1;               //hard-wired USB address
const char* const devclasses[] = { " Uninitialized", " HID Keyboard", " HID Mouse", " Mass storage" };

// =========================================================
// Helper Functions
// =========================================================

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
    //Query rate and protocol
    rcode = XferGetIdle(addr, 0, hid_device.interface, 0, &tmpbyte);
    if (rcode) {   //error handling
        xil_printf("GetIdle Error. Error code: ");
        xil_printf("%x \n", rcode);
    } else {
        xil_printf("Update rate: ");
        xil_printf("%x \n", tmpbyte);
    }
    xil_printf("Protocol: ");
    rcode = XferGetProto(addr, 0, hid_device.interface, &tmpbyte);
    if (rcode) {   //error handling
        xil_printf("GetProto Error. Error code ");
        xil_printf("%x \n", rcode);
    } else {
        xil_printf("%d \n", tmpbyte);
    }
    return device;
}

// Function to pack data and send to FPGA Logic
// Format: [22:Predict] [21:Clear] [20:Draw] [19:10:Y] [9:0:X]
void SendMouseToHardware(int x, int y, u8 buttons) {
    u32 data_packet = 0;

    // 1. Pack Coordinates
    data_packet |= (x & 0x3FF);         // Bits 0-9: X
    data_packet |= ((y & 0x3FF) << 10); // Bits 10-19: Y

    // 2. Pack Buttons (Active High)
    // buf.button bit 0 is Left, bit 1 is Right, bit 2 is Middle
    if (buttons & 0x01) data_packet |= (1 << 20); // Bit 20: Left Click -> Draw
    if (buttons & 0x02) data_packet |= (1 << 21); // Bit 21: Right Click -> Clear
    if (buttons & 0x04) data_packet |= (1 << 22); // Bit 22: Middle Click -> Predict

    // 3. Write to GPIO Channel 1
    XGpio_DiscreteWrite(&Gpio_Bridge, 1, data_packet);
}

// =========================================================
// Main Loop
// =========================================================
int main() {
    // init_platform(); // NOT NEEDED for empty application template

    // Initialize GPIO bridge to hardware
    XGpio_Initialize(&Gpio_Bridge, GPIO_MOUSE_BRIDGE_ID);
    XGpio_SetDataDirection(&Gpio_Bridge, 1, 0x00000000); // Channel 1: All Outputs (To FPGA)

    BYTE rcode;
    BOOT_MOUSE_REPORT buf;      //USB mouse report
    BOOT_KBD_REPORT kbdbuf;     //USB keyboard report

    BYTE runningdebugflag = 0;
    BYTE errorflag = 0;
    BYTE device;

    xil_printf("initializing MAX3421E...\n");
    MAX3421E_init();
    xil_printf("initializing USB...\n");
    USB_init();

    while (1) {
        MAX3421E_Task();
        USB_Task();

        if (GetUsbTaskState() == USB_STATE_RUNNING) {
            if (!runningdebugflag) {
                runningdebugflag = 1;
                device = GetDriverandReport();
            }
            else if (device == 1) {
                // Keyboard logic (Optional - keeping generic polling)
                rcode = kbdPoll(&kbdbuf);
                if (rcode == hrNAK) continue;
            }
            else if (device == 2) {
                // ============================================================
                // MOUSE HANDLING LOGIC
                // ============================================================
                rcode = mousePoll(&buf);
                if (rcode == hrNAK) {
                    continue;
                } else if (rcode) {
                    xil_printf("Mouse Error: %x \n", rcode);
                    continue;
                }

                // 1. Read Displacements (Signed 8-bit integers)
                signed char dx = (signed char)buf.Xdispl;
                signed char dy = (signed char)buf.Ydispl;

                // 2. Accumulate Position
                cursor_x += dx;
                cursor_y += dy;

                // 3. Clamp to Screen Limits (640x480)
                if (cursor_x < 0) cursor_x = 0;
                if (cursor_x > MAX_X) cursor_x = MAX_X;

                if (cursor_y < 0) cursor_y = 0;
                if (cursor_y > MAX_Y) cursor_y = MAX_Y;

                // 4. Send absolute position to FPGA
                SendMouseToHardware(cursor_x, cursor_y, buf.button);

                // Optional: Debug print every few frames if needed
                // xil_printf("X: %d, Y: %d, Btn: %x\n", cursor_x, cursor_y, buf.button);
            }
        } else if (GetUsbTaskState() == USB_STATE_ERROR) {
            if (!errorflag) {
                errorflag = 1;
                xil_printf("USB Error State\n");
            }
        } else {
            // Not running, reset flags
            if (runningdebugflag) {
                runningdebugflag = 0;
                MAX3421E_init();
                USB_init();
            }
            errorflag = 0;
        }
    }
    // cleanup_platform(); // NOT NEEDED
    return 0;
}
