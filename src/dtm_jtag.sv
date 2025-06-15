module dtm_jtag(output logic tdo, tdo_en, input logic tclk, tdi, tms, trst);

assign tdo_en = (state inside {SHIFT_IR, SHIFT_DR, EXIT1_IR, EXIT1_DR});
logic next_tdo;

typedef enum logic [3:0] {
    TEST_LOGIC_RESET,
    RUN_TEST_IDLE,
    SELECT_DR_SCAN,
    CAPTURE_DR,
    SHIFT_DR,
    EXIT1_DR,
    PAUSE_DR,
    EXIT2_DR,
    UPDATE_DR,
    SELECT_IR_SCAN,
    CAPTURE_IR,
    SHIFT_IR,
    EXIT1_IR,
    PAUSE_IR,
    EXIT2_IR,
    UPDATE_IR
} jtag_state_t;

typedef enum logic [5:0] {
    BYPASS  = 6'b111111,
    SAMPLE  = 6'h000000,
    DMI     = 6'b100001,
    IDCODE  = 6'b000001
} jtag_instruction_t;

jtag_state_t state, next_state;

jtag_instruction_t ir;

logic [5:0] ir_shift;
logic [31:0] dr;
logic [0:0] bypass;

localparam IDCODE_VALUE = 32'h1BEEF001;

always_ff @(negedge tclk, negedge trst)
    if (!trst) begin
        tdo <= 0;
        ir <= IDCODE;
    end else begin
        tdo <= next_tdo;

        if (state == UPDATE_IR)
            ir <= jtag_instruction_t'(ir_shift);
    end

always_ff @(posedge tclk, negedge trst)
    if (!trst) begin
        dr <= IDCODE_VALUE;
        next_tdo <= 0;
        bypass <= 0;
    end else begin
        case (next_state)
            TEST_LOGIC_RESET: begin
                dr <= IDCODE_VALUE;
                next_tdo <= 0;
                bypass <= 0;
            end
            CAPTURE_IR: ir_shift <= 6'b0000_01;
            SHIFT_IR: begin
                next_tdo <= ir_shift[0];
                ir_shift <= {tdi, ir_shift[5:1]};
            end
            CAPTURE_DR: begin
                case(ir)
                    IDCODE: dr <= IDCODE_VALUE;
                    SAMPLE: dr <= 32'h55555555; // TODO: connect to actual GPIO
                endcase
            end
            SHIFT_DR: begin
                case(ir)
                    IDCODE: begin
                        next_tdo <= dr[0];
                        dr <= {tdi, dr[31:1]};
                    end
                    SAMPLE: begin
                        next_tdo <= dr[0];
                        dr <= {tdi, dr[31:1]};
                    end
                    BYPASS: begin
                        next_tdo <= bypass;
                        bypass <= tdi;
                    end
                endcase
            end
            UPDATE_DR: begin
            end
        endcase
    end

logic tms_s; // sample as FSM next state is combinational logic

always_ff @(posedge tclk, negedge trst)
    if (!trst) begin
        state <= TEST_LOGIC_RESET;
        tms_s <= 1'b1;
    end else begin
        state <= next_state;
        tms_s <= tms;
    end

always_comb
    case(state)
        TEST_LOGIC_RESET:
            next_state = tms ? TEST_LOGIC_RESET : RUN_TEST_IDLE;
        RUN_TEST_IDLE:
            next_state = tms ? SELECT_DR_SCAN : RUN_TEST_IDLE;
        SELECT_DR_SCAN:
            next_state = tms ? SELECT_IR_SCAN : CAPTURE_DR;
        CAPTURE_DR:
            next_state = tms ? EXIT1_DR : SHIFT_DR;
        SHIFT_DR:
            next_state = tms ? EXIT1_DR : SHIFT_DR;
        EXIT1_DR:
            next_state = tms ? UPDATE_DR : PAUSE_DR;
        PAUSE_DR:
            next_state = tms ? EXIT2_DR : PAUSE_DR;
        EXIT2_DR:
            next_state = tms ? UPDATE_DR : SHIFT_DR;
        UPDATE_DR:
            next_state = tms ? SELECT_DR_SCAN : RUN_TEST_IDLE;
        SELECT_IR_SCAN:
            next_state = tms ? TEST_LOGIC_RESET : CAPTURE_IR;
        CAPTURE_IR:
            next_state = tms ? EXIT1_IR : SHIFT_IR;
        SHIFT_IR:
            next_state = tms ? EXIT1_IR : SHIFT_IR;
        EXIT1_IR:
            next_state = tms ? UPDATE_IR : PAUSE_IR;
        PAUSE_IR:
            next_state = tms ? EXIT2_IR : PAUSE_IR;
        EXIT2_IR:
            next_state = tms ? UPDATE_IR : SHIFT_IR;
        UPDATE_IR:
            next_state = tms ? SELECT_DR_SCAN : RUN_TEST_IDLE;
        default:
            next_state = TEST_LOGIC_RESET;
    endcase

endmodule