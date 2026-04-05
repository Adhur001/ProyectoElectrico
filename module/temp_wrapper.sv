`include "ALU/ALU.sv"
`include "Vregisters/vregisters.sv"

// The idea is to write dummy values in the vregisters and pass them to the ALU
module temp_wrapper (
    input logic clk,
    input logic [4:0] addr_vs1,
    input logic [4:0] addr_vs2,
    input logic [4:0] addr_vd,
    input logic [127:0] dummy_data_in,
    input logic wr_en,
    input logic sel,enable_ALU
);

logic [127:0] vs1_data, vs2_data, vd_data_wb, data_selected;

assign data_selected = (sel) ? dummy_data_in : vd_data_wb;

vregisters Vregs (
    .clk (clk),
    .write (wr_en),
    .addr_A (addr_vs1),
    .addr_B (addr_vs2),
    .addr_W (addr_vd),
    .data_in(data_selected),
    .data_A (vs1_data),
    .data_B (vs2_data)
);

// ahora tenemos que dividir vs1_data para alimentar el
// el ALU array y crear Vouts para dividir vd_data
logic [31:0] vs1_data1, vs1_data2, vs1_data3, vs1_data4;
logic [31:0] vs2_data1, vs2_data2, vs2_data3, vs2_data4;
logic [31:0] vd_data1, vd_data2, vd_data3, vd_data4;

assign vs1_data1 = vs1_data[127:96];
assign vs1_data2 = vs1_data[95:64];
assign vs1_data3 = vs1_data[63:32];
assign vs1_data4 = vs1_data[31:0];

assign vs2_data1 = vs2_data[127:96];
assign vs2_data2 = vs2_data[95:64];
assign vs2_data3 = vs2_data[63:32];
assign vs2_data4 = vs2_data[31:0];

assign vd_data_wb = {vd_data1, vd_data2, vd_data3, vd_data4};

ALU_array ALU_test (
    .enable (enable_ALU),
    .in_A1 (vs1_data1),
    .in_A2 (vs1_data2),
    .in_A3 (vs1_data3),
    .in_A4 (vs1_data4),
    .in_B1 (vs2_data1),
    .in_B2 (vs2_data2),
    .in_B3 (vs2_data3),
    .in_B4 (vs2_data4),
    .out1 (vd_data1),
    .out2 (vd_data2),
    .out3 (vd_data3),
    .out4 (vd_data4)
);

endmodule