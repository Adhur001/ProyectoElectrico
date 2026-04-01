// simple test for verilator.

module ALU #(parameter SIZE = 32) (
    input logic [SIZE-1:0] in_A,
    input logic [SIZE-1:0] in_B,
    output logic [SIZE-1:0] out
    );

    assign out = in_A + in_B;

endmodule

module ALU_array #(parameter SIZE = 32) (
    input  logic [SIZE-1:0] in_A1,
    input  logic [SIZE-1:0] in_A2,
    input  logic [SIZE-1:0] in_A3,
    input  logic [SIZE-1:0] in_A4,
    input  logic [SIZE-1:0] in_B1,
    input  logic [SIZE-1:0] in_B2,
    input  logic [SIZE-1:0] in_B3,
    input  logic [SIZE-1:0] in_B4,
    output logic [SIZE-1:0] out1,
    output logic [SIZE-1:0] out2,
    output logic [SIZE-1:0] out3,
    output logic [SIZE-1:0] out4
);

ALU ALU1 (.in_A(in_A1), .in_B(in_B1), .out(out1));
ALU ALU2 (.in_A(in_A2), .in_B(in_B2), .out(out2));
ALU ALU3 (.in_A(in_A3), .in_B(in_B3), .out(out3));
ALU ALU4 (.in_A(in_A4), .in_B(in_B4), .out(out4));

endmodule
