#PATHS
REMOTE_ROOT_DIR ?=sandbox/iob-soc/submodules/DMA
DMA_HW_DIR:=$(DMA_DIR)/hardware
DMA_INC_DIR:=$(DMA_HW_DIR)/include
DMA_SRC_DIR:=$(DMA_HW_DIR)/src
DMA_SIM_DIR:=$(DMA_HW_DIR)/simulation
SUBMODULES_DIR:=$(DMA_DIR)/submodules

#SUBMODULE PATHS
SUBMODULES=
SUBMODULE_DIRS=$(shell ls $(SUBMODULES_DIR))
$(foreach d, $(SUBMODULE_DIRS), $(eval TMP=$(shell make -C $(SUBMODULES_DIR)/$d corename | grep -v make)) $(eval SUBMODULES+=$(TMP)) $(eval $(TMP)_DIR ?=$(SUBMODULES_DIR)/$d))


#SIMULATION
SIMULATOR ?=icarus
SIMULATOR_LIST ?=icarus

# VERSION
VERSION ?=0.1
VLINE:="V$(VERSION)"
DMA_version.txt:
ifeq ($(VERSION),)
	$(error "variable VERSION is not set")
endif
	echo $(VLINE) > version.txt
