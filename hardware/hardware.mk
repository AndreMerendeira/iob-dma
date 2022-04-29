ifeq ($(filter DMA, $(HW_MODULES)),)

#add itself to HW_MODULES list
HW_MODULES+=DMA

# sources
VSRC+=$(DMA_DIR)/hardware/src/iob_dma.v

endif
