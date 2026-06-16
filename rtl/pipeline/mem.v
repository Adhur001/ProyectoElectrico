module mem (
    input         clk,
    input         rst,

    // De Execute
    input         i_valid,
    input         i_is_lsu,
    input         i_is_load,
    input         i_is_store,
    input         i_is_mask_op,
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
    output reg [127:0] o_result
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
