module writeback (
    input         i_valid,
    input         i_is_store,  // stores no escriben al VRF
    input  [4:0]  i_rd,
    input  [127:0] i_result,

    output        o_we,
    output [4:0]  o_addr_w,
    output [127:0] o_data_in
);
    assign o_we      = i_valid && !i_is_store;
    assign o_addr_w  = i_rd;
    assign o_data_in = i_result;
endmodule
