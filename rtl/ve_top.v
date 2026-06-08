module ve_top (
    input         clk,
    input         rst,

    // Pre-decoded ALU path — de Modified_DecodeUnit (o_vec_*)
    input         i_alu_valid,    // o_vec_valid
    input  [6:0]  i_funct7,       // o_vec_funct7
    input  [2:0]  i_funct3,       // o_vec_funct3
    input  [4:0]  i_rs1,          // o_vec_rs1
    input  [4:0]  i_rs2,          // o_vec_rs2
    input  [4:0]  i_rd,           // o_vec_rd
    input         i_is_vx,        // o_vec_is_vx
    input  [31:0] i_scalar,       // o_vec_scalar

    // Pre-decoded VLSU path — de Modified_DecodeUnit (o_vec_lsu_* / o_vec_*)
    input         i_lsu_valid,    // o_vec_lsu_valid
    input         i_is_load,      // o_vec_is_load
    input         i_is_store,     // o_vec_is_store
    input         i_is_mask_op,   // o_vec_is_mask_op
    input         i_is_strided,   // o_vec_is_strided
    input         i_is_indexed,   // o_vec_is_indexed
    input  [31:0] i_base_addr,    // o_vec_base_addr (valor de rs1 del RF escalar)
    input  [31:0] i_stride,       // o_vec_stride    (valor de rs2 del RF escalar)

    // Interfaz con DCache (externa)
    output [31:0] o_mem_addr,
    output        o_mem_read_en,
    input  [31:0] i_mem_rdata,
    output        o_mem_write_en,
    output [31:0] o_mem_wdata,
    output [3:0]  o_mem_byte_en
);

    // =========================================================================
    // Scoreboard: 1 bit por registro vectorial
    // Solo las cargas marcan registros como busy (stores no escriben al VRF)
    // =========================================================================
    wire        vlsu_busy;

    reg [31:0] scoreboard;

    wire        vlsu_scoreboard_set;
    wire        vlsu_scoreboard_clr;
    wire [4:0]  vlsu_vd;

    always @(posedge clk) begin
        if (rst)
            scoreboard <= 32'b0;
        else begin
            if (vlsu_scoreboard_clr) scoreboard[vlsu_vd] <= 1'b0;
            else if (vlsu_scoreboard_set) scoreboard[vlsu_vd] <= 1'b1;
        end
    end

    // Hazard: alguno de los registros de la instruccion ALU esta ocupado por el VLSU
    wire alu_hazard = scoreboard[i_rs1] | scoreboard[i_rs2] | scoreboard[i_rd];

    wire alu_valid  = i_alu_valid && !alu_hazard;
    wire vlsu_valid = i_lsu_valid && !vlsu_busy;

    // =========================================================================
    // Banco de registros vectoriales (4 puertos de lectura)
    // Puerto A: issue stage vs1
    // Puerto B: issue stage vs2
    // Puerto C: VLSU vs3 (stores)
    // Puerto D: VLSU vs2 (indexed offsets)
    // =========================================================================
    wire [4:0]   addr_a, addr_b;
    wire [127:0] data_a, data_b, data_c;

    wire        vlsu_vrf_we;
    wire [4:0]  vlsu_vrf_addr;
    wire [127:0] vlsu_vrf_data;

    wire        wb_we;
    wire [4:0]  wb_addr_w;
    wire [127:0] wb_data_in;

    // VLSU tiene prioridad — scoreboard garantiza que no hay conflicto de registro
    wire        vrf_we     = vlsu_vrf_we || wb_we;
    wire [4:0]  vrf_addr_w = vlsu_vrf_we ? vlsu_vrf_addr : wb_addr_w;
    wire [127:0] vrf_data_in = vlsu_vrf_we ? vlsu_vrf_data : wb_data_in;

    wire [4:0]   vlsu_vs3;
    wire [4:0]   vlsu_vs2;
    wire [127:0] vlsu_vrf_offset;

    vregisters vregfile (
        .clk     (clk),
        .rst     (rst),
        .we      (vrf_we),
        .addr_w  (vrf_addr_w),
        .data_in (vrf_data_in),
        .addr_a  (addr_a),
        .addr_b  (addr_b),
        .addr_c  (vlsu_vs3),
        .addr_d  (vlsu_vs2),
        .data_a  (data_a),
        .data_b  (data_b),
        .data_c  (data_c),
        .data_d  (vlsu_vrf_offset)
    );

    // =========================================================================
    // Pipeline ALU: issue → execute → writeback
    // =========================================================================
    wire          s1_valid;
    wire [3:0]    s1_alu_op;
    wire [4:0]    s1_rd;
    wire [127:0]  s1_vs1_data, s1_vs2_data;

    wire          s2_valid;
    wire [4:0]    s2_rd;
    wire [127:0]  s2_result;

    issue stage1 (
        .clk        (clk),
        .rst        (rst),
        .i_valid    (alu_valid),
        .i_funct7   (i_funct7),
        .i_funct3   (i_funct3),
        .i_rs1      (i_rs1),
        .i_rs2      (i_rs2),
        .i_rd       (i_rd),
        .i_is_vx    (i_is_vx),
        .i_scalar   (i_scalar),
        .i_vs1_data (data_a),
        .i_vs2_data (data_b),
        .o_addr_a   (addr_a),
        .o_addr_b   (addr_b),
        .o_valid    (s1_valid),
        .o_alu_op   (s1_alu_op),
        .o_rd       (s1_rd),
        .o_vs1_data (s1_vs1_data),
        .o_vs2_data (s1_vs2_data)
    );

    execute stage2 (
        .clk        (clk),
        .rst        (rst),
        .i_valid    (s1_valid),
        .i_alu_op   (s1_alu_op),
        .i_rd       (s1_rd),
        .i_vs1_data (s1_vs1_data),
        .i_vs2_data (s1_vs2_data),
        .o_valid    (s2_valid),
        .o_rd       (s2_rd),
        .o_result   (s2_result)
    );

    writeback stage3 (
        .i_valid    (s2_valid),
        .i_rd       (s2_rd),
        .i_result   (s2_result),
        .o_we       (wb_we),
        .o_addr_w   (wb_addr_w),
        .o_data_in  (wb_data_in)
    );

    // =========================================================================
    // VLSU
    // =========================================================================

    vlsu lsu (
        .clk              (clk),
        .rst              (rst),
        .i_valid          (vlsu_valid),
        .i_vd             (i_rd),           // vd/vs3 = rd field del decode
        .i_vs2            (i_rs2),          // vs2 = rs2 field del decode
        .i_is_load        (i_is_load),
        .i_is_store       (i_is_store),
        .i_is_mask_op     (i_is_mask_op),
        .i_is_strided     (i_is_strided),
        .i_is_indexed     (i_is_indexed),
        .i_base_addr      (i_base_addr),
        .i_stride         (i_stride),
        .o_mem_addr       (o_mem_addr),
        .o_mem_read_en    (o_mem_read_en),
        .i_mem_rdata      (i_mem_rdata),
        .o_mem_write_en   (o_mem_write_en),
        .o_mem_wdata      (o_mem_wdata),
        .o_mem_byte_en    (o_mem_byte_en),
        .o_vrf_we         (vlsu_vrf_we),
        .o_vrf_addr       (vlsu_vrf_addr),
        .o_vrf_data       (vlsu_vrf_data),
        .i_vrf_rdata      (data_c),
        .o_vs3            (vlsu_vs3),
        .i_vrf_offset     (vlsu_vrf_offset),
        .o_vs2            (vlsu_vs2),
        .o_busy           (vlsu_busy),
        .o_scoreboard_set (vlsu_scoreboard_set),
        .o_scoreboard_clr (vlsu_scoreboard_clr),
        .o_vd             (vlsu_vd)
    );

endmodule
