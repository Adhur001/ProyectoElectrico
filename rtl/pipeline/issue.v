module issue (
    input         clk,
    input         rst,

    input         i_valid,
    input  [2:0]  i_funct3,
    input  [4:0]  i_rs1,
    input  [4:0]  i_rs2,
    input  [4:0]  i_rd,

    input  [127:0] i_vs1_data,
    input  [127:0] i_vs2_data,

    output [4:0]  o_addr_a,
    output [4:0]  o_addr_b,

    output reg        o_valid,
    output reg [2:0]  o_alu_op,
    output reg [4:0]  o_rd,
    output reg [127:0] o_vs1_data,
    output reg [127:0] o_vs2_data
);

    assign o_addr_a = i_rs1;
    assign o_addr_b = i_rs2;

    always @(posedge clk) begin
        if (rst) begin
            o_valid    <= 1'b0;
            o_alu_op   <= 3'b0;
            o_rd       <= 5'b0;
            o_vs1_data <= 128'b0;
            o_vs2_data <= 128'b0;
        end else begin
            o_valid    <= i_valid;
            o_alu_op   <= i_funct3;
            o_rd       <= i_rd;
            o_vs1_data <= i_vs1_data;
            o_vs2_data <= i_vs2_data;
        end
    end
endmodule
