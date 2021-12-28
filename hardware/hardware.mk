include $(DMA_DIR)/core.mk

#submodules
ifneq (INTERCON,$(filter INTERCON, $(MODULES)))
MODULES+=INTERCON
include $(INTERCON_DIR)/hardware/hardware.mk
endif

# sources
VSRC+=$(wildcard $(DMA_SRC_DIR)/*.v)

dma_clean_hw:
	@rm -rf $(DMA_FPGA_DIR)/vivado/XCKU $(DMA_FPGA_DIR)/quartus/CYCLONEV-GT

.PHONY: dma_clean_hw
