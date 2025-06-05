// 4KB ROM
module rom_wrapped (
    slave_bus_if.slave bus,
    input bit clk
);

assign bus.bdone = 1'b1;

Gowin_pROM wrapped_mem(
    .dout(bus.rdata), //output [31:0] dout
    .clk(clk), //input clk
    .oce(1'b1), //input oce
    .ce(bus.ss), //input ce
    .reset(1'b0), //input reset
    .ad(bus.addr[9:0]) //input [9:0] ad
);

endmodule