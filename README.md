# README #

# iob-dma

## What is this repository for? ##

The IObundle Direct Memory Access (DMA) is a RISC-V-based Peripheral written in Verilog, which users can download, modify, simulate, and implement in FPGA or ASIC.
This core uses an AXI master interface for the external memory.
It also provides a set of AXI Stream interfaces to make data transfers with each core, providing them with direct access to the external memory.
Using the [C interface](#brief-description-of-c-interface), the CPU can control the data transfers of the DMA.

## Integrate in SoC ##

* Check out [IOb-SoC-SUT](https://github.com/IObundle/iob-soc-sut)

## Usage

The main class that describes this core is located in the `iob_dma.py` Python modules. It contains a set of methods useful to set up and instantiate this core.

The following steps describe the process of creating a DMA peripheral in an IOb-SoC-based system:
1) Import the `iob_dma` class
2) Add the `iob_dma` class to the submodules list. This will copy the required sources of this module to the build directory.
3) Run the `iob_dma(...)` constructor to create a Verilog instance of the DMA peripheral.
4) To use this core as a peripheral of an IOb-SoC-based system:
  1) Add the created instance to the peripherals list of the IOb-SoC-based system.
  2) Use the `_setup_portmap()` method of IOb-SoC to map IOs of the DMA peripheral.
  3) Write the firmware to run in the system, including the `iob-dma.h` C header, and use its driver functions to control this core.

## Example configuration

The `iob_soc_tester.py` script of the [IOb-SoC-SUT](https://github.com/IObundle/iob-soc-sut) system, uses the following lines of code to instantiate a DMA peripheral with the instance name `DMA0`:
```Python
# Import the iob_dma class
from iob_dma import iob_dma

# Class of the Tester system
class iob_soc_tester(iob_soc):
  ...
  @classmethod
  def _create_submodules_list(cls):
      """Create submodules list with dependencies of this module"""
      super()._create_submodules_list(
          [
              iob_dma,
              ...
          ]
      )
  # Method that runs the setup process of the Tester system
  @classmethod
  def _specific_setup(cls):
    ...
    # Create a Verilog instance of this module, named 'DMA0', and add it to the peripherals list of the system.
    cls.peripherals.append(
        iob_dma(
            "DMA0",
            "DMA interface",
            parameters={
                "N_INPUTS": "1",
                "N_OUTPUTS": "1",
                "AXI_ADDR_W": "AXI_ADDR_W",
            },
        )
    )
  ...
```

## Brief description of C interface ##

TODO
