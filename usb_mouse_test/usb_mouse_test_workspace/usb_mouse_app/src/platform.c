#include "xil_cache.h"
#include "platform.h"

void init_platform(void)
{
    /* Initialize caches if present */
    #ifdef __MICROBLAZE__
    #ifdef XPAR_MICROBLAZE_USE_ICACHE
        Xil_ICacheEnable();
    #endif
    #ifdef XPAR_MICROBLAZE_USE_DCACHE
        Xil_DCacheEnable();
    #endif
    #endif
}

void cleanup_platform(void)
{
    /* Disable caches */
    #ifdef __MICROBLAZE__
    #ifdef XPAR_MICROBLAZE_USE_DCACHE
        Xil_DCacheDisable();
    #endif
    #ifdef XPAR_MICROBLAZE_USE_ICACHE
        Xil_ICacheDisable();
    #endif
    #endif
}
