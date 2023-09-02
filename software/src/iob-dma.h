#ifndef _DMA_H_
#define _DMA_H_

#include <stdint.h>

#include "iob_dma_swreg.h"

//DMA functions

// Set DMA base address and Verilog parameters
void dma_init(int base_address);

// Start a DMA transfer
void dma_start_transfer(uint32_t *base_addr, uint32_t size, int direction, uint16_t interface_number);

// Get the ready state of the selected AXIS In interface number
uint8_t dma_get_input_state(uint16_t interface_number);

// Get the ready state of the selected AXIS Out interface number
uint8_t dma_get_output_state(uint16_t interface_number);

#endif //_DMA_H_
