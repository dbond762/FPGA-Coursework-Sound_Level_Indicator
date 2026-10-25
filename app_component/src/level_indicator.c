#include "level_indicator.h"

#include "xil_io.h"
#include <xstatus.h>

#define LI_IN    0x00
#define LI_N     0x04
#define LI_PEAK  0x08
#define LI_LEVEL 0x0C

static u32 li_base;

void li_setup(u32 baseaddr)
{
    li_base = baseaddr;
}

XStatus li_write_n(u8 n)
{
    if (n < 1 || n > 8)
    {
        return XST_FAILURE;
    }
    
    Xil_Out32(li_base + LI_N, (u32)n);

    return XST_SUCCESS;
}

void li_write_sample(s16 sample)
{
    Xil_Out32(li_base + LI_IN, (u32)(s32)sample);
}

u16 li_read_peak(void)
{
    return (u16)Xil_In32(li_base + LI_PEAK);
}

u8 li_read_level(void)
{
    return (u8)(Xil_In32(li_base + LI_LEVEL) & 0xF);
}
