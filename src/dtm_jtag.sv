module dtm_jtag(output logic tdo, tdo_en, input logic tclk, tdi, tms, trst);

assign tdo_en = (state inside {SHIFT_IR, SHIFT_DR, EXIT1_IR, EXIT1_DR});
logic next_tdo;

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
    IDCODE  = 6'b000001
} jtag_instruction_t;

jtag_state_t state, next_state;

logic [5:0] ir, instruction;
logic [31:0] dr;
logic [0:0] bypass;

localparam IDCODE_VALUE = 32'h1BEEF001;

always_ff @(negedge tclk, negedge trst)
    if (!trst) begin
        tdo <= 0;
        instruction <= IDCODE;
    end else begin
        if(state == SHIFT_DR)
            case(instruction)
                IDCODE: begin 
                    tdo <= dr[0];
                end
                BYPASS: begin 
                    tdo <= bypass;
                end
            endcase
        else if (state == SHIFT_IR)
            tdo <= ir[0];
        else if (state == UPDATE_IR)
            instruction <= ir;
    end

always_ff @(posedge tclk, negedge trst)
    if (!trst) begin
        state <= TEST_LOGIC_RESET;
        dr <= IDCODE_VALUE;
        bypass <= 0;
    end else
        case(state)
            TEST_LOGIC_RESET: begin
                state <= tms ? TEST_LOGIC_RESET : RUN_TEST_IDLE;            
                dr <= IDCODE_VALUE;
                bypass <= 0;
            end
            RUN_TEST_IDLE: 
                state <= tms ? SELECT_DR_SCAN : RUN_TEST_IDLE;            
            SELECT_DR_SCAN: 
                state <= tms ? SELECT_IR_SCAN : CAPTURE_DR;         
            CAPTURE_DR: begin
                state <= tms ? EXIT1_DR : SHIFT_DR;     
                case(instruction)
                    IDCODE: dr <= IDCODE_VALUE;
                endcase
            end
            SHIFT_DR: begin
                state <= tms ? EXIT1_DR : SHIFT_DR;

                case(instruction)
                    IDCODE: begin 
                        dr <= {tdi, dr[31:1]};
                    end
                    BYPASS: begin 
                        bypass <= tdi;
                    end
                endcase
            end
            EXIT1_DR: 
                state <= tms ? UPDATE_DR : PAUSE_DR;            
            PAUSE_DR: 
                state <= tms ? EXIT2_DR : PAUSE_DR;
            EXIT2_DR: 
                state <= tms ? UPDATE_DR : SHIFT_DR;
            UPDATE_DR: 
                state <= tms ? SELECT_DR_SCAN : RUN_TEST_IDLE;
            SELECT_IR_SCAN: 
                state <= tms ? TEST_LOGIC_RESET : CAPTURE_IR;
            CAPTURE_IR: begin
                state <= tms ? EXIT1_IR : SHIFT_IR;
                ir <= 6'b0000_01;
            end
            SHIFT_IR: begin
                state <= tms ? EXIT1_IR : SHIFT_IR;
                ir <= {tdi, ir[5:1]};
            end
            EXIT1_IR: 
                state <= tms ? UPDATE_IR : PAUSE_IR;
            PAUSE_IR: 
                state <= tms ? EXIT2_IR : PAUSE_IR;
            EXIT2_IR: 
                state <= tms ? UPDATE_IR : SHIFT_IR;
            UPDATE_IR: 
                state <= tms ? SELECT_DR_SCAN : RUN_TEST_IDLE;
            default: 
                state <= TEST_LOGIC_RESET;
        endcase

endmodule