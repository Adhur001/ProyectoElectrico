`include "ALU/ALU_array.sv"
`include "Vregisters/vregisters.sv"

module temp_wrapper (
    input logic         clk,
    input logic [4:0]   addr_vs1,
    input logic [4:0]   addr_vs2,
    input logic [4:0]   addr_vd,
    input logic [127:0] dummy_data_in,
    input logic         wr_en,
    input logic         sel,
    input logic         enable_ALU,
    input logic [2:0]   alu_op       
);

    logic [127:0] vs1_data, vs2_data, vd_data_wb, data_selected;

    assign data_selected = sel ? dummy_data_in : vd_data_wb;

    vregisters Vregs (
        .clk    (clk),
        .write  (wr_en),
        .addr_A (addr_vs1),
        .addr_B (addr_vs2),
        .addr_W (addr_vd),
        .data_in(data_selected),
        .data_A (vs1_data),
        .data_B (vs2_data)
    );

    // packed arrays for ALU_array interface
    logic [31:0] vs1_lanes [4];
    logic [31:0] vs2_lanes [4];
    logic [31:0] vd_lanes  [4];

    // slice 128-bit vectors into lanes
    assign vs1_lanes[0] = vs1_data[127:96];
    assign vs1_lanes[1] = vs1_data[95:64];
    assign vs1_lanes[2] = vs1_data[63:32];
    assign vs1_lanes[3] = vs1_data[31:0];

    assign vs2_lanes[0] = vs2_data[127:96];
    assign vs2_lanes[1] = vs2_data[95:64];
    assign vs2_lanes[2] = vs2_data[63:32];
    assign vs2_lanes[3] = vs2_data[31:0];

    // reassemble lanes into 128-bit writeback
    assign vd_data_wb = {vd_lanes[0], vd_lanes[1], vd_lanes[2], vd_lanes[3]};

    ALU_array #(.SIZE(32), .N(4)) alu (
        .enable (enable_ALU),
        .alu_op (alu_op),
        .in_A   (vs1_lanes),
        .in_B   (vs2_lanes),
        .out    (vd_lanes)
    );

endmodule