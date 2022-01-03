include $(DMA_DIR)/config.mk

USE_NETLIST ?=0

#add itself to MODULES list
MODULES+=$(shell make -C $(DMA_DIR) corename | grep -v make)

#include submodule's hardware
$(foreach p, $(SUBMODULES), $(if $(filter $p, $(MODULES)),,$(eval include $($p_DIR)/hardware/hardware.mk)))

#DMA HARDWARE

#hardware include dirs
INCLUDE+=$(incdir)$(DMA_INC_DIR)

# sources
VSRC+=$(wildcard $(DMA_SRC_DIR)/*.v)


dma_clean_hw:
	@rm -rf $(DMA_FPGA_DIR)/vivado/XCKU $(DMA_FPGA_DIR)/quartus/CYCLONEV-GT

.PHONY: dma_clean_hw
