include $(DMA_DIR)/hardware/hardware.mk

ifeq ($(VCD),1)
DEFINE+=$(defmacro)VCD
endif

DMA_TB_DIR=$(DMA_DIR)/hardware/testbench

VSRC+=$(wildcard $(DMA_TB_DIR)/*.v)
VSRC+=$(DMA_DIR)/submodules/LIB/submodules/AXI/rtl/axi_ram.v