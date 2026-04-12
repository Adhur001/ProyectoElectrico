`include "temp_wrapper.sv"

module tester (
    output logic clk,
    output logic [4:0] addr_A,
    output logic [4:0] addr_B,
    output logic [4:0] addr_W,
    output logic [127:0] data_in,
    output logic write,
    output logic sel, enable,
    output logic [2:0] alu_op
);

initial begin

    addr_A = 0; addr_B = 0;
    enable = 0;
    alu_op = 0;
    clk = 1;

    sel = 1; // registers are going to take dummy data

    #10; // begin test 1, write dummy values in registers
    data_in = {4{32'hDEAD_BEEF}};
    addr_W = 5'd1;

    #10 write = 1; // allows for writing

    #10; // write different value in same address
    data_in = {4{32'h0404_9292}};
    addr_W = 5'd1;

    #10; // change the address 
    data_in = {4{32'h0404_9292}};
    addr_W = 5'd2;

    #20 $finish;
end

always begin
    #5 clk = !clk;
end

endmodule


module wrapper_tb ();

    logic clk;
    logic [4:0] addr_A;
    logic [4:0] addr_B;
    logic [4:0] addr_W;
    logic [127:0] data_in;
    logic write;
    logic sel, enable;
    logic [2:0] alu_op;

temp_wrapper test1_DUT (
    .clk(clk),
    .addr_vs1(addr_A),
    .addr_vs2(addr_B),
    .addr_vd(addr_W),
    .dummy_data_in(data_in),
    .wr_en(write),
    .sel(sel),
    .enable_ALU(enable),
    .alu_op(alu_op)
);

tester test1_tester (
    .clk(clk),
    .addr_A(addr_A),
    .addr_B(addr_B),
    .addr_W(addr_W),
    .data_in(data_in),
    .write(write),
    .sel(sel),
    .enable(enable),
    .alu_op(alu_op)
);

initial begin
    $dumpfile("waves.vcd");
    $dumpvars(0,wrapper_tb);
end


endmodule
