#ifndef LEVEL_INDICATOR_H
#define LEVEL_INDICATOR_H

#include "xil_types.h"
#include "xstatus.h"

void li_setup(u32 baseaddr);

XStatus li_write_n(u8 n);
void li_write_sample(s16 sample);
u16 li_read_peak(void);
u8 li_read_level(void);

#endif // LEVEL_INDICATOR_H
