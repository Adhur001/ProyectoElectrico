module ALU #(parameter SIZE = 32) (
    input  logic            enable,
    input  logic [2:0]      alu_op,
    input  logic [SIZE-1:0] in_A,
    input  logic [SIZE-1:0] in_B,
    output logic [SIZE-1:0] out
);
    always @(*) begin
        if (enable) begin
            case (alu_op)
                3'b000: out = in_A + in_B;  // ADD
                3'b001: out = in_A - in_B;  // SUB
                3'b010: out = in_A & in_B;  // AND
                3'b011: out = in_A | in_B;  // OR
                3'b100: out = in_A ^ in_B;  // XOR
                default: out = '0;
            endcase
        end else
            out = '0;
    end
endmodule

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