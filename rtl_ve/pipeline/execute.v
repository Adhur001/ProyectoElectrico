module execute (
    input         clk,
    input         rst,
    input         i_stall,  // inserta burbuja en MEM cuando hay conflicto de DCache

    // De Issue
    input         i_valid,
    input         i_is_lsu,
    input  [3:0]  i_alu_op,
    input  [4:0]  i_rd,
    input  [127:0] i_vs1_data,
    input  [127:0] i_vs2_data,
    // Campos LSU
    input         i_is_load,
    input         i_is_store,
    input         i_is_mask_op,
    input         i_is_strided,
    input         i_is_indexed,
    input  [31:0] i_base_addr,
    input  [31:0] i_stride,
    input  [127:0] i_vs3_data,
    input  [127:0] i_offset_buf,
    // Rdata de DCache ACCESS_01 (capturas combinacionales del mismo ciclo)
    input  [31:0] i_mem_rdata,
    input  [31:0] i_mem_rdata_b,

    // Registro de pipeline Execute→MEM
    output reg        o_valid,
    output reg        o_is_lsu,
    output reg [4:0]  o_rd,
    output reg [127:0] o_result,   // resultado ALU
    // Campos LSU propagados a MEM
    output reg        o_is_load,
    output reg        o_is_store,
    output reg        o_is_mask_op,
    output reg        o_is_strided,
    output reg        o_is_indexed,
    output reg [31:0] o_base_addr,
    output reg [31:0] o_stride,
    output reg [127:0] o_vs3_data,
    output reg [127:0] o_offset_buf,
    output reg [63:0]  o_asm_lo,  // rdata de ACCESS_01 para cargas

    // DCache ACCESS_01 — salidas combinacionales del VLSU
    output wire [31:0] o_mem_addr,
    output wire        o_mem_read_en,
    output wire        o_mem_write_en,
    output wire [31:0] o_mem_wdata,
    output wire [3:0]  o_mem_byte_en,
    output wire [31:0] o_mem_addr_b,
    output wire        o_mem_read_en_b,
    output wire        o_mem_write_en_b,
    output wire [31:0] o_mem_wdata_b,
    output wire [3:0]  o_mem_byte_en_b
);

    wire [127:0] alu_out;

    alu_array #(.SIZE(32), .N(4)) alu (
        .alu_op (i_alu_op),
        .in_a   (i_vs1_data),
        .in_b   (i_vs2_data),
        .out    (alu_out)
    );

    // i_stall=1: la instruccion LSU en la entrada es VLSE32 esperando a entrar a execute,
    // no debe acceder a DCache todavia — MEM ya esta usando el bus este ciclo.
    vlsu lsu_access01 (
        .i_phase         (2'b00),
        .i_en            (i_is_lsu && !i_stall),
        .i_is_load       (i_is_load),
        .i_is_store      (i_is_store),
        .i_is_mask_op    (i_is_mask_op),
        .i_is_strided    (i_is_strided),
        .i_is_indexed    (i_is_indexed),
        .i_base_addr     (i_base_addr),
        .i_stride        (i_stride),
        .i_offset_buf    (i_offset_buf),
        .i_wdata         (i_vs3_data),
        .o_mem_addr      (o_mem_addr),
        .o_mem_read_en   (o_mem_read_en),
        .o_mem_write_en  (o_mem_write_en),
        .o_mem_wdata     (o_mem_wdata),
        .o_mem_byte_en   (o_mem_byte_en),
        .o_mem_addr_b    (o_mem_addr_b),
        .o_mem_read_en_b (o_mem_read_en_b),
        .o_mem_write_en_b(o_mem_write_en_b),
        .o_mem_wdata_b   (o_mem_wdata_b),
        .o_mem_byte_en_b (o_mem_byte_en_b)
    );

    always @(posedge clk) begin
        if (rst) begin
            o_valid      <= 1'b0;
            o_is_lsu     <= 1'b0;
            o_rd         <= 5'b0;
            o_result     <= 128'b0;
            o_is_load    <= 1'b0;
            o_is_store   <= 1'b0;
            o_is_mask_op <= 1'b0;
            o_is_strided <= 1'b0;
            o_is_indexed <= 1'b0;
            o_base_addr  <= 32'b0;
            o_stride     <= 32'b0;
            o_vs3_data   <= 128'b0;
            o_offset_buf <= 128'b0;
            o_asm_lo     <= 64'b0;
        end else if (i_stall) begin
            // Conflicto de DCache: insertar burbuja en MEM
            o_valid  <= 1'b0;
            o_is_lsu <= 1'b0;
        end else begin
            o_valid      <= i_valid;
            o_is_lsu     <= i_is_lsu;
            o_rd         <= i_rd;
            o_result     <= alu_out;
            o_is_load    <= i_is_load;
            o_is_store   <= i_is_store;
            o_is_mask_op <= i_is_mask_op;
            o_is_strided <= i_is_strided;
            o_is_indexed <= i_is_indexed;
            o_base_addr  <= i_base_addr;
            o_stride     <= i_stride;
            o_vs3_data   <= i_vs3_data;
            o_offset_buf <= i_offset_buf;
            o_asm_lo     <= {i_mem_rdata_b, i_mem_rdata};
        end
    end
endmodule
