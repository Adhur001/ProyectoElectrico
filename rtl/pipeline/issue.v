module issue (
    input         clk,
    input         rst,
    input         i_stall,

    // ALU path — de Modified_DecodeUnit
    input         i_alu_valid,
    input  [6:0]  i_funct7,
    input  [2:0]  i_funct3,
    input  [4:0]  i_rs1,
    input  [4:0]  i_rs2,
    input  [4:0]  i_rd,
    input         i_is_vx,
    input  [31:0] i_scalar,
    input  [127:0] i_vs1_data,  // VRF puerto A
    input  [127:0] i_vs2_data,  // VRF puerto B

    // LSU path — de Modified_DecodeUnit
    input         i_lsu_valid,
    input         i_is_load,
    input         i_is_store,
    input         i_is_mask_op,
    input         i_is_strided,
    input         i_is_indexed,
    input  [31:0] i_base_addr,
    input  [31:0] i_stride,
    input  [127:0] i_vs3_data,   // VRF puerto C (rd = vd, fuente en stores)
    input  [127:0] i_offset_data, // VRF puerto D (rs2 = vs2, offsets indexados)

    // Direcciones de lectura del VRF (combinacional)
    output [4:0]  o_addr_a,   // rs1 → vs1
    output [4:0]  o_addr_b,   // rs2 → vs2 (ALU) / vs2 offset (indexed)
    output [4:0]  o_addr_c,   // rd  → vs3/vd (stores)
    output [4:0]  o_addr_d,   // rs2 → offset buffer (indexed)

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

    // Direcciones de lectura del VRF — combinacionales, activas el mismo ciclo que la instruccion entra a Issue.
    // El VRF devuelve los datos en i_vs1_data/i_vs2_data/i_vs3_data/i_offset_data ese mismo ciclo,
    // listos para ser capturados por el registro de pipeline en el flanco siguiente.
    assign o_addr_a = i_rs1; // vs1: primer operando ALU (puerto A)
    assign o_addr_b = i_rs2; // vs2: segundo operando ALU (puerto B)
    assign o_addr_c = i_rd;  // vs3/vd: dato fuente en stores — campo rd reutilizado como vs3 en LSU (puerto C)
    assign o_addr_d = i_rs2; // vs2 offsets: mismo campo rs2, leido en paralelo por puerto D para indexed loads

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
        end else if (!i_stall) begin
            o_valid      <= i_alu_valid || i_lsu_valid; // valido si viene cualquier instruccion vectorial (ALU o LSU)
            o_is_lsu     <= i_lsu_valid;               // distingue LSU de ALU en etapas siguientes; ALU si 0, LSU si 1
            o_alu_op     <= {i_funct7[5], i_funct3};   // codifica la operacion ALU: funct7[5] distingue SUB/SRA de ADD/SRL; funct3 selecciona la operacion
            o_rd         <= i_rd;          // campo [11:7] de la instruccion; se arrastra hasta Writeback para saber a que registro vectorial escribir
            o_vs1_data   <= i_vs1_data;    // 128b de vs1 leidos del VRF puerto A; primer operando ALU
            o_vs2_data   <= i_is_vx ? {i_scalar, i_scalar, i_scalar, i_scalar} // VX: replica el escalar en las 4 lanes de 32b
                                    : i_vs2_data;                               // VV: usa el registro vectorial vs2 del VRF
            o_is_load    <= i_is_load;
            o_is_store   <= i_is_store;
            o_is_mask_op <= i_is_mask_op;
            o_is_strided <= i_is_strided;
            o_is_indexed <= i_is_indexed;
            o_base_addr  <= i_base_addr;   // valor de rs1 del banco escalar (o_vec_base_addr en DecodeUnit); direccion base para el VLSU
            o_stride     <= i_stride;      // valor de rs2 del banco escalar (o_vec_stride en DecodeUnit); salto entre elementos en modo strided
            o_vs3_data   <= i_vs3_data;    // 128b de vs3/vd leidos del VRF puerto C; dato a escribir en memoria en stores
            o_offset_buf <= i_offset_data; // 128b de vs2 leidos del VRF puerto D; 4 offsets de 32b para calcular direcciones en modo indexed
        end
        // i_stall=1: mantiene todos los registros de salida sin cambios
    end
endmodule
