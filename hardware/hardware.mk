include $(DMA_DIR)/core.mk

#submodules
ifneq (INTERCON,$(filter INTERCON, $(SUBMODULES)))
SUBMODULES+=INTERCON
include $(INTERCON_DIR)/hardware/hardware.mk
endif

# include
INCLUDE+=$(incdir)$(DMA_INC_DIR)

# headers
VHDR+=$(wildcard $(DMA_INC_DIR)/*.vh)

# sources
VSRC+=$(wildcard $(DMA_SRC_DIR)/*.v)

clean_hw:
	@rm -rf $(DMA_FPGA_DIR)/vivado/XCKU $(DMA_FPGA_DIR)/quartus/CYCLONEV-GT

.PHONY: clean_hw
