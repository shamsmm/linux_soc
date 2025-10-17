module top(
    // system clk and reset
    input bit sysclk,
    input bit sysrst_n,
    
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
//assign clk = sysclk; // 27MHz
logic rst_n;
assign rst_n = !ndmreset & sysrst_n;

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

// plic (D-bus)
slave_bus_if dbus_if_plic0(clk, rst_n);

// clit (D-bus)
slave_bus_if dbus_if_clit0(clk, rst_n);

// riscv32 core-0
logic irq_sw0, irq_ext0, irq_timer0, running, halted, haltreq, resumereq, resethaltreq;

rv_core #(.INITIAL_PC(32'h2000_0000)) core0(
    .ibus(ibus_if_core0),
    .dbus(dbus_if_core0),
    .haltreq(haltreq),
    .resumereq(resumereq),
    .resethaltreq(resethaltreq),
    .clk(clk),
    .rst_n(rst_n),
    .irq_sw(irq_sw0),
    .irq_ext(irq_ext0),
    .irq_timer(irq_timer0),
    .halted(halted),
    .running(running)
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

logic [8:0] chain = {rst_n, gpio}; // readonly

// Debug
// CDC synchronizes needed between JTAG and System clock

bit dmi_start_dtm;
logic [1:0] dmi_op_dtm;
logic [33:2] dmi_data_o_dtm, dmi_data_i_dtm;
logic [7+33:34] dmi_address_dtm;
logic dmi_finish_dtm;
dtm_jtag debug_transport(.tdi(dtm_tdi), .trst(dtm_trst), .tms(dtm_tms), .tclk(dtm_tclk), .tdo(tdo), .tdo_en(tdo_en), .dmi_start(dmi_start_dtm), .dmi_op(dmi_op_dtm), .dmi_data_o(dmi_data_o_dtm), .dmi_address(dmi_address_dtm), .dmi_finish(dmi_finish_dtm), .dmi_data_i(dmi_data_i_dtm));

logic ndmreset;
bit dmi_start_dm;
logic [1:0] dmi_op_dm;
logic [33:2] dmi_data_o_dm, dmi_data_i_dm;
logic [7+33:34] dmi_address_dm;
logic dmi_finish_dm;
dm debug_module(.haltreq(haltreq), .resumereq(resumereq), .resethaltreq(resethaltreq), .halted(halted), .running(running), .clk(clk), .rst_n(rst_n), .ndmreset(ndmreset), .dmi_start(dmi_start_dm), .dmi_op(dmi_op_dm), .dmi_data_o(dmi_data_o_dm), .dmi_address(dmi_address_dm), .dmi_finish(dmi_finish_dm), .dmi_data_i(dmi_data_i_dm));

TBUF jtag_tdo (
  .I    (tdo),      // Input data
  .O    (dtm_tdo),       // Output data
  .OEN  (!tdo_en) // Active-low output enable
);


endmodule