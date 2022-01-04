include $(DMA_DIR)/hardware/hardware.mk

ifeq ($(VCD),1)
DEFINE+=$(defmacro)VCD
endif

VSRC+=$(wildcard $(DMA_TB_DIR)/*.v)
