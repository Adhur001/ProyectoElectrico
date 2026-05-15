module alu #(parameter SIZE = 32) (
    input      [2:0]      alu_op,
    input      [SIZE-1:0] in_a,
    input      [SIZE-1:0] in_b,
    output reg [SIZE-1:0] out
);
    always @(*) begin
        case (alu_op)
            3'b000: out = in_a + in_b;          // VADD
            3'b001: out = in_a - in_b;          // VSUB
            3'b010: out = in_a & in_b;          // VAND
            3'b011: out = in_a | in_b;          // VOR
            3'b100: out = in_a ^ in_b;          // VXOR
            default: out = {SIZE{1'b0}};
        endcase
    end
endmodule
