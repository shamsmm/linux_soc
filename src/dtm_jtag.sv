module dtm_jtag(output logic tdo, tdo_en, input logic tclk, tdi, tms, trst, output logic dmi, input [8:0] chain);

assign tdo_en = (state == SHIFT_IR | state == SHIFT_DR);

typedef enum logic [3:0] {
    TEST_LOGIC_RESET = 4'h0,
    RUN_TEST_IDLE    = 4'h1,
    SELECT_DR_SCAN   = 4'h2,
    CAPTURE_DR       = 4'h3,
    SHIFT_DR         = 4'h4,
    EXIT1_DR         = 4'h5,
    PAUSE_DR         = 4'h6,
    EXIT2_DR         = 4'h7,
    UPDATE_DR        = 4'h8,
    SELECT_IR_SCAN   = 4'h9,
    CAPTURE_IR       = 4'hA,
    SHIFT_IR         = 4'hB,
    EXIT1_IR         = 4'hC,
    PAUSE_IR         = 4'hD,
    EXIT2_IR         = 4'hE,
    UPDATE_IR        = 4'hF
} jtag_state_t;

typedef enum logic [5:0] {
    BYPASS  = 6'b111111,
    SAMPLE  = 6'b000010,
    DMI     = 6'b101010,
    IDCODE  = 6'b000001
} jtag_instruction_t;

jtag_state_t state, next_state;

logic [5:0] ir, instruction;
logic [31:0] dr;
logic [0:0] bypass = 1'b0;

localparam IDCODE_VALUE = {
    4'h1,           // Version
    16'hBEEF,       // Part number 
    11'h000,        // Manufacturer ID
    1'b1            // LSB always 1
};

logic [31:0] idcode = IDCODE_VALUE; // readonly

always_ff @(posedge tclk, negedge trst)
    if (!trst) begin
        instruction <= IDCODE;
    end else begin
        case (state)
            CAPTURE_IR: ir <= 6'b0000_01;
            SHIFT_IR: begin
                ir <= {ir[4:0], tdi};
                tdo <= ir[5];
            end
            UPDATE_IR: instruction <= ir;
            CAPTURE_DR: begin
                case(instruction)
                    IDCODE: dr <= idcode;
                    DMI:    dr <= 0; // TODO: connect to actual DMI
                    BYPASS: dr <= 0;
                endcase
            end
            SHIFT_DR: begin
                dr <= {dr[30:0], tdi};
                tdo <= dr[31];
            end
            UPDATE_DR: begin
                case(instruction)
                    DMI:    dmi <= dr; // TODO: connect to actual DMI
                endcase
            end
        endcase
    end

always_ff @(posedge tclk, negedge trst)
    if (!trst)
        state <= TEST_LOGIC_RESET;
    else
        state <= next_state;

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