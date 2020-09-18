DMA_HW_DIR:=$(DMA_DIR)/hardware

#include
DMA_INC_DIR:=$(DMA_HW_DIR)/include
INCLUDE+=$(incdir) $(DMA_INC_DIR)

#headers
WHDR+=$(wildcard $(DMA_INC_DIR)/*.vh)

#sources
DMA_SRC_DIR:=$(DMA_HW_DIR)/src
VSRC+=$(wildcard $(DMA_SRC_DIR)/*.v)
