ifeq ($(filter DMA, $(HW_MODULES)),)

LIB_DIR ?=$(DMA_DIR)/submodules/LIB
include $(LIB_DIR)/hardware/hardware.mk
include $(LIB_DIR)/hardware/iob2axi/hardware.mk

#add itself to HW_MODULES list
HW_MODULES+=DMA

#DMA HARDWARE

# sources
VSRC+=$(DMA_SRC_DIR)/iob_dma_axi.v

endif
