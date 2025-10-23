RVCORE_SOURCE = ./src/rv_core
IC_SOURCE = ./src/interconnect
FILES = ./src/rv_core/bus_if_types_pkg.sv
FILES += ./src/rv_core/instructions.sv
FILES += ./src/jtag.sv
FILES += ./src/dm.sv
FILES += ./src/dtm_jtag.sv
FILES += $(filter-out ./src/rv_core/instructions.sv, $(filter-out ./src/rv_core/bus_if_types_pkg.sv, $(wildcard $(RVCORE_SOURCE)/*.sv)))
FILES += $(wildcard $(IC_SOURCE)/*.sv)
FILES += memory.sv memory_word.sv memory_wrapped.sv rom_wrapped.sv gpio_wrapped.sv top.sv jtag_test.sv

export RVCORE_SOURCE
export IC_SOURCE
export FILES
export TOP_MODULE = top

syn:
	yosys syn.tcl