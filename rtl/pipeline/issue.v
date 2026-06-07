module issue (
    input         clk,
    input         rst,

    input         i_valid,
    input  [31:0] i_instr,       // instruccion ALU completa (opcode 1010111, R-type)

    input  [127:0] i_vs1_data,
    input  [127:0] i_vs2_data,

    output [4:0]  o_addr_a,      // indice rs1 → puerto A del VRF
    output [4:0]  o_addr_b,      // indice rs2 → puerto B del VRF

    output reg        o_valid,
    output reg [2:0]  o_alu_op,
    output reg [4:0]  o_rd,
    output reg [127:0] o_vs1_data,
    output reg [127:0] o_vs2_data
);

    // Extraccion de campos R-type de la instruccion ALU vectorial
    wire [4:0] rs1    = i_instr[19:15];
    wire [4:0] rs2    = i_instr[24:20];
    wire [4:0] rd     = i_instr[11:7];
    wire [2:0] funct3 = i_instr[14:12];

    assign o_addr_a = rs1;
    assign o_addr_b = rs2;

    always @(posedge clk) begin
        if (rst) begin
            o_valid    <= 1'b0;
            o_alu_op   <= 3'b0;
            o_rd       <= 5'b0;
            o_vs1_data <= 128'b0;
            o_vs2_data <= 128'b0;
        end else begin
            o_valid    <= i_valid;
            o_alu_op   <= funct3;
            o_rd       <= rd;
            o_vs1_data <= i_vs1_data;
            o_vs2_data <= i_vs2_data;
        end
    end
endmodule
