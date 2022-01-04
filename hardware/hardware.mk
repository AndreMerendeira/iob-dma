include $(DMA_DIR)/config.mk

#add itself to MODULES list
MODULES+=$(shell make -C $(DMA_DIR) corename | grep -v make)

#include submodule's hardware
$(foreach p, $(SUBMODULES), $(if $(filter $p, $(MODULES)),,$(eval include $($p_DIR)/hardware/hardware.mk)))

#DMA HARDWARE

#hardware include dirs
INCLUDE+=$(incdir)$(DMA_INC_DIR)

# sources
VSRC+=$(wildcard $(DMA_SRC_DIR)/*.v)
