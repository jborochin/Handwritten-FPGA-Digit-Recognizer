/*
 * MAX3421E USB Host Controller - Register Definitions
 * For Spartan-7 Urbana Board USB Mouse Test Project
 */

#ifndef MAX3421E_REGS_H
#define MAX3421E_REGS_H

/* =============================================================================
 * SPI Command Format
 * =============================================================================
 * Bit 7:3 = Register address
 * Bit 2   = Direction (0=write, 1=read)  <-- NOTE: This is ACKSTAT for host mode
 * Bit 1   = ACKSTAT (host mode)
 * Bit 0   = Always 0
 */

#define MAX_REG_READ   0x00
#define MAX_REG_WRITE  0x02

/* =============================================================================
 * MAX3421E Register Addresses (host mode)
 * =============================================================================
 */

/* R1 - RCVFIFO: Receive FIFO */
#define rRCVFIFO        0x08    // 1 << 3

/* R2 - SNDFIFO: Send FIFO */
#define rSNDFIFO        0x10    // 2 << 3

/* R3 - SUDFIFO: Setup Data FIFO */
#define rSUDFIFO        0x20    // 4 << 3

/* R4 - RCVBC: Receive Byte Count */
#define rRCVBC          0x30    // 6 << 3

/* R5 - SNDBC: Send Byte Count */
#define rSNDBC          0x38    // 7 << 3

/* R6 - USBIRQ: USB Interrupt Request */
#define rUSBIRQ         0x68    // 13 << 3
#define bmVBUSIRQ       0x40
#define bmNOVBUSIRQ     0x20
#define bmOSCOKIRQ      0x01

/* R7 - USBIEN: USB Interrupt Enable */
#define rUSBIEN         0x70    // 14 << 3
#define bmVBUSIE        0x40
#define bmNOVBUSIE      0x20
#define bmOSCOKIE       0x01

/* R8 - USBCTL: USB Control */
#define rUSBCTL         0x78    // 15 << 3
#define bmCHIPRES       0x20
#define bmPWRDOWN       0x10

/* R9 - CPUCTL: CPU Control */
#define rCPUCTL         0x80    // 16 << 3
#define bmPUSLEWID1     0x80
#define bmPUSLEWID0     0x40
#define bmIE            0x01

/* R10 - PINCTL: Pin Control */
#define rPINCTL         0x88    // 17 << 3
#define bmFDUPSPI       0x10
#define bmINTLEVEL      0x08
#define bmPOSINT        0x04
#define bmGPXB          0x02
#define bmGPXA          0x01

/* R11 - REVISION: Revision */
#define rREVISION       0x90    // 18 << 3

/* R12 - IOPINS1: I/O Pins 1 (directly accessible) */
#define rIOPINS1        0xA0    // 20 << 3

/* R13 - IOPINS2: I/O Pins 2 (directly accessible) */
#define rIOPINS2        0xA8    // 21 << 3

/* R14 - GPINIRQ: GPIO Interrupt Request */
#define rGPINIRQ        0xB0    // 22 << 3

/* R15 - GPINIEN: GPIO Interrupt Enable */
#define rGPINIEN        0xB8    // 23 << 3

/* R16 - GPINPOL: GPIO Interrupt Polarity */
#define rGPINPOL        0xC0    // 24 << 3

/* R17 - HIRQ: Host Interrupt Request */
#define rHIRQ           0xC8    // 25 << 3
#define bmBUSEVENTIRQ   0x01
#define bmRWUIRQ        0x02
#define bmRCVDAVIRQ     0x04
#define bmSNDBAVIRQ     0x08
#define bmSUSDNIRQ      0x10
#define bmCONDETIRQ     0x20
#define bmFRAMEIRQ      0x40
#define bmHXFRDNIRQ     0x80

/* R18 - HIEN: Host Interrupt Enable */
#define rHIEN           0xD0    // 26 << 3

/* R19 - MODE: Mode */
#define rMODE           0xD8    // 27 << 3
#define bmHOST          0x01
#define bmLOWSPEED      0x02
#define bmHUBPRE        0x04
#define bmSOFKAENAB     0x08
#define bmSEPIRQ        0x10
#define bmDELAYISO      0x20
#define bmDMPULLDN      0x40
#define bmDPPULLDN      0x80

/* R20 - PERADDR: Peripheral Address */
#define rPERADDR        0xE0    // 28 << 3

/* R21 - HCTL: Host Control */
#define rHCTL           0xE8    // 29 << 3
#define bmBUSRST        0x01
#define bmFRMRST        0x02
#define bmSAMPLEBUS     0x04
#define bmSIGRSM        0x08
#define bmRCVTOG0       0x10
#define bmRCVTOG1       0x20
#define bmSNDTOG0       0x40
#define bmSNDTOG1       0x80

/* R22 - HXFR: Host Transfer */
#define rHXFR           0xF0    // 30 << 3
/* Token values */
#define tokSETUP        0x10
#define tokIN           0x00
#define tokOUT          0x20
#define tokINHS         0x80
#define tokOUTHS        0xA0
#define tokISOIN        0x40
#define tokISOOUT       0x60

/* R23 - HRSL: Host Result */
#define rHRSL           0xF8    // 31 << 3
#define bmRCVTOGRD      0x10
#define bmSNDTOGRD      0x20
#define bmKSTATUS       0x40
#define bmJSTATUS       0x80
/* Result codes (lower nibble) */
#define hrSUCCESS       0x00
#define hrBUSY          0x01
#define hrBADREQ        0x02
#define hrUNDEF         0x03
#define hrNAK           0x04
#define hrSTALL         0x05
#define hrTOGERR        0x06
#define hrWRONGPID      0x07
#define hrBADBC         0x08
#define hrPIDERR        0x09
#define hrPKTERR        0x0A
#define hrCRCERR        0x0B
#define hrKERR          0x0C
#define hrJERR          0x0D
#define hrTIMEOUT       0x0E
#define hrBABBLE        0x0F

/* =============================================================================
 * USB Standard Requests
 * =============================================================================
 */
#define USB_REQUEST_GET_STATUS          0x00
#define USB_REQUEST_CLEAR_FEATURE       0x01
#define USB_REQUEST_SET_FEATURE         0x03
#define USB_REQUEST_SET_ADDRESS         0x05
#define USB_REQUEST_GET_DESCRIPTOR      0x06
#define USB_REQUEST_SET_DESCRIPTOR      0x07
#define USB_REQUEST_GET_CONFIGURATION   0x08
#define USB_REQUEST_SET_CONFIGURATION   0x09
#define USB_REQUEST_GET_INTERFACE       0x0A
#define USB_REQUEST_SET_INTERFACE       0x0B
#define USB_REQUEST_SYNCH_FRAME         0x0C

/* Descriptor types */
#define USB_DESCRIPTOR_DEVICE           0x01
#define USB_DESCRIPTOR_CONFIGURATION    0x02
#define USB_DESCRIPTOR_STRING           0x03
#define USB_DESCRIPTOR_INTERFACE        0x04
#define USB_DESCRIPTOR_ENDPOINT         0x05
#define USB_DESCRIPTOR_HID              0x21
#define USB_DESCRIPTOR_HID_REPORT       0x22

/* HID Class requests */
#define HID_REQUEST_GET_REPORT          0x01
#define HID_REQUEST_GET_IDLE            0x02
#define HID_REQUEST_GET_PROTOCOL        0x03
#define HID_REQUEST_SET_REPORT          0x09
#define HID_REQUEST_SET_IDLE            0x0A
#define HID_REQUEST_SET_PROTOCOL        0x0B

/* Request type bits */
#define bmREQ_DIR_IN                    0x80
#define bmREQ_TYPE_STANDARD             0x00
#define bmREQ_TYPE_CLASS                0x20
#define bmREQ_TYPE_VENDOR               0x40
#define bmREQ_RECIP_DEVICE              0x00
#define bmREQ_RECIP_INTERFACE           0x01
#define bmREQ_RECIP_ENDPOINT            0x02

#endif /* MAX3421E_REGS_H */
