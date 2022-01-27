#
# CONFIGURATIONS FILE
#

TOP_MODULE=iob_dma

#PATHS
REMOTE_ROOT_DIR ?=sandbox/iob-dma
DMA_HW_DIR:=$(DMA_DIR)/hardware
DMA_INC_DIR:=$(DMA_HW_DIR)/include
DMA_SRC_DIR:=$(DMA_HW_DIR)/src
DMA_SIM_DIR:=$(DMA_HW_DIR)/simulation
SIM_DIR?=$(DMA_SIM_DIR)
SUBMODULES_DIR:=$(DMA_DIR)/submodules


# SUBMODULE PATHS
SUBMODULES_DIR_LIST=$(shell ls $(SUBMODULES_DIR))
$(foreach d, $(SUBMODULES_DIR_LIST), $(eval $d_DIR ?=$(SUBMODULES_DIR)/$d))

#SIMULATION
SIMULATOR ?=icarus
SIM_DIR ?=$(DMA_SIM_DIR)/$(SIMULATOR)
SIMULATOR_LIST ?=icarus

# VERSION
VERSION ?=0.1
VLINE:="V$(VERSION)"
DMA_version.txt:
ifeq ($(VERSION),)
	$(error "variable VERSION is not set")
endif
	echo $(VLINE) > version.txt
