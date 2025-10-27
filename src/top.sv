module top(
    // system clk and reset
    input bit sysclk,
    input bit sysrst_n,
    
    // input/outputs
    inout [7:0] gpio,

    // debug transport module pins
    input tdi,
    input tms,
    input tclk,
    input trst,
    inout tdo_tristate
);

bit clk;
//assign clk = sysclk; // 27MHz
logic rst_n;
logic ndmreset;
assign rst_n = !ndmreset & sysrst_n;

Gowin_CLKDIV divider0 (
    .clkout(clk), //output clkout
    .hclkin(sysclk), //input hclkin
    .resetn(rst_n) //input resetn
);

soc #(.CDC("REG")) soc(.*); // The SoC

TBUF jtag_tdo (
  .I    (tdo),      // Input data
  .O    (tdo_tristate),       // Output data
  .OEN  (!tdo_en) // Active-low output enable
);


endmodule