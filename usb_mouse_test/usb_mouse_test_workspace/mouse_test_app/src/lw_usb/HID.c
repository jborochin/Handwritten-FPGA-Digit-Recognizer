#include <stdio.h>
#include "project_config.h"
#include "GenericMacros.h"
#include "MAX3421E.h"

// ======================================================================
// FORCE DEFINITIONS (To match USB.c)
// ======================================================================
#ifndef BYTE
typedef unsigned char BYTE;
typedef unsigned short WORD;
typedef unsigned long DWORD;
typedef unsigned int BOOL;
#endif

#define USB_DESCRIPTOR_INTERFACE 0x04
#define USB_DESCRIPTOR_ENDPOINT  0x05
#define HID_INTF                 0x03
#define BOOT_INTF_SUBCLASS       0x01
#define HID_PROTOCOL_KEYBOARD    0x01
#define HID_PROTOCOL_MOUSE       0x02
#define BOOT_PROTOCOL            0x00
#define HID_M                    0x02
#define HID_K                    0x01

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

typedef struct {
    union {
        struct {
            BYTE bLength;
            BYTE bDescriptorType;
            WORD wTotalLength;
            BYTE bNumInterfaces;
            BYTE bConfigurationValue;
            BYTE iConfiguration;
            BYTE bmAttributes;
            BYTE bMaxPower;
        } config;
        struct {
            BYTE bLength;
            BYTE bDescriptorType;
            BYTE bInterfaceNumber;
            BYTE bAlternateSetting;
            BYTE bNumEndpoints;
            BYTE bInterfaceClass;
            BYTE bInterfaceSubClass;
            BYTE bInterfaceProtocol;
            BYTE iInterface;
        } interface;
        struct {
            BYTE bLength;
            BYTE bDescriptorType;
            BYTE bEndpointAddress;
            BYTE bmAttributes;
            WORD wMaxPacketSize;
            BYTE bInterval;
        } endpoint;
    } descr;
} USB_DESCR;

#include "HID.h"

extern DEV_RECORD devtable[];
HID_DEVICE hid_device = { { 0 } };
EP_RECORD hid_ep[2] = { { 0 } };

// Function Prototypes for Transfer functions
BYTE XferGetConfDescr(BYTE addr, BYTE confIndex, WORD len, BYTE confValue, BYTE* ptr);
BYTE XferSetConf(BYTE addr, BYTE confIndex, BYTE confValue);
BYTE XferSetProto(BYTE addr, BYTE confIndex, BYTE interface, BYTE protocol);
BYTE XferSetIdle(BYTE addr, BYTE confIndex, BYTE interface, BYTE duration, BYTE reportID);
BYTE XferInTransfer(BYTE addr, BYTE ep, WORD len, BYTE* data, BYTE maxpkt);

// ======================================================================
// MOUSE PROBE (HIDMProbe)
// ======================================================================
BOOL HIDMProbe(BYTE addr, DWORD flags) {
    BYTE rcode;
    BYTE confvalue;
    WORD total_length;
    BYTE bigbuf[256];
    USB_DESCR* data_ptr = (USB_DESCR *) &bigbuf;

    rcode = XferGetConfDescr(addr, 0, 256, 0, bigbuf);
    if (rcode) return FALSE;

    if (data_ptr->descr.config.wTotalLength > 256) total_length = 256;
    else total_length = data_ptr->descr.config.wTotalLength;

    confvalue = data_ptr->descr.config.bConfigurationValue;
    BYTE* byte_ptr = (BYTE*) &bigbuf;

    while (byte_ptr < (BYTE*)(&bigbuf) + total_length) {
        data_ptr = (USB_DESCR*) byte_ptr;

        if (data_ptr->descr.config.bDescriptorType != USB_DESCRIPTOR_INTERFACE) {
            byte_ptr += data_ptr->descr.config.bLength;
            continue;
        }

        if (data_ptr->descr.interface.bInterfaceClass == HID_INTF &&
            data_ptr->descr.interface.bInterfaceSubClass == BOOT_INTF_SUBCLASS &&
            data_ptr->descr.interface.bInterfaceProtocol == HID_PROTOCOL_MOUSE) {

            devtable[addr].devclass = HID_M;
            devtable[addr].epinfo = hid_ep;
            devtable[addr].epinfo[0].MaxPktSize = devtable[addr].epinfo->MaxPktSize; // Preserve
            hid_device.interface = data_ptr->descr.interface.bInterfaceNumber;

            // Find Endpoint
            while (data_ptr->descr.config.bDescriptorType != USB_DESCRIPTOR_ENDPOINT) {
                byte_ptr += data_ptr->descr.config.bLength;
                data_ptr = (USB_DESCR*) byte_ptr;
            }

            devtable[addr].epinfo[1].epAddr = data_ptr->descr.endpoint.bEndpointAddress;
            devtable[addr].epinfo[1].Attr = data_ptr->descr.endpoint.bmAttributes;
            devtable[addr].epinfo[1].MaxPktSize = data_ptr->descr.endpoint.wMaxPacketSize;
            devtable[addr].epinfo[1].Interval = data_ptr->descr.endpoint.bInterval;

            XferSetConf(addr, 0, confvalue);
            XferSetProto(addr, 0, hid_device.interface, BOOT_PROTOCOL);
            XferSetIdle(addr, 0, hid_device.interface, 0, 0);
            return TRUE;
        }
        byte_ptr += data_ptr->descr.config.bLength;
    }
    return FALSE;
}

// ======================================================================
// KEYBOARD PROBE (HIDKProbe)
// ======================================================================
BOOL HIDKProbe(BYTE addr, DWORD flags) {
    BYTE rcode;
    BYTE confvalue;
    WORD total_length;
    BYTE bigbuf[256];
    USB_DESCR* data_ptr = (USB_DESCR *) &bigbuf;

    rcode = XferGetConfDescr(addr, 0, 256, 0, bigbuf);
    if (rcode) return FALSE;

    if (data_ptr->descr.config.wTotalLength > 256) total_length = 256;
    else total_length = data_ptr->descr.config.wTotalLength;

    confvalue = data_ptr->descr.config.bConfigurationValue;
    BYTE* byte_ptr = (BYTE*) &bigbuf;

    while (byte_ptr < (BYTE*)(&bigbuf) + total_length) {
        data_ptr = (USB_DESCR*) byte_ptr;

        if (data_ptr->descr.config.bDescriptorType != USB_DESCRIPTOR_INTERFACE) {
            byte_ptr += data_ptr->descr.config.bLength;
            continue;
        }

        if (data_ptr->descr.interface.bInterfaceClass == HID_INTF &&
            data_ptr->descr.interface.bInterfaceSubClass == BOOT_INTF_SUBCLASS &&
            data_ptr->descr.interface.bInterfaceProtocol == HID_PROTOCOL_KEYBOARD) {

            devtable[addr].devclass = HID_K;
            devtable[addr].epinfo = hid_ep;
            devtable[addr].epinfo[0].MaxPktSize = devtable[addr].epinfo->MaxPktSize;
            hid_device.interface = data_ptr->descr.interface.bInterfaceNumber;

            while (data_ptr->descr.config.bDescriptorType != USB_DESCRIPTOR_ENDPOINT) {
                byte_ptr += data_ptr->descr.config.bLength;
                data_ptr = (USB_DESCR*) byte_ptr;
            }

            devtable[addr].epinfo[1].epAddr = data_ptr->descr.endpoint.bEndpointAddress;
            devtable[addr].epinfo[1].Attr = data_ptr->descr.endpoint.bmAttributes;
            devtable[addr].epinfo[1].MaxPktSize = data_ptr->descr.endpoint.wMaxPacketSize;
            devtable[addr].epinfo[1].Interval = data_ptr->descr.endpoint.bInterval;

            XferSetConf(addr, 0, confvalue);
            XferSetProto(addr, 0, hid_device.interface, BOOT_PROTOCOL);
            XferSetIdle(addr, 0, hid_device.interface, 0, 0);
            return TRUE;
        }
        byte_ptr += data_ptr->descr.config.bLength;
    }
    return FALSE;
}

// ======================================================================
// POLLING FUNCTIONS
// ======================================================================

BYTE mousePoll(BOOT_MOUSE_REPORT* buf) {
    BYTE rcode;
    MAXreg_wr(rPERADDR, hid_device.addr);
    rcode = XferInTransfer(hid_device.addr, 1, 3, (BYTE*) buf, devtable[hid_device.addr].epinfo[1].MaxPktSize);
    return rcode;
}

BYTE kbdPoll(BOOT_KBD_REPORT* buf) {
    BYTE rcode;
    MAXreg_wr(rPERADDR, hid_device.addr);
    rcode = XferInTransfer(hid_device.addr, 1, 8, (BYTE*) buf, devtable[hid_device.addr].epinfo[1].MaxPktSize);
    return rcode;
}
