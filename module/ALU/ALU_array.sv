`include "ALU.sv"

module ALU_array #(parameter SIZE = 32, parameter N = 4) (
    input  logic            enable,
    input  logic [2:0]      alu_op,
    input  logic [SIZE-1:0] in_A [N],
    input  logic [SIZE-1:0] in_B [N],
    output logic [SIZE-1:0] out  [N]
);

    genvar i;
    for (i = 0; i < N; i++) begin : alu_lanes
        ALU #(.SIZE(SIZE)) alu_inst (
            .enable (enable),
            .alu_op (alu_op),
            .in_A   (in_A[i]),
            .in_B   (in_B[i]),
            .out    (out[i])
        );
    end

endmodule