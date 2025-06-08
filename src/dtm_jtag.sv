module dtm_jtag(output logic tdo, tdo_en, input logic tclk, tdi, tms, trst);

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
    SAMPLE  = 6'h3A, 
    IDCODE  = 6'b000001
} jtag_instruction_t;

jtag_state_t state, next_state;

logic [5:0] ir_shift, ir;
logic [31:0] dr;
logic [0:0] bypass;

localparam IDCODE_VALUE = 32'h1BEEF001;

logic tdo_next_bit;

always_comb begin
    tdo_next_bit = 1'b0; // Default to 0
    tdo_en = 1'b0;       // Default to TDO not enabled

    case(state)
        SHIFT_DR: begin
            tdo_en = 1'b1;
            case(ir)
                IDCODE: tdo_next_bit = dr[0];
                SAMPLE: tdo_next_bit = dr[0];
                BYPASS: tdo_next_bit = bypass;
                // Add other DRs based on instruction as needed
                default: tdo_next_bit = bypass; // Default to bypass if unknown instruction
            endcase
        end
        SHIFT_IR: begin
            tdo_en = 1'b1;
            tdo_next_bit = ir[0];
        end
        default: begin
            tdo_en = 1'b0; // TDO tri-stated or driven low when not shifting
            tdo_next_bit = 1'b0; // Should be don't care, but set to 0
        end
    endcase
end

always_ff @(negedge tclk or negedge trst) begin
    if (!trst) begin
        tdo <= 1'b0; // TDO should be tri-stated or driven low on reset
    end else begin
        tdo <= tdo_next_bit;
    end
end

always_ff @(posedge tclk, negedge trst)
    if (!trst) begin
        state <= TEST_LOGIC_RESET;
        dr <= IDCODE_VALUE;
        bypass <= 0;
        ir <= IDCODE;
        ir_shift <= 0;
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
                case(ir)
                    IDCODE: dr <= IDCODE_VALUE;
                    SAMPLE: dr <= 32'h12345678;
                    BYPASS: bypass <= 1'b0;
                endcase
            end
            SHIFT_DR: begin
                state <= tms ? EXIT1_DR : SHIFT_DR;

                case(ir)
                    IDCODE: begin 
                        dr <= {tdi, dr[31:1]};
                    end
                    SAMPLE: begin
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
                ir_shift <= 6'b0000_01;
            end
            SHIFT_IR: begin
                state <= tms ? EXIT1_IR : SHIFT_IR;
                ir_shift <= {tdi, ir_shift[5:1]};
            end
            EXIT1_IR: 
                state <= tms ? UPDATE_IR : PAUSE_IR;
            PAUSE_IR: 
                state <= tms ? EXIT2_IR : PAUSE_IR;
            EXIT2_IR: 
                state <= tms ? UPDATE_IR : SHIFT_IR;
            UPDATE_IR: begin
                state <= tms ? SELECT_DR_SCAN : RUN_TEST_IDLE;
                ir <= ir_shift;
            end
            default: 
                state <= TEST_LOGIC_RESET;
        endcase

endmodule