// receives intructions and decodes it into addresses and alu operation
module decode_unit (
    input  logic clk,
    input logic enable_decode,
    input  logic reset,
    input logic [31:0] instruction,
    output  logic [2:0] alu_op,
    output logic [4:0] addr_A,
    output logic [4:0] addr_B,
    output logic [4:0] addr_W,
    output logic write,
    output logic enable_ALU
);

    always @(posedge clk) begin
        if (reset) begin
            alu_op <= 3'b000;
            addr_A <= 5'b0;
            addr_B <= 5'b0;
            addr_W <= 5'b0;
            write <= 1'b0;
            enable_ALU <= 1'b0;
        end else if (enable_decode) begin // for now ALU is always available
            alu_op <= instruction[14:12];
            addr_A <= instruction[19:15];
            addr_B <= instruction[24:20];
            addr_W <= instruction[11:7];
            write <= 1'b1;
            // idea for next pipeline stage
            enable_ALU <= 1'b1;
        end
    end

endmodule
