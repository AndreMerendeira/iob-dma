CORE_NAME:=DMA
IS_CORE:=1
USE_NETLIST ?=0
TOP_MODULE:=dma_axi

#PATHS
DMA_HW_DIR:=$(DMA_DIR)/hardware
DMA_INC_DIR:=$(DMA_HW_DIR)/include
DMA_SRC_DIR:=$(DMA_HW_DIR)/src
DMA_TB_DIR:=$(DMA_HW_DIR)/testbench
DMA_FPGA_DIR:=$(DMA_HW_DIR)/fpga
DMA_SUBMODULES_DIR:=$(DMA_DIR)/submodules
TEX_DIR ?=$(DMA_SUBMODULES_DIR)/TEX
REMOTE_ROOT_DIR ?=sandbox/iob-dma

#SIMULATION
SIMULATOR ?=icarus
SIM_SERVER ?=localhost
SIM_USER ?=$(USER)
SIM_DIR ?=hardware/simulation/$(SIMULATOR)

#FPGA
FPGA_FAMILY ?=XCKU
FPGA_USER ?=$(USER)
FPGA_SERVER ?=pudim-flan.iobundle.com
ifeq ($(FPGA_FAMILY),XCKU)
        FPGA_COMP:=vivado
        FPGA_PART:=xcku040-fbva676-1-c
else #default; ifeq ($(FPGA_FAMILY),CYCLONEV-GT)
        FPGA_COMP:=quartus
        FPGA_PART:=5CGTFD9E5F35C7
endif
FPGA_DIR ?= $(DMA_DIR)/hardware/fpga/$(FPGA_COMP)
ifeq ($(FPGA_COMP),vivado)
FPGA_LOG:=vivado.log
else ifeq ($(FPGA_COMP),quartus)
FPGA_LOG:=quartus.log
endif

#ASIC
ASIC_NODE ?=umc130
ASIC_SERVER ?=micro5.lx.it.pt
ASIC_COMPILE_ROOT_DIR ?=$(ROOT_DIR)/sandbox/iob-dma
ASIC_USER ?=user14
ASIC_DIR ?=hardware/asic/$(ASIC_NODE)

XILINX ?=1
INTEL ?=1

VLINE:="V$(VERSION)"
$(CORE_NAME)_version.txt:
ifeq ($(VERSION),)
	$(error "variable VERSION is not set")
endif
	echo $(VLINE) > version.txt
