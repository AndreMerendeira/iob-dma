#
# TOP MAKEFILE
#

DMA_DIR:=.
include config.mk

#
# SIMULATE
#
sim:
	make -C $(SIM_DIR) run

sim-waves:
	gtkwave $(SIM_DIR)/*.vcd &

sim-clean:
	make -C $(SIM_DIR) clean

#
# CLEAN ALL
#
clean-all: sim-clean

.PHONY: sim sim-waves sim-clean \
	clean-all
