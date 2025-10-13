module top(
    // system clk and reset
    input bit sysclk,
    input bit rst_n,
    
    // input/outputs
    inout [7:0] gpio,

    // debug transport module pins
    input dtm_tdi,
    input dtm_tms,
    input dtm_tclk,
    input dtm_trst,
    inout dtm_tdo
);

bit clk;
assign clk = sysclk; // 27MHz

//Gowin_CLKDIV divider0 (
//    .clkout(clk), //output clkout
//    .hclkin(sysclk), //input hclkin
//    .resetn(rst_n) //input resetn
//);

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

// plic (D-bus)
slave_bus_if dbus_if_plic0(clk, rst_n);

// clit (D-bus)
slave_bus_if dbus_if_clit0(clk, rst_n);

// riscv32 core-0
logic irq_sw0, irq_ext0, irq_timer0;

rv_core #(.INITIAL_PC(32'h2000_0000)) core0(
    .ibus(ibus_if_core0),
    .dbus(dbus_if_core0),
    .haltreq(1'b0),
    .resumereq(1'b0),
    .resethaltreq(1'b0),
    .clk(clk),
    .rst_n(rst_n),
    .irq_sw(irq_sw0),
    .irq_ext(irq_ext0),
    .irq_timer(irq_timer0)
);

// clint
clint clint0(.bus(dbus_if_clit0), .clk(clk), .irq_sw(irq_sw0), .irq_timer(irq_timer0), .rst_n(rst_n));


//plic plic0(.irq_ext(irq_ext0));

// dual port memory
memory_wrapped mem0(.ibus(ibus_if_mem0), .dbus(dbus_if_mem0), .clk(clk), .rst_n(rst_n));

// rom single port memory
rom_wrapped rom0(.bus(ibus_if_rom0), .clk(clk), .rst_n(rst_n));

// gpio memory mapped
gpio_wrapped gpio0(.bus(dbus_if_gpio0), .clk(clk), .gpio(gpio), .rst_n(rst_n));

// interconnect

dbus_interconnect dbus_ic(.*);
ibus_interconnect ibus_ic(.*);

// Debug Transport and Debug Interface
logic tdo, tdo_en;
logic dmi;

logic [8:0] chain = {rst_n, gpio}; // readonly

dtm_jtag debug_transport(.tdi(dtm_tdi), .trst(dtm_trst), .tms(dtm_tms), .tclk(dtm_tclk), .tdo(tdo), .tdo_en(tdo_en));

TBUF jtag_tdo (
  .I    (tdo),      // Input data
  .O    (dtm_tdo),       // Output data
  .OEN  (!tdo_en) // Active-low output enable
);


endmodule