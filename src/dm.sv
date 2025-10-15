// Single hart DM
module dm(
    // DMI trivial bus
    input bit dmi_start,
    output bit dmi_finish,
    input logic [1:0] dmi_op,
    input logic [33:2] dmi_data_o,
    output logic [33:2] dmi_data_i,
    input logic [7+33:34] dmi_address,

    // RV-core
    output bit haltreq,
    output bit resumereq,
    output bit resethaltreq,
    input bit halted,
    input bit running,

    // abstract command

    // Platform 
    output bit ndmreset,

    // System Bus

    // reset and clock
    input bit clk,
    input bit rst_n
);

import instructions::*;

logic [31:0] data0, data1, data2, sbaddress0, sbdata0;
dmcontrol_t dmcontrol;
abstractcs_t abstractcs;
command_t command;
dmstatus_t dmstatus;
sbcs_t sbcs; // system bus access

// DMI FSM
typedef enum logic [1:0] {
    IDLE,
    EXECUTING,
    FINALIZING
} state_e;

state_e state, next_state;

// too much but whatever
always_comb begin
    case(state)
        IDLE: next_state = dmi_start ? EXECUTING : IDLE;
        EXECUTING: next_state = FINALIZING;
        FINALIZING: next_state = IDLE;
    endcase

    dmi_finish = state == FINALIZING;
end

always_comb begin
    ndmreset = dmcontrol.ndmreset;

    dmstatus = '0;
    dmstatus.version = 2;
    dmstatus.hasresethaltreq = 1;
    dmstatus.authenticated = 1;
    dmstatus.anyhalted = halted;
    dmstatus.allhalted = dmstatus.anyhalted; // only single hart
    dmstatus.anyrunning = running;
    dmstatus.allrunning = dmstatus.anyrunning; // only single hart
    dmstatus.anyresumeack = running; // hack?
    dmstatus.allresumeack = dmstatus.anyresumeack;
    dmstatus.anyhavereset = running; // hack?
    dmstatus.allhavereset = dmstatus.anyhavereset;

    dmi_data_o_dmcontrol = dmcontrol_t'(dmi_data_o);

    case(dmi_address)
        7'h04: dmi_data_i = data0;
        7'h05: dmi_data_i = data1;
        7'h06: dmi_data_i = data2;
        7'h10: dmi_data_i = dmcontrol; // 
        7'h11: dmi_data_i = dmstatus; //
        7'h38: dmi_data_i = sbcs; //
        7'h39: dmi_data_i = sbaddress0;
        7'h3C: dmi_data_i = sbdata0; // side effects
        default: dmi_data_i = 0; 
    endcase
end

dmcontrol_t dmi_data_o_dmcontrol;

always_ff @(posedge clk, negedge rst_n)
    if (!rst_n) begin
        dmcontrol <= 0;
        resethaltreq <= 0;
        resumereq <= 0;
        haltreq <= 0;
    end else begin
        if (dmi_start && dmi_op == 2) begin
            case(dmi_address)
                7'h10: begin
                    if (dmi_data_o_dmcontrol.setresethaltreq)
                        resethaltreq <= 1;
                    else if(dmi_data_o_dmcontrol.clrresethaltreq)
                        resethaltreq <= 0;

                    if (dmi_data_o_dmcontrol.resumereq & halted) begin
                        resumereq <= 1;
                    end else if (dmi_data_o_dmcontrol.haltreq) begin
                        haltreq <= 1;
                        resumereq <= 0;
                    end

                    dmcontrol <= dmi_data_o;
                end
            endcase
        end
    end

endmodule