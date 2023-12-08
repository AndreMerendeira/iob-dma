#include "iob-dma.h"

//DMA functions

// Set DMA base address
void dma_init(int base_address){
  IOB_DMA_INIT_BASEADDR(base_address);
}

// Start a DMA transfer
// base_addr: Base address of external memory to start the data transfer.
// size: Amount of 32-bit words to transfer.
// direction: 0 = Read from memory, 1 = Write to memory.
// interface_number: Which AXI Stream interface to use.
void dma_start_transfer(uint32_t *base_addr, uint32_t size, int direction, uint16_t interface_number){
  IOB_DMA_SET_BASE_ADDR((uint32_t)base_addr);
  IOB_DMA_SET_DIRECTION(direction);
  IOB_DMA_SET_INTERFACE_NUM(interface_number);
  // Setting the transfer size will begin the transfer
  IOB_DMA_SET_TRANSFER_SIZE(size);
}

// Get the ready state of the selected AXIS In interface number
uint8_t dma_get_input_state(uint16_t interface_number){
  IOB_DMA_SET_INTERFACE_NUM(interface_number);
  return IOB_DMA_GET_READY_R();
}

// Get the ready state of the selected AXIS Out interface number
uint8_t dma_get_output_state(uint16_t interface_number){
  IOB_DMA_SET_INTERFACE_NUM(interface_number);
  return IOB_DMA_GET_READY_W();
}

