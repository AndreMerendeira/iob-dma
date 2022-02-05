ifeq ($(filter DMA, $(HW_MODULES)),)

MEM_DIR ?= $(DMA_DIR)/submodules/MEM
INTERCON_DIR ?=$(DMA_DIR)/submodules/INTERCON
LIB_DIR ?=$(DMA_DIR)/submodules/LIB

#add itself to HW_MODULES list
HW_MODULES+=DMA

DMA_SRC_DIR = $(DMA_DIR)/hardware/src

INCLUDE += -I $(LIB_DIR)/hardware/include

#DMA HARDWARE

# sources
VSRC+=$(DMA_SRC_DIR)/iob_dma.v
VSRC+=$(MEM_DIR)/hardware/fifo/sfifo/iob_sync_fifo.v
VSRC+=$(MEM_DIR)/hardware/fifo/bin_counter.v
VSRC+=$(MEM_DIR)/hardware/ram/2p_ram/iob_2p_ram.v

endif
