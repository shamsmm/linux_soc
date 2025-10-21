import instructions::*;
// Single hart DM
module dm(
    // DMI trivial bus
    input bit dmi_start, // must be synchronized to this clock domain
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
    output access_register_command_control_t dbg_arcc,
    input logic [31:0] dbg_regout,

    // Platform 
    output bit ndmreset,

    // System Bus

    // reset and clock
    input bit clk,
    input bit rst_n
);

logic [31:0] data0, data1, data2, sbaddress0, sbdata0;
logic [31:0] progbuf [0:4];
dmcontrol_t dmcontrol;
abstractcs_t abstractcs;
hartinfo_t hartinfo;
command_t command;
dmstatus_t dmstatus;
sbcs_t sbcs; // system bus access

// DMI FSM
typedef enum logic [1:0] {
    IDLE,
    EXECUTING,
    FINISH
} state_e;

state_e state, next_state;

// too much but whatever
always_comb begin
    dmi_finish = state == FINISH;
    case(state)
        IDLE: next_state = dmi_start ? EXECUTING : IDLE;
        EXECUTING: next_state = FINISH;
        FINISH: next_state = IDLE;
        default: next_state = IDLE;
    endcase
end

always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
        state <= IDLE;
    else
        state <= next_state;


// abstract FSM
typedef enum logic [2:0] {
    AIDLE,
    APARSE,
    ANOTSUPPORTED,
    AREGACCESS,
    AEXECUTING,
    AFINISH
} astate_e;

astate_e astate, next_astate;

always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
        astate <= AIDLE;
    else
        astate <= next_astate;

always_comb begin
    case(astate)
        AIDLE: next_astate = dmi_start && dmi_op == 2 && dmi_address == 7'h17 ? APARSE : AIDLE;
        APARSE: next_astate = command.cmdtype == 0 ? AREGACCESS : ANOTSUPPORTED;
        ANOTSUPPORTED: next_astate = AIDLE;
        AREGACCESS: next_astate = AFINISH;
        AFINISH: next_astate = AIDLE;
    endcase
end

// Register Access
always_comb begin
    if (astate == AREGACCESS)
        dbg_arcc = command.control;
    else
        dbg_arcc = 0;
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

    hartinfo.nscratch = 2;
    hartinfo.dataaccess = 1;
    hartinfo.datasize = 3;
    hartinfo.dataaddr = 0; // Debug data is at 0x00000000

    dmi_data_o_dmcontrol = dmcontrol_t'(dmi_data_o);
    dmi_data_o_abstracts = abstractcs_t'(dmi_data_o);

    case(dmi_address)
        7'h04: dmi_data_i = data0;
        7'h05: dmi_data_i = data1;
        7'h06: dmi_data_i = data2;
        7'h10: dmi_data_i = dmcontrol; // 
        7'h11: dmi_data_i = dmstatus; //
        7'h12: dmi_data_i = hartinfo; //
        7'h16: dmi_data_i = abstractcs; //
        7'h20: dmi_data_i = progbuf[0];
        7'h21: dmi_data_i = progbuf[1];
        7'h22: dmi_data_i = progbuf[3];
        7'h38: dmi_data_i = sbcs; //
        7'h39: dmi_data_i = sbaddress0;
        7'h3C: dmi_data_i = sbdata0; // side effects
        default: dmi_data_i = 0; 
    endcase
end

dmcontrol_t dmi_data_o_dmcontrol;
abstractcs_t dmi_data_o_abstracts;

always_ff @(posedge clk, negedge rst_n)
    if (!rst_n) begin
        dmcontrol <= 0;
        resethaltreq <= 0;
        resumereq <= 0;
        haltreq <= 0;
        abstractcs <= {3'h0, 5'd3, 11'h0, 1'b0, 1'h0, 3'h0, 4'h0, 4'h3};
    end else begin
        // Register access read into data(0-2)?
        

        if (dmi_start && dmi_op == 2) begin
            case(dmi_address)
                7'h10: begin
                    if (dmi_data_o_dmcontrol.setresethaltreq) begin
                        resethaltreq <= 1;
                    end else if(dmi_data_o_dmcontrol.clrresethaltreq) begin
                        resethaltreq <= 0;
                    end if (dmi_data_o_dmcontrol.resumereq & halted) begin
                        haltreq <= 0;
                        resumereq <= 1;
                    end else if (dmi_data_o_dmcontrol.haltreq) begin
                        haltreq <= 1;
                        resumereq <= 0;
                    end

                    dmcontrol <= dmi_data_o&41'h1; // only ndmreset
                end
                7'h16: begin
                    if (dmi_data_o_abstracts.cmderr == 1)
                        abstractcs.cmderr <= 0;
                end
                7'h17: command <= dmi_data_o;
                7'h04: data0 <= dmi_data_o;
                7'h05: data1 <= dmi_data_o;
                7'h06: data2 <= dmi_data_o;
                7'h20: progbuf[0] <= dmi_data_o;
                7'h21: progbuf[1] <= dmi_data_o;
                7'h22: progbuf[3] <= dmi_data_o;
            endcase
        end
    end

endmodule