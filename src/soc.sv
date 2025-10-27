module soc #(parameter string CDC = "REG") (
    input clk, sysrst_n, rst_n,
    output tdo,
    output tdo_en,
    input tclk, tdi, tms, trst,
    inout [7:0] gpio,
    output ndmreset
);

// riscv32 core-0 master interfaces to I-bus and D-bus
master_bus_if dbus_if_core0(clk, rst_n);
master_bus_if dbus_if_dm0(clk, rst_n);
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
logic irq_sw0, irq_timer0, running, halted, haltreq, resumereq, resethaltreq, reset, resumeack;

// debug signals
access_register_command_control_t dbg_arcc;
logic [31:0] dbg_rwrdata;
logic [31:0] dbg_regout;
rv_core #(.INITIAL_PC(32'h2000_0000)) core0(.dbg_arcc(dbg_arcc), .dbg_rwrdata(dbg_rwrdata), .dbg_regout(dbg_regout), .haltreq(haltreq), .resumereq(resumereq), .resethaltreq(resethaltreq), .ibus(ibus_if_core0), .dbus(dbus_if_core0), .clk(clk), .rst_n(rst_n), .irq_sw(irq_sw0), .irq_timer(irq_timer0), .halted(halted), .running(running), .reset(reset), .resumeack(resumeack));

// dual port memory
memory_wrapped mem0(.ibus(ibus_if_mem0), .dbus(dbus_if_mem0), .clk(clk), .rst_n(rst_n));

// rom single port memory
rom_wrapped rom0(.bus(ibus_if_rom0), .clk(clk), .rst_n(rst_n));

// gpio memory mapped
gpio_wrapped gpio0(.bus(dbus_if_gpio0), .gpio(gpio), .clk(clk), .rst_n(rst_n));

// clint
clint clint0(.bus(dbus_if_clit0), .clk(clk), .irq_sw(irq_sw0), .irq_timer(irq_timer0), .rst_n(rst_n));

// interconnect

dbus_interconnect dbus_ic(.*);
ibus_interconnect ibus_ic(.*);

// Debug

bit dmi_start;
logic [1:0] dmi_op;
logic [33:2] dmi_data_o, dmi_data_i;
logic [7+33:34] dmi_address;
logic dmi_finish;
dtm_jtag #(CDC) debug_transport(.tdi(tdi), .trst(trst), .tms(tms), .tclk(tclk), .tdo(tdo), .tdo_en(tdo_en), .dmi_start(dmi_start), .dmi_op(dmi_op), .dmi_data_o(dmi_data_o), .dmi_address(dmi_address), .dmi_finish(dmi_finish), .dmi_data_i(dmi_data_i), .clk(clk), .rst_n(sysrst_n));

dm debug_module(.dbus(dbus_if_dm0), .dbg_arcc(dbg_arcc), .dbg_rwrdata(dbg_rwrdata), .dbg_regout(dbg_regout), .haltreq(haltreq), .resumereq(resumereq), .resethaltreq(resethaltreq), .halted(halted), .running(running), .clk(clk), .rst_n(sysrst_n), .ndmreset(ndmreset), .dmi_start(dmi_start), .dmi_op(dmi_op), .dmi_data_o(dmi_data_o), .dmi_address(dmi_address), .dmi_finish(dmi_finish), .dmi_data_i(dmi_data_i), .reset(reset), .resumeack(resumeack));


endmodule