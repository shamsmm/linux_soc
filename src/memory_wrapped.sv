// 16KB RAM two ports, 1 Read only, other read and write
module memory_wrapped (
    slave_bus_if.slave ibus,
    slave_bus_if.slave dbus,
    input bit clk,
    input bit rst_n
);

bit rerror, rerror2, werror;

enum logic {AD, DO} state, next_state, state2, next_state2;

always_ff @(posedge clk, negedge rst_n)
    if (!rst_n) begin
        state2 <= AD;
    end else begin
        state2 <= next_state2;
    end

always_comb begin
    case(state2)
        AD: next_state2 = ibus.bstart ? DO : AD;
        DO: next_state2 = AD;
    endcase
end

always_comb begin
    ibus.bdone = 0;
    case(state2)
        AD: ibus.bdone = 0;
        DO: ibus.bdone = 1;
    endcase
end

always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
        state <= AD;
    else    
        state <= next_state;

always_comb begin
    case(state)
        AD: next_state = dbus.bstart ? DO : AD;
        DO: next_state = AD;
    endcase
end

always_comb begin
    dbus.bdone = 0;
    case(state)
        AD: dbus.bdone = 0;
        DO: dbus.bdone = 1;
    endcase
end
logic [11:0] ada;
logic [31:0] douta;

always_comb begin
    dbus.rdata = 0;
    rerror = 0;

    case(dbus.tsize)
        WORD: begin
            if (dbus.addr[1:0] == 2'b00)
                dbus.rdata = douta;
            else
                rerror = 1;
        end
        HALFWORD: begin
            if (dbus.addr[0] == 1'b0)
                dbus.rdata = dbus.addr[0] ? {16'b0, douta[15:0]} : {16'b0, douta[31:16]};
            else
                rerror = 1;
        end
        BYTE: begin
            case(dbus.addr[1:0])
                2'b00: dbus.rdata = {24'b0, douta[7:0]};
                2'b01: dbus.rdata = {24'b0, douta[15:8]};
                2'b10: dbus.rdata = {24'b0, douta[23:16]};
                2'b11: dbus.rdata = {24'b0, douta[31:24]};
            endcase
        end
        default: rerror = 1;
    endcase
end

Gowin_DPB wrapped_mem(
    .douta(douta), //output [31:0] douta
    .doutb(ibus.rdata), //output [31:0] doutb
    .clka(clk), //input clka
    .ocea(1'b1), //input ocea
    .cea(dbus.ss), //input cea
    .reseta(1'b0), //input reseta
    .wrea(dbus.ttype == WRITE), //input wrea
    .clkb(clk), //input clkb
    .oceb(1'b1), //input oceb
    .ceb(ibus.ss), //input ceb
    .resetb(1'b0), //input resetb
    .wreb(1'b0), //input wreb
    .ada(dbus.addr[13:2]), //input [11:0] ada
    .dina(dbus.wdata), //input [31:0] dina
    .adb(ibus.addr[13:2]), //input [11:0] adb
    .dinb(32'b0) //input [31:0] dinb
);

endmodule