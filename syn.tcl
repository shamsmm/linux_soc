yosys read_verilog -sv $::env(FILES) -I $::env(RVCORE_SOURCE) -I $::env(IC_SOURCE)
yosys synth_gowin -top $(TOP_MODULE) -json $(TOP_MODULE).json