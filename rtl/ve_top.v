module ve_top (
    input         clk,
    input         rst,

    input         i_valid,
    input  [31:0] i_instr,       // instruccion RVV de 32 bits
    input         i_is_vx,       // indica instruccion vector-escalar
    input  [31:0] i_scalar,      // valor escalar para operaciones VX
    input  [31:0] i_base_addr,   // direccion base para VLSU (simula rs1 escalar)
    input  [31:0] i_stride,      // stride para VLSU strided (simula rs2 escalar)

    // Interfaz con DCache (externa)
    output [31:0] o_mem_addr,
    output        o_mem_read_en,
    input  [31:0] i_mem_rdata,
    output        o_mem_write_en,
    output [31:0] o_mem_wdata,
    output [3:0]  o_mem_byte_en
);

    // =========================================================================
    // Decodificacion de opcode y dispatch
    // =========================================================================
    wire        vlsu_busy;   // declarado aqui para uso en dispatch y scoreboard

    wire [6:0] opcode       = i_instr[6:0];
    wire [4:0] instr_rs1    = i_instr[19:15];
    wire [4:0] instr_rs2    = i_instr[24:20];
    wire [4:0] instr_rd     = i_instr[11:7];
    wire [2:0] instr_funct3 = i_instr[14:12];
    wire [6:0] instr_funct7 = i_instr[31:25];

    wire is_alu_op  = (opcode == 7'b1010111);
    wire is_vlsu_op = (opcode == 7'b0000111) || (opcode == 7'b0100111);

    // =========================================================================
    // Scoreboard: 1 bit por registro vectorial
    // Solo las cargas marcan registros como busy (stores no escriben al VRF)
    // =========================================================================
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

    // Hazard: alguno de los registros involucrados en la instruccion ALU
    // esta siendo escrito por el VLSU
    wire alu_hazard = scoreboard[instr_rs1] | scoreboard[instr_rs2] | scoreboard[instr_rd];

    wire alu_valid  = i_valid && is_alu_op  && !alu_hazard;
    wire vlsu_valid = i_valid && is_vlsu_op && !vlsu_busy;

    // =========================================================================
    // Banco de registros vectoriales (3 puertos de lectura)
    // Puerto A: issue stage rs1
    // Puerto B: issue stage rs2
    // Puerto C: VLSU vs3 (stores)
    // =========================================================================
    wire [4:0]   addr_a, addr_b;
    wire [127:0] data_a, data_b, data_c;

    // Puerto de escritura: mux entre VLSU (cargas) y ALU writeback
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
        .i_funct7   (instr_funct7),
        .i_funct3   (instr_funct3),
        .i_rs1      (instr_rs1),
        .i_rs2      (instr_rs2),
        .i_rd       (instr_rd),
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
        .i_instr          (i_instr),
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
