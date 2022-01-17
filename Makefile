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
	make -C $(SIM_DIR) clean

# CLEAN ALL
clean-all: sim-clean

.PHONY: corename
	sim sim-waves sim-clean \
	clean-all
