module mem (
    input         clk,
    input         rst,

    // De Execute
    input         i_valid,
    input         i_is_lsu,
    input         i_is_load,
    input         i_is_store,
    input         i_is_mask_op,
    input         i_is_strided,
    input         i_is_indexed,
    input  [31:0] i_base_addr,
    input  [31:0] i_stride,
    input  [127:0] i_offset_buf,
    input  [127:0] i_vs3_data,
    input  [4:0]  i_rd,
    input  [127:0] i_result,    // resultado ALU (path no-LSU)
    input  [63:0]  i_asm_lo,   // rdata de ACCESS_01 capturado en Execute

    // Rdata de DCache ACCESS_23 (combinacional, mismo ciclo)
    input  [31:0]  i_mem_rdata,
    input  [31:0]  i_mem_rdata_b,

    // Registro de pipeline MEM→Writeback
    output reg        o_valid,
    output reg        o_is_store,
    output reg [4:0]  o_rd,
    output reg [127:0] o_result,

    // DCache ACCESS_23 — salidas combinacionales del VLSU
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

    vlsu lsu_access23 (
        .i_phase         (2'b01),
        .i_en            (i_valid && i_is_lsu && !i_is_mask_op),
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

    // Ensambla los 128 bits completos: ACCESS_01 (asm_lo) + ACCESS_23 (rdata)
    wire [127:0] asm_full  = {i_mem_rdata_b, i_mem_rdata, i_asm_lo};

    // VLM usa solo el byte 0 del primer acceso
    wire [127:0] load_data = i_is_mask_op ? {120'b0, i_asm_lo[7:0]} : asm_full;

    always @(posedge clk) begin
        if (rst) begin
            o_valid    <= 1'b0;
            o_is_store <= 1'b0;
            o_rd       <= 5'b0;
            o_result   <= 128'b0;
        end else begin
            o_valid    <= i_valid;
            o_is_store <= i_is_store;
            o_rd       <= i_rd;
            o_result   <= (i_is_lsu && i_is_load) ? load_data : i_result;
        end
    end
endmodule
