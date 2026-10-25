#include "xparameters.h"
#include "xil_printf.h"
#include "level_indicator.h"
#include <stddef.h>
#include "xstatus.h"
#include "sleep.h"

#define LI_BASE XPAR_AXI_LEVEL_INDICATOR_0_BASEADDR

#define PAUSE_US 2000000

int main( void )
{
    li_setup(LI_BASE);
    
    if (li_write_n(4) != XST_SUCCESS)
    {
       xil_printf("invalid N\r\n");
       return XST_FAILURE;
    }

    const s16 samples[] = {0, 3000, 7000, 11000, 15000, 19000, 23000, 27000, -32768, 0};
    size_t samples_size = sizeof(samples) / sizeof(samples[0]);
    
    for (size_t i = 0; i < samples_size; i++)
    {
        li_write_sample(samples[i]);
        u16 peak  = li_read_peak();
        u8  level = li_read_level();

#ifndef SIMULATION
        xil_printf("in=%d peak=%d level=%d\r\n", samples[i], peak, level);
        usleep(PAUSE_US);
#endif
    }

    while (TRUE)
    {
    }
    
    return XST_SUCCESS;
}
