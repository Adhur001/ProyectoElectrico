module issue (
    input         clk,
    input         rst,
    input         i_stall,
    input         i_raw_stall,

    // ALU path — de Modified_DecodeUnit
    input         i_alu_valid,
    input  [6:0]  i_funct7,
    input  [2:0]  i_funct3,
    input  [4:0]  i_rs1,
    input  [4:0]  i_rs2,
    input  [4:0]  i_rd,
    input         i_is_vx,
    input  [31:0] i_scalar,
    input  [127:0] i_vs1_data,
    input  [127:0] i_vs2_data,

    // LSU path — de Modified_DecodeUnit
    input         i_lsu_valid,
    input         i_is_load,
    input         i_is_store,
    input         i_is_mask_op,
    input         i_is_strided,
    input         i_is_indexed,
    input  [31:0] i_base_addr,
    input  [31:0] i_stride,
    input  [127:0] i_vs3_data,
    input  [127:0] i_offset_data,

    // Direcciones de lectura del VRF (combinacional)
    output [4:0]  o_addr_a,
    output [4:0]  o_addr_b,
    output [4:0]  o_addr_c,
    output [4:0]  o_addr_d,

    // Registro de pipeline Issue→Execute
    output reg        o_valid,
    output reg        o_is_lsu,
    output reg [3:0]  o_alu_op,
    output reg [4:0]  o_rd,
    output reg [127:0] o_vs1_data,
    output reg [127:0] o_vs2_data,
    // Campos LSU
    output reg        o_is_load,
    output reg        o_is_store,
    output reg        o_is_mask_op,
    output reg        o_is_strided,
    output reg        o_is_indexed,
    output reg [31:0] o_base_addr,
    output reg [31:0] o_stride,
    output reg [127:0] o_vs3_data,
    output reg [127:0] o_offset_buf
);

    assign o_addr_a = i_rs1;
    assign o_addr_b = i_rs2;
    assign o_addr_c = i_rd;
    assign o_addr_d = i_rs2;

    always @(posedge clk) begin
        if (rst) begin
            o_valid      <= 1'b0;
            o_is_lsu     <= 1'b0;
            o_alu_op     <= 4'b0;
            o_rd         <= 5'b0;
            o_vs1_data   <= 128'b0;
            o_vs2_data   <= 128'b0;
            o_is_load    <= 1'b0;
            o_is_store   <= 1'b0;
            o_is_mask_op <= 1'b0;
            o_is_strided <= 1'b0;
            o_is_indexed <= 1'b0;
            o_base_addr  <= 32'b0;
            o_stride     <= 32'b0;
            o_vs3_data   <= 128'b0;
            o_offset_buf <= 128'b0;
        end else if (i_stall) begin
            // DCache freeze: mantiene todos los registros de salida sin cambios
        end else if (i_raw_stall) begin
            // RAW hazard: inserta burbuja para que el productor avance sin que el consumidor entre
            o_valid  <= 1'b0;
            o_is_lsu <= 1'b0;
        end else begin
            o_valid      <= i_alu_valid || i_lsu_valid;
            o_is_lsu     <= i_lsu_valid;
            o_alu_op     <= {i_funct7[5], i_funct3};
            o_rd         <= i_rd;
            o_vs1_data   <= i_vs1_data;
            o_vs2_data   <= i_is_vx ? {i_scalar, i_scalar, i_scalar, i_scalar}
                                    : i_vs2_data;
            o_is_load    <= i_is_load;
            o_is_store   <= i_is_store;
            o_is_mask_op <= i_is_mask_op;
            o_is_strided <= i_is_strided;
            o_is_indexed <= i_is_indexed;
            o_base_addr  <= i_base_addr;
            o_stride     <= i_stride;
            o_vs3_data   <= i_vs3_data;
            o_offset_buf <= i_offset_data;
        end
    end
endmodule
