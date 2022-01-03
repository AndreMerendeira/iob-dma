#
# TOP MAKEFILE
#

DMA_DIR:=.
include config.mk

corename:
	@echo "DMA"

#
# SIMULATE
#
sim:
	make -C $(SIM_DIR) run

sim-waves:
	gtkwave $(SIM_DIR)/*.vcd &

sim-clean:
	make -C $(SIM_DIR) clean-all

#
# FPGA COMPILE
#

fpga-build:
	make -C $(FPGA_DIR) build

fpga-clean:
	make -C $(FPGA_DIR) clean-all

#
# COMPILE ASIC
#

asic:
ifeq ($(shell hostname), $(ASIC_SERVER))
	make -C $(ASIC_DIR) ASIC=1
else
	ssh $(ASIC_USER)@$(ASIC_SERVER) "if [ ! -d $(REMOTE_ROOT_DIR) ]; then mkdir -p $(REMOTE_ROOT_DIR); fi"
	rsync -avz --delete --exclude .git $(DMA_DIR) $(ASIC_USER)@$(ASIC_SERVER):$(REMOTE_ROOT_DIR)
	ssh -Y -C $(ASIC_USER)@$(ASIC_SERVER) 'cd $(REMOTE_ROOT_DIR); make -C $(ASIC_DIR) ASIC=1'
	scp $(ASIC_USER)@$(ASIC_SERVER):$(REMOTE_ROOT_DIR)/$(ASIC_DIR)/synth/*.txt $(ASIC_DIR)/synth
endif

asic-synth:
ifeq ($(shell hostname), $(ASIC_SERVER))
	make -C $(ASIC_DIR) synth ASIC=1
else
	ssh $(ASIC_USER)@$(ASIC_SERVER) "if [ ! -d $(REMOTE_ROOT_DIR) ]; then mkdir -p $(REMOTE_ROOT_DIR); fi"
	rsync -avz --delete --exclude .git $(DMA_DIR) $(ASIC_USER)@$(ASIC_SERVER):$(REMOTE_ROOT_DIR)
	ssh -Y -C $(ASIC_USER)@$(ASIC_SERVER) 'cd $(REMOTE_ROOT_DIR); make -C $(ASIC_DIR) synth ASIC=1'
	scp $(ASIC_USER)@$(ASIC_SERVER):$(REMOTE_ROOT_DIR)/$(ASIC_DIR)/synth/*.txt $(ASIC_DIR)/synth
endif

asic-sim-synth:
ifeq ($(shell hostname), $(ASIC_SERVER))
	make -C $(HW_DIR)/simulation/ncsim run TEST_LOG=$(TEST_LOG) SYNTH=1
else
	ssh $(ASIC_USER)@$(ASIC_SERVER) "if [ ! -d $(REMOTE_ROOT_DIR) ]; then mkdir -p $(REMOTE_ROOT_DIR); fi"
	rsync -avz --delete --exclude .git $(DMA_DIR) $(ASIC_USER)@$(ASIC_SERVER):$(REMOTE_ROOT_DIR)
	ssh $(ASIC_USER)@$(ASIC_SERVER) 'cd $(REMOTE_ROOT_DIR); make -C $(HW_DIR)/simulation/ncsim run TEST_LOG=$(TEST_LOG) SYNTH=1'
ifeq ($(TEST_LOG),1)
	scp $(ASIC_USER)@$(ASIC_SERVER):$(REMOTE_ROOT_DIR)/$(HW_DIR)/simulation/ncsim/test.log $(HW_DIR)/simulation/ncsim
endif
endif

asic-clean:
	make -C $(ASIC_DIR) clean
ifneq ($(shell hostname), $(ASIC_SERVER))
	rsync -avz --delete --exclude .git $(DMA_DIR) $(ASIC_USER)@$(ASIC_SERVER):$(REMOTE_ROOT_DIR)
	ssh $(ASIC_USER)@$(ASIC_SERVER) "if [ -d $(REMOTE_ROOT_DIR) ]; then cd $(REMOTE_ROOT_DIR); make -C $(ASIC_DIR) clean; fi"
endif


# CLEAN ALL
clean-all: sim-clean fpga-clean asic-clean

.PHONY: corename
	sim sim-waves sim-clean \
	fpga-build fpga-clean \
	asic asic-synth asic-sim-synth asic-clean \
	clean-all
