ifeq ($(filter DMA, $(HW_MODULES)),)

include $(DMA_DIR)/config.mk

#add itself to HW_MODULES list
HW_MODULES+=DMA

#DMA HARDWARE

# sources
VSRC+=$(DMA_SRC_DIR)/dma_axi.v
VSRC+=$(DMA_SRC_DIR)/dma_axi_r.v
VSRC+=$(DMA_SRC_DIR)/dma_axi_w.v

endif
