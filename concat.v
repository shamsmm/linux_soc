
module concat;

  initial begin
  //$display("Concatenated (hex): %h", {7'h10, 32'h80000000, 2'd2});
    $display("jtag arp_init");
    $display("irscan riscv.tap 0x11");
    $display("Reset DM    : drscan riscv.tap 41 0x%h", {7'h10, 32'h00000000, 2'd2});
    $display("nDM Reset 1 : drscan riscv.tap 41 0x%h", {7'h10, 32'h00000003, 2'd2});
    $display("nDM Reset 0 : drscan riscv.tap 41 0x%h", {7'h10, 32'h00000001, 2'd2});
    $display("Halt        : drscan riscv.tap 41 0x%h", {7'h10, 32'h80000001, 2'd2});
    $display("R DMstatus  : drscan riscv.tap 41 0x%h", {7'h11, 32'h00000000, 2'd1});
    $display("Resume      : drscan riscv.tap 41 0x%h", {7'h10, 32'h40000001, 2'd2});
    $display("R GPR  data0: drscan riscv.tap 41 0x%h", {7'h17, {8'h0, 1'b0, 3'd2, 1'b0, 1'b0, 1'b1, 1'b0, 16'h1000}, 2'd2}); // Read GPR x0
    $display("R CSR  dpc  : drscan riscv.tap 41 0x%h", {7'h17, {8'h0, 1'b0, 3'd2, 1'b0, 1'b0, 1'b1, 1'b0, 16'h07b0}, 2'd2}); // Read CSR dpc
    $display("R data0     : drscan riscv.tap 41 0x%h", {7'h04, 32'h00000000, 2'd1}); // Read GPR x0
    $finish; 
  end

endmodule