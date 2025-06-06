// 4KB ROM
module rom_wrapped (
    slave_bus_if.slave bus,
    input bit clk,
    input bit rst_n
);

enum logic {AD, DO} state, next_state;

always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
        state <= AD;
    else    
        state <= next_state;

always_comb begin
    case(state)
        AD: next_state = bus.bstart ? DO : AD;
        DO: next_state = AD;
    endcase
end

always_comb begin
    bus.bdone = 0;
    case(state)
        AD: bus.bdone = 0;
        DO: bus.bdone = 1;
    endcase
end

Gowin_pROM wrapped_mem(
    .dout(bus.rdata), //output [31:0] dout
    .clk(clk), //input clk
    .oce(1'b0), //input oce
    .ce(1'b1), //input ce
    .reset(1'b0), //input reset
    .ad(bus.addr[11:2]) //input [9:0] ad
);

endmodule