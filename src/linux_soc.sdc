//Copyright (C)2014-2025 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.11 
//Created Time: 2025-06-23 22:42:46
create_clock -name dtm_tclk -period 100 -waveform {0 50} [get_ports {dtm_tclk}]
create_clock -name sysclk -period 37.037 -waveform {0 18.518} [get_ports {sysclk}]
create_clock -name clk -period 10 -waveform {0 5} [get_nets {clk}]
