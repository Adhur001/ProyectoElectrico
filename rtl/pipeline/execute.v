module execute (
    input         clk,
    input         rst,

    input         i_valid,
    input  [3:0]  i_alu_op,
    input  [4:0]  i_rd,
    input  [127:0] i_vs1_data,
    input  [127:0] i_vs2_data,

    output reg        o_valid,
    output reg [4:0]  o_rd,
    output reg [127:0] o_result
);

wire [127:0] alu_out;

    alu_array #(.SIZE(32), .N(4)) alu (
        .alu_op (i_alu_op),
        .in_a   (i_vs1_data),
        .in_b   (i_vs2_data),
        .out    (alu_out)
    );

    always @(posedge clk) begin
        if (rst) begin
            o_valid  <= 1'b0;
            o_rd     <= 5'b0;
            o_result <= 128'b0;
        end else begin
            o_valid  <= i_valid;
            o_rd     <= i_rd;
            o_result <= alu_out;
        end
    end
endmodule
