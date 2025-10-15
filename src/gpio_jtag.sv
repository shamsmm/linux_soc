module gpio_jtag(
    // JTAG signals
    output logic tdo,
    output logic tdo_en,
    input  logic tclk, // TCLK
    input  logic tdi,
    input  logic tms,
    input  logic trst,

    // GPIO value
    
);

import jtag::*;

logic [5:0] ir_shift;
logic [31:0] dr;
logic [0:0] bypass;

localparam int unsigned IDCODE_VALUE = 32'h1BEEF002;

typedef enum logic [5:0] {
    BYPASS  = 6'h00,
    IDCODE  = 6'h01,
    SAMPLE  = 6'hFF
} jtag_instruction_t;

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
                    IDCODE, SAMPLE: begin
                        tdo <= dr[0];
                    end
                    BYPASS: begin
                        tdo <= bypass;
                    end
                endcase
            end
        endcase

always_ff @(negedge tclk, negedge trst)
    if (!trst)
        ir <= IDCODE;
    else
        case(state)
            TEST_LOGIC_RESET: ir <= IDCODE;
            UPDATE_IR: ir <= jtag_instruction_t'(ir_shift);
            UPDATE_DR: case(ir)
            endcase
        endcase

always_ff @(posedge tclk or negedge trst) begin
    if (!trst) begin
        dr <= IDCODE_VALUE;
        bypass <= 0;
    end else begin
        case (state)
            TEST_LOGIC_RESET: begin
                dr <= IDCODE_VALUE;
                bypass <= 0;
            end
            CAPTURE_IR: ir_shift <= 6'b0000_01;
            SHIFT_IR: begin
                ir_shift <= {tdi, ir_shift[5:1]};
            end
            CAPTURE_DR: begin
                case(ir)
                    IDCODE: dr <= IDCODE_VALUE;
                    SAMPLE: dr <= 32'h55555555;
                    BYPASS: bypass <= 0;
                    default: bypass <= 0;
                endcase
            end
            SHIFT_DR: begin
                case(ir)
                    IDCODE, SAMPLE: begin
                        dr <= {tdi, dr[31:1]};
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