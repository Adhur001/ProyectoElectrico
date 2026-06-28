module alu #(parameter SIZE = 32) (
    input      [3:0]      alu_op,
    input      [SIZE-1:0] in_a,
    input      [SIZE-1:0] in_b,
    output reg [SIZE-1:0] out
);
    always @(*) begin
        case (alu_op)
            4'b0000: out = in_a + in_b;
            4'b1000: out = in_a - in_b;
            4'b0001: out = in_a << in_b[4:0];
            4'b0010: out = ($signed(in_a) < $signed(in_b)) ? {{(SIZE-1){1'b0}}, 1'b1}
                                                            : {SIZE{1'b0}};
            4'b0011: out = (in_a < in_b) ? {{(SIZE-1){1'b0}}, 1'b1}
                                         : {SIZE{1'b0}};
            4'b0100: out = in_a ^ in_b;
            4'b0101: out = in_a >> in_b[4:0];
            4'b1101: out = $signed(in_a) >>> in_b[4:0];
            4'b0110: out = in_a | in_b;
            4'b0111: out = in_a & in_b;
            default: out = {SIZE{1'b0}};
        endcase
    end
endmodule
