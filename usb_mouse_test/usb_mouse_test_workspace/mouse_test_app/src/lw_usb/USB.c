#include "project_config.h"
#include "MAX3421E.h"
#include "GenericMacros.h"

// ====================================================================
// FORCE DEFINITIONS
// ====================================================================

#define USB_NUMDEVICES 2

// Structures
typedef struct {
    BYTE epAddr;
    BYTE Attr;
    WORD MaxPktSize;
    BYTE Interval;
    BYTE sndToggle;
    BYTE rcvToggle;
} EP_RECORD;

typedef struct {
    EP_RECORD* epinfo;
    BYTE devclass;
} DEV_RECORD;

// Global USB State
BYTE usb_task_state = 0x11;

// Device Table
DEV_RECORD devtable[USB_NUMDEVICES + 1];

// External Function Prototypes
BOOL HIDMProbe(BYTE addr, DWORD flags);
BOOL HIDKProbe(BYTE addr, DWORD flags);

// ====================================================================
// USB STACK FUNCTIONS
// ====================================================================

// Initialize USB Stack
void USB_init(void) {
    usb_task_state = 0x11; // DETACHED_INIT
    for (int i = 0; i < USB_NUMDEVICES + 1; i++) {
        devtable[i].epinfo = NULL;
        devtable[i].devclass = 0;
    }
}

// Main USB Task Manager
void USB_Task(void) {
    BYTE rcode;

    MAX3421E_Task();

    switch (usb_task_state) {
        case 0x11: // USB_DETACHED_SUBSTATE_INITIALIZE
            usb_task_state = 0x12; // WAIT_FOR_DEVICE
            break;

        case 0x12: // USB_DETACHED_SUBSTATE_WAIT_FOR_DEVICE
            // Waiting for interrupt
            break;

        case 0x13: // USB_DETACHED_SUBSTATE_ILLEGAL
            usb_task_state = 0x11;
            break;

        case 0x20: // USB_ATTACHED_SUBSTATE_SETTLE
            usb_task_state = 0x30; // RESET_DEVICE
            break;

        case 0x30: // USB_ATTACHED_SUBSTATE_RESET_DEVICE
            MAXreg_wr(rHCTL, bmBUSRST);
            usb_task_state = 0x40; // WAIT_RESET_COMPLETE
            break;

        case 0x40: // USB_ATTACHED_SUBSTATE_WAIT_RESET_COMPLETE
            if ((MAXreg_rd(rHCTL) & bmBUSRST) == 0) {
                MAXreg_wr(rMODE, bmSOFKAENAB | bmDPPULLDN | bmDMPULLDN | bmHOST | bmSEPIRQ);
                usb_task_state = 0x50; // WAIT_SOF
            }
            break;

        case 0x50: // USB_ATTACHED_SUBSTATE_WAIT_SOF
            if (MAXreg_rd(rHIRQ) & bmFRAMEIRQ) {
                // Try Mouse
                rcode = HIDMProbe(1, 0);
                if (rcode) {
                    usb_task_state = 0x41; // STATE_RUNNING (Unique Value)
                } else {
                    // Try Keyboard
                    rcode = HIDKProbe(1, 0);
                    if (rcode) {
                        usb_task_state = 0x41; // STATE_RUNNING
                    } else {
                        usb_task_state = 0xC0; // ERROR
                    }
                }
            }
            break;

        case 0x41: // USB_STATE_RUNNING (Now 0x41 to avoid conflict)
            break;

        case 0xC0: // USB_STATE_ERROR
            break;
    }
}

DEV_RECORD* GetDevtable(BYTE index) {
    if (index > USB_NUMDEVICES) return NULL;
    return &devtable[index];
}

BYTE GetUsbTaskState(void) {
    return usb_task_state;
}
