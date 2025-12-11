#ifndef PROJECT_CONFIG_H_
#define PROJECT_CONFIG_H_

#define _MICROBLAZE_
#include "xparameters.h"
#include "xspi.h"
#include "xgpio.h"

// Undefine conflict macros
#ifdef FALSE
#undef FALSE
#endif
#ifdef TRUE
#undef TRUE
#endif

#include "GenericTypeDefs.h"
#define USB_SPI_CLK_FREQ 10000000

#endif
