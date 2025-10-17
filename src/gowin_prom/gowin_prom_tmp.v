//Copyright (C)2014-2024 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//Tool Version: V1.9.11
//Part Number: GW1NR-LV9QN88PC6/I5
//Device: GW1NR-9
//Device Version: C
//Created Time: Fri Oct 17 18:20:20 2025

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

    Gowin_pROM your_instance_name(
        .dout(dout), //output [31:0] dout
        .clk(clk), //input clk
        .oce(oce), //input oce
        .ce(ce), //input ce
        .reset(reset), //input reset
        .ad(ad) //input [9:0] ad
    );

//--------Copy end-------------------
