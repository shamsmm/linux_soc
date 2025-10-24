module dtm_jtag(
    // JTAG signals
    output logic tdo,
    output logic tdo_en,
    input  logic tclk, // TCLK
    input  logic tdi,
    input  logic tms,
    input  logic trst,

    // DMI trivial bus
    output bit dmi_start,
    input bit dmi_finish,
    output logic [1:0] dmi_op,
    output logic [33:2] dmi_data_o,
    input logic [33:2] dmi_data_i,
    output logic [7+33:34] dmi_address,
    
    // clock and reset
    input bit clk,
    input bit rst_n
);

import jtag::*;

logic [5:0] ir_shift;
logic [7+33:0] dr;
logic [0:0] bypass;

localparam int unsigned IDCODE_VALUE = 32'h1BEEF001;

typedef enum logic [5:0] {
    BYPASS  = 6'h00,
    IDCODE  = 6'h01,
    DTM     = 6'h10,
    DMI     = 6'h11
} jtag_instruction_t;

typedef enum logic [11:10] {
    NOERROR = 0,
    RESERVED = 1,
    FAILED = 2,
    STILL_IN_PROGRESS = 3
} dmistat_e;

typedef struct packed {
    logic [31:18] _31_18;
    logic dmihardreset;
    logic dmireset;
    logic _15;
    logic [14:12] idle;
    dmistat_e dmistat;
    logic [9:4] abits;
    logic [3:0] version;
} dtmcs_t;

typedef struct packed {
    //logic [1:0] op; // leave it to other variables
    logic [33:2] data;
    logic [7+33:34] address;
} dmi_without_op_t;  

typedef enum logic [1:0] {
    IDLE,
    START,
    EXECUTING,
    FINISH
} fsm_state_e;

fsm_state_e fsm_state, next_fsm_state;
logic [1:0] fsm_state_ff2, next_fsm_state_ff2;
`define VERILATOR
`ifdef VERILATOR
// Simulation-only double flip-flop synchronizer (clk -> tclk)
reg [1:0] fsm_state_ff1;

always @(posedge tclk) begin
    fsm_state_ff1 <= fsm_state;     // First sync stage
    fsm_state_ff2 <= fsm_state_ff1; // Second sync stage
end
`else
// Real hardware FIFO instance for CDC
FIFO_HS_Top fsm_state_cdc(
    .Data(fsm_state),
    .WrClk(clk),
    .RdClk(tclk),
    .WrEn(1'b1),
    .RdEn(1'b1),
    .Almost_Empty(),
    .Almost_Full(),
    .Q(fsm_state_ff2),
    .Empty(),
    .Full()
);
`endif

struct packed {jtag_state_t state; logic[5:0] ir; logic [1:0] dmiop; logic dmihardreset;} tclk_signals, tclk_signals_ff2;

always_comb tclk_signals = {state, ir, dr[1:0], dr[17]};

always_comb begin
    dmi_start = fsm_state == START;

    case(fsm_state)
        IDLE: next_fsm_state = (tclk_signals_ff2.state == UPDATE_DR && tclk_signals_ff2.ir == DMI && (tclk_signals_ff2.dmiop == 2'd1 || tclk_signals_ff2.dmiop == 2'd2)) ? START : IDLE;
        START: next_fsm_state = EXECUTING;
        EXECUTING: next_fsm_state = dmi_finish ? FINISH : EXECUTING;
        FINISH: next_fsm_state = tclk_signals_ff2.state != UPDATE_DR ? IDLE : FINISH;
        default: next_fsm_state = IDLE;
    endcase    
end

always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
        fsm_state <= IDLE;
    end else begin
        if (tclk_signals_ff2.state == UPDATE_DR && tclk_signals_ff2.ir == DTM && tclk_signals_ff2.dmihardreset)
            fsm_state <= IDLE;
        else
            fsm_state <= next_fsm_state;
    end
end

`ifdef VERILATOR
// Define internal synchronization registers
struct packed {jtag_state_t state; logic[5:0] ir; logic [1:0] dmiop; logic dmihardreset;} tclk_signals_ff1; //4+6+2+1 13 bits to cross domain

always @(posedge clk) begin
    tclk_signals_ff1 <= tclk_signals;     // First stage sync
    tclk_signals_ff2 <= tclk_signals_ff1; // Second stage sync
end
`else
// Actual hardware FIFO instance for CDC
FIFO_HS_Top next_fsm_state_cdc(
    .Data({tclk_signals.state, tclk_signals.ir, tclk_signals.dmiop, tclk_signals.dmihardreset}),
    .WrClk(tclk),
    .RdClk(clk),
    .WrEn(1'b1),
    .RdEn(1'b1),
    .Almost_Empty(),
    .Almost_Full(),
    .Q(tclk_signals_ff2),
    .Empty(),
    .Full()
);
`endif

jtag_state_t state, next_state;
jtag_instruction_t ir;
dtmcs_t dtmcs;

assign tdo_en = (state == SHIFT_DR || state == SHIFT_IR);

always_ff @(negedge tclk, negedge trst)
    if (!trst)
        tdo <= 0;
    else
        case (state)
            TEST_LOGIC_RESET: tdo <= 0;
            SHIFT_IR: tdo <= ir_shift[0];
            SHIFT_DR: begin
                case(ir)
                    IDCODE, DTM, DMI: begin
                        tdo <= dr[0];
                    end
                    BYPASS: begin
                        tdo <= bypass;
                    end
                endcase
            end
        endcase

logic [40:0] dr_ff1, dr_ff2;

always @(posedge clk) begin
    dr_ff1 <= dr;     // First sync stage
    dr_ff2 <= dr_ff1; // Second sync stage
end

always_comb {dmi_address, dmi_data_o, dmi_op} = dr_ff2;

logic [33:2] dmi_data_last_trn;
always_ff @(posedge clk) begin
    if (dmi_finish)
        dmi_data_last_trn <= dmi_data_i;
end

always_ff @(negedge tclk, negedge trst)
    if (!trst) begin
        ir <= IDCODE;
        dtmcs.version <= 1;
        dtmcs.abits <= 7;
        //dtmcs.dmistat <= NOERROR;
        dtmcs.idle <= 3; // Wait a lot
    end else
        case(state)
            TEST_LOGIC_RESET: ir <= IDCODE;
            UPDATE_IR: ir <= jtag_instruction_t'(ir_shift);
            UPDATE_DR: case(ir)
                //DTM: dtmcs[17:16] <= dr[17:16]; // only writable fields
                //DMI: {dmi_address, dmi_data_o, dmi_op} <= dr; // another fsm starts the transaction // always update dmi
                default:;
            endcase
        endcase

dmistat_e dmistat;
always_ff @(posedge tclk, negedge trst)
    if (!trst)
        dmistat <= NOERROR;
    else
        if (state == UPDATE_DR && ir == DTM && (dr[17:16] != 0)) // dmireset or dmihardreset
            dmistat <= NOERROR;
        else if (dmistat != 0) // first error only (sticky)
            if (state == CAPTURE_DR && ir == DMI)
                dmistat <= dmi_error;

dmistat_e dmi_error;
always_comb dmi_error = fsm_state_e'(fsm_state_ff2) == IDLE ? NOERROR : STILL_IN_PROGRESS;

always_ff @(posedge tclk or negedge trst) begin
    if (!trst) begin
        dr <= {9'b0, IDCODE_VALUE};
        bypass <= 0;
    end else begin
        case (state)
            TEST_LOGIC_RESET: begin
                dr <= {9'b0, IDCODE_VALUE};
                bypass <= 0;
            end
            CAPTURE_IR: ir_shift <= 6'b0000_01;
            SHIFT_IR: begin
                ir_shift <= {tdi, ir_shift[5:1]};
            end
            CAPTURE_DR: begin
                case(ir)
                    IDCODE: dr <= {9'b0, IDCODE_VALUE};
                    DTM: dr <= {9'b0, {dtmcs[31:12], dmistat, dtmcs[9:0]}};
                    DMI: dr <= {dmi_address, dmi_data_last_trn, dmi_error};
                    BYPASS: bypass <= 0;
                    default: bypass <= 0;
                endcase
            end
            SHIFT_DR: begin
                case(ir)
                    IDCODE, DTM: begin
                        dr <= {9'b0, tdi, dr[31:1]};
                    end
                    DMI: begin
                        dr <= {tdi, dr[7+33:1]};
                    end
                    BYPASS: begin
                        bypass <= tdi;
                    end
                    default: bypass <= tdi; // Default to BYPASS
                endcase
            end
        endcase
    end
end

always_ff @(posedge tclk or negedge trst) begin
    if (!trst) begin
        state <= TEST_LOGIC_RESET;
    end else begin
        state <= next_state;
    end
end

always_comb begin
    unique case(state)
        TEST_LOGIC_RESET: next_state = tms ? TEST_LOGIC_RESET : RUN_TEST_IDLE;
        RUN_TEST_IDLE:    next_state = tms ? SELECT_DR_SCAN : RUN_TEST_IDLE;
        SELECT_DR_SCAN:   next_state = tms ? SELECT_IR_SCAN : CAPTURE_DR;
        CAPTURE_DR:       next_state = tms ? EXIT1_DR : SHIFT_DR;
        SHIFT_DR:         next_state = tms ? EXIT1_DR : SHIFT_DR;
        EXIT1_DR:         next_state = tms ? UPDATE_DR : PAUSE_DR;
        PAUSE_DR:         next_state = tms ? EXIT2_DR : PAUSE_DR;
        EXIT2_DR:         next_state = tms ? UPDATE_DR : SHIFT_DR;
        UPDATE_DR:        next_state = tms ? SELECT_DR_SCAN : RUN_TEST_IDLE;
        SELECT_IR_SCAN:   next_state = tms ? TEST_LOGIC_RESET : CAPTURE_IR;
        CAPTURE_IR:       next_state = tms ? EXIT1_IR : SHIFT_IR;
        SHIFT_IR:         next_state = tms ? EXIT1_IR : SHIFT_IR;
        EXIT1_IR:         next_state = tms ? UPDATE_IR : PAUSE_IR;
        PAUSE_IR:         next_state = tms ? EXIT2_IR : PAUSE_IR;
        EXIT2_IR:         next_state = tms ? UPDATE_IR : SHIFT_IR;
        UPDATE_IR:        next_state = tms ? SELECT_DR_SCAN : RUN_TEST_IDLE;
        default:          next_state = TEST_LOGIC_RESET;
    endcase
end

endmodule