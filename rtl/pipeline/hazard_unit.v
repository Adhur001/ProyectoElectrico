module hazard_unit (
    input         i_valid,
    input  [4:0]  i_rs1,
    input  [4:0]  i_rs2,
    input         i_is_store,
    input  [4:0]  i_rd,

    input         i_s1_valid,
    input  [4:0]  i_s1_rd,
    input         i_s1_is_store,

    input         i_s2_valid,
    input  [4:0]  i_s2_rd,
    input         i_s2_is_store,

    input         i_s3_valid,
    input  [4:0]  i_s3_rd,
    input         i_s3_is_store,

    output        o_raw_stall
);
    wire s1_writes = i_s1_valid && !i_s1_is_store;
    wire s2_writes = i_s2_valid && !i_s2_is_store;
    wire s3_writes = i_s3_valid && !i_s3_is_store;

    wire rs1_haz = (s1_writes && i_s1_rd == i_rs1) ||
                   (s2_writes && i_s2_rd == i_rs1) ||
                   (s3_writes && i_s3_rd == i_rs1);

    wire rs2_haz = (s1_writes && i_s1_rd == i_rs2) ||
                   (s2_writes && i_s2_rd == i_rs2) ||
                   (s3_writes && i_s3_rd == i_rs2);

    wire rd_haz  = i_is_store && (
                   (s1_writes && i_s1_rd == i_rd) ||
                   (s2_writes && i_s2_rd == i_rd) ||
                   (s3_writes && i_s3_rd == i_rd));

    assign o_raw_stall = i_valid && (rs1_haz || rs2_haz || rd_haz);
endmodule
