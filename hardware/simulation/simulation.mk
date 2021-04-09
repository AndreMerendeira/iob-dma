include $(DMA_DIR)/hardware/hardware.mk

DEFINE+=$(defmacro)VCD

VSRC+=$(wildcard $(DMA_TB_DIR)/*.v)
