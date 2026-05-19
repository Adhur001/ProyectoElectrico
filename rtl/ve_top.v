module ve_top (
    input         clk,
    input         rst,

    input         i_valid,
    input  [2:0]  i_funct3,
    input  [4:0]  i_rs1,
    input  [4:0]  i_rs2,
    input  [4:0]  i_rd
);
    wire [4:0]    addr_a, addr_b, addr_w;
    wire [127:0]  data_a, data_b, data_in;
    wire          we;

    wire          s1_valid;
    wire [2:0]    s1_alu_op;
    wire [4:0]    s1_rd;
    wire [127:0]  s1_vs1_data, s1_vs2_data;

    wire          s2_valid;
    wire [4:0]    s2_rd;
    wire [127:0]  s2_result;

    vregisters vregfile (
        .clk     (clk),
        .rst     (rst),
        .we      (we),
        .addr_a  (addr_a),
        .addr_b  (addr_b),
        .addr_w  (addr_w),
        .data_in (data_in),
        .data_a  (data_a),
        .data_b  (data_b)
    );

    issue stage1 (
        .clk        (clk),
        .rst        (rst),
        .i_valid    (i_valid),
        .i_funct3   (i_funct3),
        .i_rs1      (i_rs1),
        .i_rs2      (i_rs2),
        .i_rd       (i_rd),
        .i_vs1_data (data_a),
        .i_vs2_data (data_b),
        .o_addr_a   (addr_a),
        .o_addr_b   (addr_b),
        .o_valid    (s1_valid),
        .o_alu_op   (s1_alu_op),
        .o_rd       (s1_rd),
        .o_vs1_data (s1_vs1_data),
        .o_vs2_data (s1_vs2_data)
    );

    execute stage2 (
        .clk        (clk),
        .rst        (rst),
        .i_valid    (s1_valid),
        .i_alu_op   (s1_alu_op),
        .i_rd       (s1_rd),
        .i_vs1_data (s1_vs1_data),
        .i_vs2_data (s1_vs2_data),
        .o_valid    (s2_valid),
        .o_rd       (s2_rd),
        .o_result   (s2_result)
    );

    writeback stage3 (
        .i_valid    (s2_valid),
        .i_rd       (s2_rd),
        .i_result   (s2_result),
        .o_we       (we),
        .o_addr_w   (addr_w),
        .o_data_in  (data_in)
    );
endmodule
