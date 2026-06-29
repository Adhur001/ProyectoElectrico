module ve_top (
    input         clk,
    input         rst,

    // Pre-decoded ALU path — de Modified_DecodeUnit
    input         i_alu_valid,
    input  [6:0]  i_funct7,
    input  [2:0]  i_funct3,
    input  [4:0]  i_rs1,
    input  [4:0]  i_rs2,
    input  [4:0]  i_rd,
    input         i_is_vx,
    input  [31:0] i_scalar,

    // Pre-decoded LSU path — de Modified_DecodeUnit
    input         i_lsu_valid,
    input         i_is_load,
    input         i_is_store,
    input         i_is_mask_op,
    input         i_is_strided,
    input         i_is_indexed,
    input  [31:0] i_base_addr,
    input  [31:0] i_stride,

    // Stall hacia decode unit del procesador escalar
    output        o_stall,

    // Interfaz con DCache (externa) — puerto A
    output [31:0] o_mem_addr,
    output        o_mem_read_en,
    input  [31:0] i_mem_rdata,
    output        o_mem_write_en,
    output [31:0] o_mem_wdata,
    output [3:0]  o_mem_byte_en,

    // Interfaz con DCache (externa) — puerto B
    output [31:0] o_mem_addr_b,
    output        o_mem_read_en_b,
    input  [31:0] i_mem_rdata_b,
    output        o_mem_write_en_b,
    output [31:0] o_mem_wdata_b,
    output [3:0]  o_mem_byte_en_b
);

    // =========================================================================
    // Banco de registros vectoriales (4 puertos de lectura, 1 escritura)
    // Puerto A: vs1 (ALU)
    // Puerto B: vs2 (ALU) / vs2 offset (LSU indexed)
    // Puerto C: vs3/vd (LSU stores — campo rd de la instruccion)
    // Puerto D: vs2 offset (LSU indexed — campo rs2)
    // =========================================================================
    wire [4:0]   addr_a, addr_b, addr_c, addr_d;
    wire [127:0] data_a, data_b, data_c, data_d;

    wire        wb_we;
    wire [4:0]  wb_addr_w;
    wire [127:0] wb_data_in;

    vregisters vregfile (
        .clk     (clk),
        .rst     (rst),
        .we      (wb_we),
        .addr_w  (wb_addr_w),
        .data_in (wb_data_in),
        .addr_a  (addr_a),
        .addr_b  (addr_b),
        .addr_c  (addr_c),
        .addr_d  (addr_d),
        .data_a  (data_a),
        .data_b  (data_b),
        .data_c  (data_c),
        .data_d  (data_d)
    );

    // =========================================================================
    // Senales de pipeline entre etapas
    // s1_* = Issue → Execute
    // s2_* = Execute → MEM
    // s3_* = MEM → Writeback
    // =========================================================================
    wire        s1_valid,   s2_valid;
    wire        s1_is_lsu,  s2_is_lsu;
    wire [3:0]  s1_alu_op;
    wire [4:0]  s1_rd,      s2_rd;
    wire [127:0] s1_vs1_data, s1_vs2_data;
    wire [127:0] s1_result,   s2_result;
    // Campos LSU s1
    wire        s1_is_load,    s1_is_store,    s1_is_mask_op;
    wire        s1_is_strided, s1_is_indexed;
    wire [31:0] s1_base_addr,  s1_stride;
    wire [127:0] s1_vs3_data,  s1_offset_buf;
    // Campos LSU s2
    wire        s2_is_load,    s2_is_store,    s2_is_mask_op;
    wire        s2_is_strided, s2_is_indexed;
    wire [31:0] s2_base_addr,  s2_stride;
    wire [127:0] s2_vs3_data,  s2_offset_buf;
    wire [63:0]  s2_asm_lo;
    // s3
    wire        s3_valid, s3_is_store;
    wire [4:0]  s3_rd;
    wire [127:0] s3_result;

    // =========================================================================
    // Logica de stall: DCache conflict (Execute vs MEM) y RAW hazard
    // dcache_stall: ambas etapas tendrian LSU activo — Execute congela su input (i_stall).
    // raw_stall:    instruccion entrante lee registro escrito por instruccion en pipeline
    //               — Issue inserta burbuja (i_raw_stall), productor avanza normalmente.
    // =========================================================================
    wire dcache_stall = s1_is_lsu && s2_is_lsu;
    wire raw_stall;
    wire stall = dcache_stall || raw_stall;
    assign o_stall = stall;

    hazard_unit hu (
        .i_valid      (i_alu_valid || i_lsu_valid),
        .i_rs1        (i_rs1),
        .i_rs2        (i_rs2),
        .i_is_store   (i_is_store),
        .i_rd         (i_rd),
        .i_s1_valid   (s1_valid),
        .i_s1_rd      (s1_rd),
        .i_s1_is_store(s1_is_store),
        .i_s2_valid   (s2_valid),
        .i_s2_rd      (s2_rd),
        .i_s2_is_store(s2_is_store),
        .i_s3_valid   (s3_valid),
        .i_s3_rd      (s3_rd),
        .i_s3_is_store(s3_is_store),
        .o_raw_stall  (raw_stall)
    );

    // =========================================================================
    // Mux de salidas DCache: Execute (ACCESS_01) o MEM (ACCESS_23)
    // El stall garantiza que nunca esten activos al mismo tiempo.
    // MEM tiene prioridad por simetria con el diseno anterior.
    // =========================================================================
    wire [31:0] exe_mem_addr,       mem_mem_addr;
    wire        exe_mem_read_en,    mem_mem_read_en;
    wire        exe_mem_write_en,   mem_mem_write_en;
    wire [31:0] exe_mem_wdata,      mem_mem_wdata;
    wire [3:0]  exe_mem_byte_en,    mem_mem_byte_en;
    wire [31:0] exe_mem_addr_b,     mem_mem_addr_b;
    wire        exe_mem_read_en_b,  mem_mem_read_en_b;
    wire        exe_mem_write_en_b, mem_mem_write_en_b;
    wire [31:0] exe_mem_wdata_b,    mem_mem_wdata_b;
    wire [3:0]  exe_mem_byte_en_b,  mem_mem_byte_en_b;

    wire sel_mem = s2_is_lsu && !s2_is_mask_op;

    assign o_mem_addr       = sel_mem ? mem_mem_addr       : exe_mem_addr;
    assign o_mem_read_en    = sel_mem ? mem_mem_read_en    : exe_mem_read_en;
    assign o_mem_write_en   = sel_mem ? mem_mem_write_en   : exe_mem_write_en;
    assign o_mem_wdata      = sel_mem ? mem_mem_wdata      : exe_mem_wdata;
    assign o_mem_byte_en    = sel_mem ? mem_mem_byte_en    : exe_mem_byte_en;
    assign o_mem_addr_b     = sel_mem ? mem_mem_addr_b     : exe_mem_addr_b;
    assign o_mem_read_en_b  = sel_mem ? mem_mem_read_en_b  : exe_mem_read_en_b;
    assign o_mem_write_en_b = sel_mem ? mem_mem_write_en_b : exe_mem_write_en_b;
    assign o_mem_wdata_b    = sel_mem ? mem_mem_wdata_b    : exe_mem_wdata_b;
    assign o_mem_byte_en_b  = sel_mem ? mem_mem_byte_en_b  : exe_mem_byte_en_b;

    // =========================================================================
    // Pipeline: Issue → Execute → MEM → Writeback
    // =========================================================================
    issue stage1 (
        .clk          (clk),
        .rst          (rst),
        .i_stall      (dcache_stall),
        .i_raw_stall  (raw_stall),
        .i_alu_valid  (i_alu_valid),
        .i_funct7     (i_funct7),
        .i_funct3     (i_funct3),
        .i_rs1        (i_rs1),
        .i_rs2        (i_rs2),
        .i_rd         (i_rd),
        .i_is_vx      (i_is_vx),
        .i_scalar     (i_scalar),
        .i_vs1_data   (data_a),
        .i_vs2_data   (data_b),
        .i_lsu_valid  (i_lsu_valid),
        .i_is_load    (i_is_load),
        .i_is_store   (i_is_store),
        .i_is_mask_op (i_is_mask_op),
        .i_is_strided (i_is_strided),
        .i_is_indexed (i_is_indexed),
        .i_base_addr  (i_base_addr),
        .i_stride     (i_stride),
        .i_vs3_data   (data_c),
        .i_offset_data(data_d),
        .o_addr_a     (addr_a),
        .o_addr_b     (addr_b),
        .o_addr_c     (addr_c),
        .o_addr_d     (addr_d),
        .o_valid      (s1_valid),
        .o_is_lsu     (s1_is_lsu),
        .o_alu_op     (s1_alu_op),
        .o_rd         (s1_rd),
        .o_vs1_data   (s1_vs1_data),
        .o_vs2_data   (s1_vs2_data),
        .o_is_load    (s1_is_load),
        .o_is_store   (s1_is_store),
        .o_is_mask_op (s1_is_mask_op),
        .o_is_strided (s1_is_strided),
        .o_is_indexed (s1_is_indexed),
        .o_base_addr  (s1_base_addr),
        .o_stride     (s1_stride),
        .o_vs3_data   (s1_vs3_data),
        .o_offset_buf (s1_offset_buf)
    );

    execute stage2 (
        .clk          (clk),
        .rst          (rst),
        .i_stall      (dcache_stall),
        .i_valid      (s1_valid),
        .i_is_lsu     (s1_is_lsu),
        .i_alu_op     (s1_alu_op),
        .i_rd         (s1_rd),
        .i_vs1_data   (s1_vs1_data),
        .i_vs2_data   (s1_vs2_data),
        .i_is_load    (s1_is_load),
        .i_is_store   (s1_is_store),
        .i_is_mask_op (s1_is_mask_op),
        .i_is_strided (s1_is_strided),
        .i_is_indexed (s1_is_indexed),
        .i_base_addr  (s1_base_addr),
        .i_stride     (s1_stride),
        .i_vs3_data   (s1_vs3_data),
        .i_offset_buf (s1_offset_buf),
        .i_mem_rdata      (i_mem_rdata),
        .i_mem_rdata_b    (i_mem_rdata_b),
        .o_mem_addr       (exe_mem_addr),
        .o_mem_read_en    (exe_mem_read_en),
        .o_mem_write_en   (exe_mem_write_en),
        .o_mem_wdata      (exe_mem_wdata),
        .o_mem_byte_en    (exe_mem_byte_en),
        .o_mem_addr_b     (exe_mem_addr_b),
        .o_mem_read_en_b  (exe_mem_read_en_b),
        .o_mem_write_en_b (exe_mem_write_en_b),
        .o_mem_wdata_b    (exe_mem_wdata_b),
        .o_mem_byte_en_b  (exe_mem_byte_en_b),
        .o_valid          (s2_valid),
        .o_is_lsu     (s2_is_lsu),
        .o_rd         (s2_rd),
        .o_result     (s2_result),
        .o_is_load    (s2_is_load),
        .o_is_store   (s2_is_store),
        .o_is_mask_op (s2_is_mask_op),
        .o_is_strided (s2_is_strided),
        .o_is_indexed (s2_is_indexed),
        .o_base_addr  (s2_base_addr),
        .o_stride     (s2_stride),
        .o_vs3_data   (s2_vs3_data),
        .o_offset_buf (s2_offset_buf),
        .o_asm_lo     (s2_asm_lo)
    );

    mem stage3 (
        .clk              (clk),
        .rst              (rst),
        .i_valid          (s2_valid),
        .i_is_lsu         (s2_is_lsu),
        .i_is_load        (s2_is_load),
        .i_is_store       (s2_is_store),
        .i_is_mask_op     (s2_is_mask_op),
        .i_is_strided     (s2_is_strided),
        .i_is_indexed     (s2_is_indexed),
        .i_base_addr      (s2_base_addr),
        .i_stride         (s2_stride),
        .i_offset_buf     (s2_offset_buf),
        .i_vs3_data       (s2_vs3_data),
        .i_rd             (s2_rd),
        .i_result         (s2_result),
        .i_asm_lo         (s2_asm_lo),
        .i_mem_rdata      (i_mem_rdata),
        .i_mem_rdata_b    (i_mem_rdata_b),
        .o_valid          (s3_valid),
        .o_is_store       (s3_is_store),
        .o_rd             (s3_rd),
        .o_result         (s3_result),
        .o_mem_addr       (mem_mem_addr),
        .o_mem_read_en    (mem_mem_read_en),
        .o_mem_write_en   (mem_mem_write_en),
        .o_mem_wdata      (mem_mem_wdata),
        .o_mem_byte_en    (mem_mem_byte_en),
        .o_mem_addr_b     (mem_mem_addr_b),
        .o_mem_read_en_b  (mem_mem_read_en_b),
        .o_mem_write_en_b (mem_mem_write_en_b),
        .o_mem_wdata_b    (mem_mem_wdata_b),
        .o_mem_byte_en_b  (mem_mem_byte_en_b)
    );

    writeback stage4 (
        .i_valid    (s3_valid),
        .i_is_store (s3_is_store),
        .i_rd       (s3_rd),
        .i_result   (s3_result),
        .o_we       (wb_we),
        .o_addr_w   (wb_addr_w),
        .o_data_in  (wb_data_in)
    );

endmodule
