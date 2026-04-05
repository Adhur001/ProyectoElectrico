`include "temp_wrapper.sv"

module tester (
    output logic clk,
    output logic [4:0] addr_vs1,
    output logic [4:0] addr_vs2,
    output logic [4:0] addr_vd,
    output logic [127:0] dummy_data_in,
    output logic wr_en,
    output logic sel,enable_ALU
);

initial begin

    addr_vs1 = 0; addr_vs2 = 0;
    enable_ALU = 0;
    clk = 1;

    sel = 1; // registers are going to take dummy data

    #10; // begin test 1, write dummy values in registers
    dummy_data_in = {4{32'hDEAD_BEEF}};
    addr_vd = 5'd1;

    #10 wr_en = 1; // allows for writing

    #10; // write different value in same address
    dummy_data_in = {4{32'h0404_9292}};
    addr_vd = 5'd1;

    #10; // change the address 
    dummy_data_in = {4{32'h0404_9292}};
    addr_vd = 5'd2;

    #20 $finish;
end

always begin
    #5 clk = !clk;
end

endmodule


module wrapper_tb ();

    logic clk;
    logic [4:0] addr_vs1;
    logic [4:0] addr_vs2;
    logic [4:0] addr_vd;
    logic [127:0] dummy_data_in;
    logic wr_en;
    logic sel,enable_ALU;

temp_wrapper test1_DUT (
    .clk(clk),
    .addr_vs1(addr_vs1),
    .addr_vs2(addr_vs2),
    .addr_vd(addr_vd),
    .dummy_data_in(dummy_data_in),
    .wr_en(wr_en),
    .sel(sel),
    .enable_ALU(enable_ALU)
);

tester test1_tester (
    .clk(clk),
    .addr_vs1(addr_vs1),
    .addr_vs2(addr_vs2),
    .addr_vd(addr_vd),
    .dummy_data_in(dummy_data_in),
    .wr_en(wr_en),
    .sel(sel),
    .enable_ALU(enable_ALU)
);

initial begin
    $dumpfile("waves.vcd");
    $dumpvars(0,wrapper_tb);
end


endmodule
