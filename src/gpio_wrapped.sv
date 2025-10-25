import bus_if_types_pkg::*;

// byte accessed, 4-byte aligned 8-bit gpio
// TODO: interrupts
module gpio_wrapped(slave_bus_if.slave bus, input bit clk, inout [7:0] gpio, input bit rst_n);

genvar i;
generate
  for (i = 0; i < 8; i = i + 1) begin : io_buffer_gen
    IOBUF pin (
      .I    (output_val[i]),      // Input data
      .O    (input_val[i]),       // Output data
      .IO   (gpio[i]),            // Bidirectional pin
      .OEN  (!output_en[i])       // Active-low output enable
    );
  end
endgenerate


logic [7:0] input_val;
logic [7:0] input_en; // compatibility but won't be used
logic [7:0] output_en;
logic [7:0] output_val;

always_comb begin
    bus.bdone = 1'b1; // all thing take one clock cycle
    bus.rdata = 32'b0;

    case(bus.addr[7:0])
        8'h00: bus.rdata = {24'b0, input_val};
        8'h04: bus.rdata = {24'b0, input_en};
        8'h08: bus.rdata = {24'b0, output_en};
        8'h0C: bus.rdata = {24'b0, output_val};
    endcase
end

always_ff @( posedge clk, negedge rst_n ) begin
    if (!rst_n) begin
        input_en <= 8'hFF;
        output_en <= 8'b00;
        output_val <= 8'b00;
    end
    else if (bus.bstart && bus.ss && bus.ttype == WRITE) begin
        case(bus.addr[7:0])
            8'h04: input_en <= bus.wdata[7:0];
            8'h08: output_en <= bus.wdata[7:0];
            8'h0C: output_val <= bus.wdata[7:0];
        endcase
    end
end

endmodule