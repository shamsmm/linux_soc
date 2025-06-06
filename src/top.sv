module top(
    input bit sysclk,
    input bit rst_n,
    inout [7:0] gpio
);

bit clk;

Gowin_CLKDIV divider0 (
    .clkout(clk), //output clkout
    .hclkin(sysclk), //input hclkin
    .resetn(rst_n) //input resetn
);

// riscv32 core-0 master interfaces to I-bus and D-bus
master_bus_if dbus_if_core0(clk, rst_n);
master_bus_if ibus_if_core0(clk, rst_n);

// dual port memory interface to I-bus and D-bus 
slave_bus_if dbus_if_mem0(clk, rst_n);
slave_bus_if ibus_if_mem0(clk, rst_n);

// flash rom interface (read only) to bus (I-bus)
slave_bus_if ibus_if_rom0(clk, rst_n);

// gpio memory mapped interface to bus (D-bus)
slave_bus_if dbus_if_gpio0(clk, rst_n);

// riscv32 core-0
rv_core #(.INITIAL_PC(32'h2000_0000)) core0(.ibus(ibus_if_core0), .dbus(dbus_if_core0), .clk(clk), .rst_n(rst_n));

// dual port memory
memory_wrapped mem0(.ibus(ibus_if_mem0), .dbus(dbus_if_mem0), .clk(clk), .rst_n(rst_n));

// rom single port memory
rom_wrapped rom0(.bus(ibus_if_rom0), .clk(clk), .rst_n(rst_n));

// gpio memory mapped
gpio_wrapped gpio0(.bus(dbus_if_gpio0), .clk(clk), .gpio(gpio), .rst_n(rst_n));

// interconnect

dbus_interconnect dbus_ic(.*);
ibus_interconnect ibus_ic(.*);


endmodule