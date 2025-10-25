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
    output logic [31:0] dbg_rwrdata,

    // Platform 
    output bit ndmreset,

    // System Bus
    master_bus_if.master dbus,

    // reset and clock
    input bit clk,
    input bit rst_n
);

logic [31:0] data0, data1, data2, sbaddress0, sbdata0;
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
typedef enum logic [3:0] {
    AIDLE,
    APARSE,
    ANOTSUPPORTED,
    AREGACCESS,
    AEXECUTING,
    ANOTHALTED,
    AFINISHREGACCESS
} astate_e;

astate_e astate, next_astate;

always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
        astate <= AIDLE;
    else
        astate <= next_astate;

always_comb begin
    dbg_rwrdata = data0; // in Register Access

    case(astate)
        AIDLE: next_astate = dmi_start && dmi_op == 2 && dmi_address == 7'h17 && abstractcs.cmderr == 0 ? APARSE : AIDLE;
        APARSE: next_astate = command.cmdtype == 0 ? (halted ? AREGACCESS : ANOTHALTED) : ANOTSUPPORTED;
        ANOTHALTED: next_astate = AIDLE;
        ANOTSUPPORTED: next_astate = AIDLE;
        AREGACCESS: next_astate = AFINISHREGACCESS;
        AFINISHREGACCESS: next_astate = AIDLE;
        default: next_astate = AIDLE;
    endcase
end

// Register Access
always_comb begin
    if (astate == AREGACCESS || astate == AFINISHREGACCESS)
        dbg_arcc = command.control;
    else
        dbg_arcc = 0;
end
        
logic anyhavereset;

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
    dmstatus.anyhavereset = anyhavereset;
    dmstatus.allhavereset = dmstatus.anyhavereset;

    hartinfo.nscratch = 2;
    hartinfo.dataaccess = 1;
    hartinfo.datasize = 3;
    hartinfo.dataaddr = 0; // Debug data is at 0x00000000

    dmi_data_o_dmcontrol = dmcontrol_t'(dmi_data_o);
    dmi_data_o_abstracts = abstractcs_t'(dmi_data_o);
    dmi_data_o_sbcs = sbcs_t'(dmi_data_o);
end

dmcontrol_t dmi_data_o_dmcontrol;
abstractcs_t dmi_data_o_abstracts;
sbcs_t dmi_data_o_sbcs;

always_ff @(posedge clk, negedge rst_n)
    if (!rst_n) begin
        dmcontrol <= 0;
        resethaltreq <= 0;
        resumereq <= 0;
        haltreq <= 0;
        abstractcs <= {3'h0, 5'd0, 11'h0, 1'b0, 1'h0, 3'h0, 4'h0, 4'h3};
        anyhavereset <= 0;
        sbcs <= {3'd1, 6'b0, 1'b0, 1'b0, 1'b0, 3'd2, 1'b0, 1'b0, 3'b0, 7'd32, 5'b00100};
    end else begin
        // Read registered
        if (dmi_start && dmi_op == 1)
            case(dmi_address)
                7'h04: dmi_data_i = data0;
                7'h05: dmi_data_i = data1;
                7'h06: dmi_data_i = data2;
                7'h10: dmi_data_i = dmcontrol; // 
                7'h11: dmi_data_i = dmstatus; //
                7'h12: dmi_data_i = hartinfo; //
                7'h16: dmi_data_i = abstractcs; //
                7'h38: dmi_data_i = sbcs; //
                7'h39: dmi_data_i = sbaddress0;
                7'h3C: dmi_data_i = sbdata0; // side effects
                default: dmi_data_i = 0; 
            endcase

        // SB
        sbcs.sbbusy <= dbus_state != BIDLE;

        //if (dbus_state == ASBSIZERROR) // OpenOCD should be smart enough
        //    sbcs.sberror <= 4;
        

        if (dbus.bdone && sbcs.sbautoincrement)
            sbaddress0 <= sbaddress0 + 4; // always 32-bit access, so we increment by 4 bytes

        start_dbus_r_transaction <= 0;
        start_dbus_w_transaction <= 0;
        if (sbcs.sberror == 0 && sbcs.sbbusyerror == 0) begin
            if ((dmi_start && dmi_op == 2 && dmi_address == 7'h39 && sbcs.sbreadonaddr) || (dmi_start && dmi_op == 1 && dmi_address == 7'h3C && sbcs.sbreadondata))
                start_dbus_r_transaction <= 1;
            else if (dmi_start && dmi_op == 2 && dmi_address == 7'h3C)
                start_dbus_w_transaction <= 1;
        end

        if (dbus.bdone && dbus_state == BWONGOING)
            sbdata0 <= dbus.rdata;

        // Rest
        if (astate == AFINISHREGACCESS && dbg_arcc.transfer & !dbg_arcc.write) // read from it
            data0 <= dbg_regout;
        
        if (astate != AIDLE && ((dmi_address == 7'h17 || dmi_address == 7'h16 || dmi_address == 7'h18) && dmi_start && dmi_op == 2 || dmi_start && (dmi_address == 7'h04 || dmi_address == 7'h05 || dmi_address == 7'h06)))
            abstractcs.cmderr <= 3'd1;

        if (astate == ANOTSUPPORTED)
            abstractcs.cmderr <= 3'd2;

        if (astate == ANOTHALTED)
            abstractcs.cmderr <= 3'd4;

        if (dmi_start && dmi_op == 2) begin
            case(dmi_address)
                7'h10: begin
                    if (!dmi_data_o_dmcontrol.dmactive) begin // writing 0 always reset the hole thing
                        // reset DM
                        dmcontrol <= 0;
                        resethaltreq <= 0;
                        resumereq <= 0;
                        haltreq <= 0;
                        abstractcs <= {3'h0, 5'd0, 11'h0, 1'b0, 1'h0, 3'h0, 4'h0, 4'h3};
                        sbcs <= {3'd1, 6'b0, 1'b0, 1'b0, 1'b0, 3'd2, 1'b0, 1'b0, 3'b0, 7'd32, 5'b00100};
                    end else begin
                        if (dmi_data_o_dmcontrol.setresethaltreq) begin
                            resethaltreq <= 1;
                        end else if(dmi_data_o_dmcontrol.clrresethaltreq) begin
                            resethaltreq <= 0;
                        end 
                        
                        if (dmi_data_o_dmcontrol.ackhavereset) begin
                            anyhavereset <= 0;
                        end else begin
                            anyhavereset <= dmi_data_o_dmcontrol.ndmreset; // instantaneous reset
                        end

                        if (dmi_data_o_dmcontrol.resumereq & halted) begin
                            haltreq <= 0;
                            resumereq <= 1;
                        end else if (dmi_data_o_dmcontrol.haltreq) begin
                            haltreq <= 1;
                            resumereq <= 0;
                        end

                        dmcontrol.ndmreset <= dmi_data_o_dmcontrol.ndmreset;
                        dmcontrol.dmactive <= dmi_data_o_dmcontrol.dmactive;
                    end
                end
                7'h16: begin
                    if (dmi_data_o_abstracts.cmderr == 3'b111)
                        abstractcs.cmderr <= 0;
                end
                7'h17: command <= dmi_data_o;
                7'h04: data0 <= dmi_data_o;
                7'h05: data1 <= dmi_data_o;
                7'h06: data2 <= dmi_data_o;
                7'h38: begin
                    if (dmi_data_o_sbcs.sberror == 3'b111)
                        sbcs.sberror <= 0;

                    if (dmi_data_o_sbcs.sbbusyerror == 1'b1)
                        sbcs.sbbusyerror <= 0; // TODO: isa OpenOCD is smart enough to not cause this

                    sbcs.sbreadonaddr <= dmi_data_o_sbcs.sbreadonaddr;
                    sbcs.sbaccess <= dmi_data_o_sbcs.sbaccess;
                    sbcs.sbautoincrement <= dmi_data_o_sbcs.sbautoincrement;
                    sbcs.sbreadondata <= dmi_data_o_sbcs.sbreadondata;
                end
                7'h39: sbaddress0 <= dmi_data_o;
                7'h3C: sbdata0 <= dmi_data_o;
            endcase
        end
    end

// D-bus
typedef enum logic [2:0] {BIDLE, BRSTART, BRDELAY, BRONGOING, BWSTART, BWDELAY, BWONGOING} bus_state_e;
bus_state_e dbus_state, next_dbus_state;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        dbus_state <= BIDLE;
    else
        dbus_state <= next_dbus_state;
end

always_comb begin
    dbus.bstart = dbus_state == BRSTART || dbus_state == BWSTART;
end

logic start_dbus_r_transaction, start_dbus_w_transaction; // when sbcs written or read from data0 or written to address0

always_comb begin
    case(dbus_state)
        BIDLE: next_dbus_state =  start_dbus_r_transaction ? BRSTART : start_dbus_w_transaction ? BWSTART : BIDLE;
        BRSTART: next_dbus_state = dbus.bdone ? BRDELAY : BRONGOING;
        BWSTART: next_dbus_state = dbus.bdone ? BWDELAY : BWONGOING;
        BRDELAY: next_dbus_state = BIDLE;
        BWDELAY: next_dbus_state = BIDLE;
        BRONGOING: next_dbus_state = dbus.bdone ? BIDLE : BRONGOING;
        BWONGOING: next_dbus_state = dbus.bdone ? BIDLE : BWONGOING;
    endcase
end

always_comb begin
    dbus.wdata = sbdata0; // always writing from data in register
    // dbus.bstart = ; handle by FSM
    dbus.ttype = (start_dbus_r_transaction | dbus_state inside {BRSTART, BRDELAY, BRONGOING}) ? READ : WRITE; // TODO: better FSM or extra reg handling?
    dbus.breq = dbus.bstart; // TODO: breq and bstart are same? either have clear sepearion in logic or collapse into one
    dbus.addr = sbaddress0;
    dbus.tsize = WORD;
end

endmodule