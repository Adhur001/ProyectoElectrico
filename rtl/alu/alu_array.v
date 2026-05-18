module alu_array #(
    parameter SIZE = 32,
    parameter N    = 4
) (
    input  [2:0]        alu_op,
    input  [N*SIZE-1:0] in_a,
    input  [N*SIZE-1:0] in_b,
    output [N*SIZE-1:0] out
);
    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : lane
            alu #(.SIZE(SIZE)) alu_inst (
                .alu_op (alu_op),
                .in_a   (in_a[i*SIZE +: SIZE]),
                .in_b   (in_b[i*SIZE +: SIZE]),
                .out    (out [i*SIZE +: SIZE])
            );
        end
    endgenerate
endmodule
