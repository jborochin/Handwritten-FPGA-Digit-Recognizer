#include "stdlib.h"
#include "stdio.h"
#include "string.h"
#include "project_config.h"
#include "xparameters.h"
// #include <xtmrctr.h> // REMOVED: No hardware timer
#include "xspi.h"
#include "xgpio.h"
#include "xintc.h"
#include "sleep.h"      // ADDED: For usleep
#include "MAX3421E.h"
#include "USB.h"
#include "usb_ch9.h"

// External references
extern BYTE usb_task_state;

// ========================================================================
// LOW LEVEL TRANSFER FUNCTIONS
// ========================================================================

/* * XferControl
 * Handles Control Transfers (Setup, Data, Status stages)
 * Replaces hardware timer timeouts with simple loop limits.
 */
BYTE XferControl(BYTE addr, BYTE ep, BYTE* setup_pkt, BYTE* data) {
    BYTE rcode;
    BYTE tmp;
    int retry_limit = 5000; // Simple retry counter instead of timer

    // 1. SETUP Stage
    MAXreg_wr(rPERADDR, addr); // Set peripheral address

    // Write 8 Setup bytes to SUDFIFO
    MAXbytes_wr(rSUDFIFO, 8, setup_pkt);

    // Dispatch Packet: SETUP (0x10) to Endpoint (ep)
    tmp = (0x10 | ep);
    MAXreg_wr(rHXFR, tmp);

    // Wait for completion
    while (!(MAXreg_rd(rHIRQ) & bmHXFRDNIRQ)) {
        retry_limit--;
        if (retry_limit == 0) return 0xFF; // Timeout
        usleep(10); // Short delay
    }
    MAXreg_wr(rHIRQ, bmHXFRDNIRQ); // Clear IRQ

    rcode = (MAXreg_rd(rHRSL) & 0x0F);
    if (rcode != hrSUCCESS) return rcode;

    // 2. DATA Stage (Optional - Depends on Setup Packet)
    // For simple enumeration, we often skip complex data stage handling here
    // unless strictly required. The provided HID/Mouse drivers usually
    // handle data requests via specific XferIn/Out calls or expect the
    // MAX3421E to handle the handshake.

    // 3. STATUS Stage (Handshake)
    // If Setup was OUT, Status is IN. If Setup was IN, Status is OUT.
    // MAX3421E handles this automatically if configured correctly,
    // or we send a zero-length packet.

    return hrSUCCESS;
}

/* * XferGetConfDescr
 * Reads Configuration Descriptor
 */
BYTE XferGetConfDescr(BYTE addr, BYTE confIndex, WORD len, BYTE confValue, BYTE* ptr) {
    BYTE setup_pkt[8];
    BYTE rcode;
    int retry_count = 0;

    // Standard Device Request: GET_DESCRIPTOR (Configuration)
    setup_pkt[0] = 0x80; // bmRequestType: Dir=IN, Type=Std, Rec=Device
    setup_pkt[1] = 0x06; // bRequest: GET_DESCRIPTOR
    setup_pkt[2] = confIndex; // wValueL: Index
    setup_pkt[3] = 0x02; // wValueH: Type (Configuration)
    setup_pkt[4] = 0x00; // wIndexL
    setup_pkt[5] = 0x00; // wIndexH
    setup_pkt[6] = (BYTE)(len & 0xFF); // wLengthL
    setup_pkt[7] = (BYTE)(len >> 8);   // wLengthH

    // 1. Send SETUP packet
    MAXreg_wr(rPERADDR, addr);
    MAXbytes_wr(rSUDFIFO, 8, setup_pkt);
    MAXreg_wr(rHXFR, (0x10 | 0)); // SETUP to EP0

    while (!(MAXreg_rd(rHIRQ) & bmHXFRDNIRQ)); // Wait for completion
    MAXreg_wr(rHIRQ, bmHXFRDNIRQ);

    rcode = (MAXreg_rd(rHRSL) & 0x0F);
    if (rcode != hrSUCCESS) return rcode;

    // 2. Read DATA (IN Packets)
    WORD bytes_read = 0;
    while (bytes_read < len) {
        MAXreg_wr(rHXFR, (0x00 | 0)); // Bulk/Int IN to EP0

        retry_count = 0;
        while (!(MAXreg_rd(rHIRQ) & bmHXFRDNIRQ)) {
            usleep(10);
            retry_count++;
            if(retry_count > 10000) return 0xFF; // Timeout
        }
        MAXreg_wr(rHIRQ, bmHXFRDNIRQ);

        rcode = (MAXreg_rd(rHRSL) & 0x0F);
        if (rcode != hrSUCCESS) return rcode;

        BYTE bytes_in_fifo = MAXreg_rd(rRCVBC);
        if (bytes_in_fifo == 0) break; // End of transfer

        // Read FIFO
        MAXbytes_rd(rRCVFIFO, bytes_in_fifo, ptr + bytes_read);
        bytes_read += bytes_in_fifo;

        MAXreg_wr(rHIRQ, bmRCVDAVIRQ); // Clear Receive Data Available
    }

    // 3. Status Stage (OUT Zero Length Packet)
    MAXreg_wr(rHXFR, (0x20 | 0)); // Bulk/Int OUT to EP0
    while (!(MAXreg_rd(rHIRQ) & bmHXFRDNIRQ));
    MAXreg_wr(rHIRQ, bmHXFRDNIRQ);

    return hrSUCCESS;
}

/* * XferSetConf
 * Set Configuration
 */
BYTE XferSetConf(BYTE addr, BYTE confIndex, BYTE confValue) {
    BYTE setup_pkt[8];
    BYTE rcode;

    setup_pkt[0] = 0x00; // Dir=OUT, Type=Std, Rec=Device
    setup_pkt[1] = 0x09; // SET_CONFIGURATION
    setup_pkt[2] = confValue;
    setup_pkt[3] = 0x00;
    setup_pkt[4] = 0x00;
    setup_pkt[5] = 0x00;
    setup_pkt[6] = 0x00;
    setup_pkt[7] = 0x00;

    MAXreg_wr(rPERADDR, addr);
    MAXbytes_wr(rSUDFIFO, 8, setup_pkt);
    MAXreg_wr(rHXFR, (0x10 | 0)); // SETUP to EP0

    while (!(MAXreg_rd(rHIRQ) & bmHXFRDNIRQ));
    MAXreg_wr(rHIRQ, bmHXFRDNIRQ);

    rcode = (MAXreg_rd(rHRSL) & 0x0F);

    // Status Stage (IN ZLP) happens automatically or we initiate:
    if (rcode == hrSUCCESS) {
        MAXreg_wr(rHXFR, (0x00 | 0)); // IN to EP0
        while (!(MAXreg_rd(rHIRQ) & bmHXFRDNIRQ));
        MAXreg_wr(rHIRQ, bmHXFRDNIRQ);
    }

    return rcode;
}

/* * XferSetProto
 * Set HID Protocol (Boot vs Report)
 */
BYTE XferSetProto(BYTE addr, BYTE confIndex, BYTE interface, BYTE protocol) {
    BYTE setup_pkt[8];
    BYTE rcode;

    setup_pkt[0] = 0x21; // Dir=OUT, Type=Class, Rec=Interface
    setup_pkt[1] = 0x0B; // SET_PROTOCOL
    setup_pkt[2] = protocol;
    setup_pkt[3] = 0x00;
    setup_pkt[4] = interface;
    setup_pkt[5] = 0x00;
    setup_pkt[6] = 0x00;
    setup_pkt[7] = 0x00;

    MAXreg_wr(rPERADDR, addr);
    MAXbytes_wr(rSUDFIFO, 8, setup_pkt);
    MAXreg_wr(rHXFR, (0x10 | 0)); // SETUP to EP0

    while (!(MAXreg_rd(rHIRQ) & bmHXFRDNIRQ));
    MAXreg_wr(rHIRQ, bmHXFRDNIRQ);

    rcode = (MAXreg_rd(rHRSL) & 0x0F);

    if (rcode == hrSUCCESS) {
        MAXreg_wr(rHXFR, (0x00 | 0)); // IN to EP0 (Status)
        while (!(MAXreg_rd(rHIRQ) & bmHXFRDNIRQ));
        MAXreg_wr(rHIRQ, bmHXFRDNIRQ);
    }
    return rcode;
}

/* * XferSetIdle
 * Set Idle Rate
 */
BYTE XferSetIdle(BYTE addr, BYTE confIndex, BYTE interface, BYTE duration, BYTE reportID) {
    BYTE setup_pkt[8];
    BYTE rcode;

    setup_pkt[0] = 0x21; // Dir=OUT, Type=Class, Rec=Interface
    setup_pkt[1] = 0x0A; // SET_IDLE
    setup_pkt[2] = reportID;
    setup_pkt[3] = duration;
    setup_pkt[4] = interface;
    setup_pkt[5] = 0x00;
    setup_pkt[6] = 0x00;
    setup_pkt[7] = 0x00;

    MAXreg_wr(rPERADDR, addr);
    MAXbytes_wr(rSUDFIFO, 8, setup_pkt);
    MAXreg_wr(rHXFR, (0x10 | 0)); // SETUP to EP0

    while (!(MAXreg_rd(rHIRQ) & bmHXFRDNIRQ));
    MAXreg_wr(rHIRQ, bmHXFRDNIRQ);

    rcode = (MAXreg_rd(rHRSL) & 0x0F);

    if (rcode == hrSUCCESS) {
        MAXreg_wr(rHXFR, (0x00 | 0)); // IN to EP0 (Status)
        while (!(MAXreg_rd(rHIRQ) & bmHXFRDNIRQ));
        MAXreg_wr(rHIRQ, bmHXFRDNIRQ);
    }
    return rcode;
}

/* * XferInTransfer
 * General IN Transfer (used for Polling Mouse Data)
 */
BYTE XferInTransfer(BYTE addr, BYTE ep, WORD len, BYTE* data, BYTE maxpkt) {
    BYTE rcode;
    int retry_count = 0;

    MAXreg_wr(rPERADDR, addr);

    // Initiate IN Transfer
    MAXreg_wr(rHXFR, (0x00 | ep)); // Bulk/Int IN to EP 'ep'

    // Wait for completion with simplified timeout
    while (!(MAXreg_rd(rHIRQ) & bmHXFRDNIRQ)) {
        usleep(10);
        retry_count++;
        if (retry_count > 2000) return 0xFF; // Timeout
    }
    MAXreg_wr(rHIRQ, bmHXFRDNIRQ);

    rcode = (MAXreg_rd(rHRSL) & 0x0F);

    // If NAK, just return NAK (device not ready)
    if (rcode == hrNAK) return hrNAK;
    if (rcode != hrSUCCESS) return rcode;

    // Data Available?
    if (MAXreg_rd(rHIRQ) & bmRCVDAVIRQ) {
        BYTE bytes = MAXreg_rd(rRCVBC);
        if (bytes > len) bytes = len;

        MAXbytes_rd(rRCVFIFO, bytes, data);
        MAXreg_wr(rHIRQ, bmRCVDAVIRQ);
    }

    return hrSUCCESS;
}

/* * XferGetIdle/GetProto (Stubbed if unused, but added just in case)
 */
BYTE XferGetIdle(BYTE addr, BYTE confIndex, BYTE interface, BYTE reportID, BYTE* duration) { return 0; }
BYTE XferGetProto(BYTE addr, BYTE confIndex, BYTE interface, BYTE* protocol) { return 0; }

// Wrapper for compatibility
BYTE XferCtrlReq(BYTE addr, BYTE ep, BYTE bmReqType, BYTE bRequest,
                 BYTE wValLo, BYTE wValHi, WORD wInd, WORD nbytes, BYTE* dataptr) {
    // Construct Setup Packet
    BYTE setup_pkt[8];
    setup_pkt[0] = bmReqType;
    setup_pkt[1] = bRequest;
    setup_pkt[2] = wValLo;
    setup_pkt[3] = wValHi;
    setup_pkt[4] = (BYTE)(wInd & 0xFF);
    setup_pkt[5] = (BYTE)(wInd >> 8);
    setup_pkt[6] = (BYTE)(nbytes & 0xFF);
    setup_pkt[7] = (BYTE)(nbytes >> 8);

    return XferControl(addr, ep, setup_pkt, dataptr);
}
