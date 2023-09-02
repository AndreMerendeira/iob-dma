/* PC Emulation of PFSM peripheral */

#include <stdint.h>
#include <stdio.h>

#include "iob_dma_swreg.h"

static uint32_t base;
void IOB_DMA_INIT_BASEADDR(uint32_t addr) {
	base = addr;
}

void dma_start_transfer(uint32_t base_addr, uint32_t size, int direction, uint16_t interface_number){
}

uint8_t dma_get_input_state(uint16_t interface_number){
    return 0x01;
}

uint8_t dma_get_output_state(uint16_t interface_number){
    return 0x01;
}
