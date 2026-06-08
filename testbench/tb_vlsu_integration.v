// Testbench de integracion: DecodeUnit + VLSU + banco de registros vectoriales + DCache
// Verifica el flujo completo: instruccion → decode → VLSU → memoria/VRF
// Todas las instrucciones usan x1 (int_rf[1]) para base_addr y x2 (int_rf[2]) para stride.

`timescale 1ns/1ps

module tb_vlsu_integration;

    // -------------------------------------------------------------------------
    // Reloj y reset
    // -------------------------------------------------------------------------
    reg clk, rst;
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Registro entero simulado — el decode lee base_addr (rs1) y stride (rs2) de aqui
    // -------------------------------------------------------------------------
    reg [31:0] int_rf [0:31];

    // Instruccion al decode unit
    reg [31:0] du_i_instr;

    // -------------------------------------------------------------------------
    // Decode unit (Modified_DecodeUnit.v)
    // -------------------------------------------------------------------------
    wire [4:0]  du_o_rs1_addr, du_o_rs2_addr;

    wire        du_o_vec_lsu_valid;
    wire        du_o_vec_is_load, du_o_vec_is_store;
    wire        du_o_vec_is_mask_op, du_o_vec_is_strided, du_o_vec_is_indexed;
    wire [4:0]  du_o_vec_rd, du_o_vec_rs2;
    wire [31:0] du_o_vec_base_addr, du_o_vec_stride;

    decode du (
        .CLK            (clk),
        .RST            (rst),
        .FLUSH          (1'b0),
        .STALL          (1'b0),
        .i_instr        (du_i_instr),
        .i_pc           (32'b0),
        .i_bubble       (1'b0),
        .i_rs1_data     (int_rf[du_o_rs1_addr]),
        .i_rs2_data     (int_rf[du_o_rs2_addr]),
        .o_rs1_addr     (du_o_rs1_addr),
        .o_rs2_addr     (du_o_rs2_addr),
        .o_vec_lsu_valid  (du_o_vec_lsu_valid),
        .o_vec_is_load    (du_o_vec_is_load),
        .o_vec_is_store   (du_o_vec_is_store),
        .o_vec_is_mask_op (du_o_vec_is_mask_op),
        .o_vec_is_strided (du_o_vec_is_strided),
        .o_vec_is_indexed (du_o_vec_is_indexed),
        .o_vec_rd         (du_o_vec_rd),
        .o_vec_rs2        (du_o_vec_rs2),
        .o_vec_base_addr  (du_o_vec_base_addr),
        .o_vec_stride     (du_o_vec_stride),
        // outputs no conectados en este banco de pruebas
        .o_rs1_2_pc     (),
        .o_is_branch    (),
        .o_is_type_u    (),
        .o_dual_op      (),
        .o_pc           (),
        .o_imm          (),
        .o_is_unsigned  (),
        .o_data_size    (),
        .o_alu_op       (),
        .o_alu_src_rs2  (),
        .o_dmem_write   (),
        .o_dmen_read    (),
        .o_rd_addr      (),
        .o_write_on_reg (),
        .o_vec_valid    (),
        .o_vec_funct7   (),
        .o_vec_funct3   (),
        .o_vec_rs1      (),
        .o_vec_is_vx    (),
        .o_vec_scalar   ()
    );

    // -------------------------------------------------------------------------
    // Señales del VLSU
    // -------------------------------------------------------------------------
    wire [31:0]  o_mem_addr;
    wire         o_mem_read_en;
    reg  [31:0]  i_mem_rdata;
    wire         o_mem_write_en;
    wire [31:0]  o_mem_wdata;
    wire [3:0]   o_mem_byte_en;

    wire         o_vrf_we;
    wire [4:0]   o_vrf_addr;
    wire [127:0] o_vrf_data;
    wire [127:0] i_vrf_rdata;
    wire [4:0]   o_vs3;
    wire [127:0] i_vrf_offset;
    wire [4:0]   o_vs2;

    wire         o_busy;
    wire         o_scoreboard_set;
    wire         o_scoreboard_clr;
    wire [4:0]   o_vd;

    // -------------------------------------------------------------------------
    // Modelo de DCache (lectura combinacional, escritura sincrona)
    // -------------------------------------------------------------------------
    reg [31:0] mem [0:127];

    always @(*) begin
        if (o_mem_read_en)
            i_mem_rdata = mem[o_mem_addr[6:0]];
        else
            i_mem_rdata = 32'b0;
    end

    always @(posedge clk) begin
        if (o_mem_write_en) begin
            if (o_mem_byte_en[0]) mem[o_mem_addr[6:0]][7:0]   <= o_mem_wdata[7:0];
            if (o_mem_byte_en[1]) mem[o_mem_addr[6:0]][15:8]  <= o_mem_wdata[15:8];
            if (o_mem_byte_en[2]) mem[o_mem_addr[6:0]][23:16] <= o_mem_wdata[23:16];
            if (o_mem_byte_en[3]) mem[o_mem_addr[6:0]][31:24] <= o_mem_wdata[31:24];
        end
    end

    // -------------------------------------------------------------------------
    // Instancia del VLSU — recibe campos ya decodificados del decode unit
    // -------------------------------------------------------------------------
    vlsu lsu (
        .clk              (clk),
        .rst              (rst),
        .i_valid          (du_o_vec_lsu_valid),
        .i_vd             (du_o_vec_rd),         // rd = vd/vs3
        .i_vs2            (du_o_vec_rs2),        // rs2 = vs2 (indexed offsets)
        .i_is_load        (du_o_vec_is_load),
        .i_is_store       (du_o_vec_is_store),
        .i_is_mask_op     (du_o_vec_is_mask_op),
        .i_is_strided     (du_o_vec_is_strided),
        .i_is_indexed     (du_o_vec_is_indexed),
        .i_base_addr      (du_o_vec_base_addr),
        .i_stride         (du_o_vec_stride),
        .o_mem_addr       (o_mem_addr),
        .o_mem_read_en    (o_mem_read_en),
        .i_mem_rdata      (i_mem_rdata),
        .o_mem_write_en   (o_mem_write_en),
        .o_mem_wdata      (o_mem_wdata),
        .o_mem_byte_en    (o_mem_byte_en),
        .o_vrf_we         (o_vrf_we),
        .o_vrf_addr       (o_vrf_addr),
        .o_vrf_data       (o_vrf_data),
        .i_vrf_rdata      (i_vrf_rdata),
        .o_vs3            (o_vs3),
        .i_vrf_offset     (i_vrf_offset),
        .o_vs2            (o_vs2),
        .o_busy           (o_busy),
        .o_scoreboard_set (o_scoreboard_set),
        .o_scoreboard_clr (o_scoreboard_clr),
        .o_vd             (o_vd)
    );

    // -------------------------------------------------------------------------
    // Banco de registros vectoriales
    // -------------------------------------------------------------------------
    reg  [4:0]   read_addr;
    wire [127:0] read_data;

    vregisters vrf (
        .clk     (clk),
        .rst     (rst),
        .we      (o_vrf_we),
        .addr_w  (o_vrf_addr),
        .data_in (o_vrf_data),
        .addr_a  (o_vs3),        // VLSU: lectura de vs3 (stores)
        .addr_b  (read_addr),    // puerto libre para verificacion
        .addr_c  (5'b0),
        .addr_d  (o_vs2),        // VLSU: lectura de vs2 (indexed offsets)
        .data_a  (i_vrf_rdata),
        .data_b  (read_data),
        .data_c  (),
        .data_d  (i_vrf_offset)
    );

    // -------------------------------------------------------------------------
    integer pass = 0, fail = 0;

    task check;
        input [127:0] got;
        input [127:0] expected;
        begin
            if (got === expected) begin
                pass = pass + 1;
                $display("      PASS");
            end else begin
                fail = fail + 1;
                $display("      FAIL: obtenido=%h  esperado=%h", got, expected);
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Secuencia de pruebas
    // Latencia decode: 1 ciclo extra vs el testbench anterior.
    //   Cargas:  7 @posedge (1 decode + 1 IDLE→ACCESS_0 + 4 ACCESS + 1 WRITEBACK)
    //   Stores:  6 @posedge (1 decode + 1 IDLE→SWRITE_0 + 4 SWRITE)
    // int_rf[1] = base_addr (rs1=x1 en todas las instrucciones)
    // int_rf[2] = stride    (rs2=x2 en instrucciones strided)
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_vlsu_integration.vcd");
        $dumpvars(0, tb_vlsu_integration);

        // Inicializar DCache para pruebas de carga
        mem[0]  = 32'hDEAD_BEEF;
        mem[4]  = 32'hCAFE_BABE;
        mem[8]  = 32'h1234_5678;
        mem[12] = 32'h9ABC_DEF0;

        mem[20] = 32'h0000_0001;
        mem[24] = 32'h0000_0002;
        mem[28] = 32'h0000_0003;
        mem[32] = 32'h0000_0004;

        mem[100] = 32'hA1A1_A1A1;
        mem[104] = 32'hB2B2_B2B2;
        mem[108] = 32'hC3C3_C3C3;
        mem[112] = 32'hD4D4_D4D4;

        du_i_instr = 32'h0000_0013; read_addr = 0;
        rst = 1;
        @(posedge clk); @(posedge clk);
        #1; rst = 0;
        @(posedge clk); #1;

        // =================================================================
        // TEST 1: VLE32.v v3, (x1)  base=0 → vregisters[3]
        //   Instruccion: 32'h0200_E187  (rs1=x1, mop=00, vd=v3, width=110)
        //   Esperado: {0x9ABCDEF0, 0x12345678, 0xCAFEBABE, 0xDEADBEEF}
        // =================================================================
        $display("\n[TEST 1] VLE32.v v3, (x1)  base=0 → vregisters[3]");
        int_rf[1] = 32'd0;
        du_i_instr = 32'h0200_E187;
        @(posedge clk); #1; du_i_instr = 32'h0000_0013; // decode captura
        @(posedge clk); #1;  // IDLE→ACCESS_0
        @(posedge clk); #1;  // ACCESS_0→ACCESS_1
        @(posedge clk); #1;  // ACCESS_1→ACCESS_2
        @(posedge clk); #1;  // ACCESS_2→ACCESS_3
        @(posedge clk); #1;  // ACCESS_3→WRITEBACK
        @(posedge clk); #1;  // WRITEBACK→IDLE, VRF escribe

        read_addr = 5'd3; #1;
        $display("  vregisters[3] tras carga:");
        check(read_data, {32'h9ABC_DEF0, 32'h1234_5678, 32'hCAFE_BABE, 32'hDEAD_BEEF});

        // =================================================================
        // TEST 2: VLE32.v v5, (x1)  base=20 → vregisters[5]
        //   Instruccion: 32'h0200_E287  (rs1=x1, vd=v5)
        //   Esperado: {0x00000004, 0x00000003, 0x00000002, 0x00000001}
        // =================================================================
        @(posedge clk); #1;
        $display("\n[TEST 2] VLE32.v v5, (x1)  base=20 → vregisters[5]");
        int_rf[1] = 32'd20;
        du_i_instr = 32'h0200_E287;
        @(posedge clk); #1; du_i_instr = 32'h0000_0013;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;

        read_addr = 5'd5; #1;
        $display("  vregisters[5] tras carga:");
        check(read_data, {32'h0000_0004, 32'h0000_0003, 32'h0000_0002, 32'h0000_0001});

        // =================================================================
        // TEST 3: VSE32.v v3, (x1)  base=40
        //   Instruccion: 32'h0200_E1A7  (rs1=x1, vs3=v3, mop=00)
        //   Escribe vregisters[3] en mem[40..52]
        // =================================================================
        @(posedge clk); #1;
        $display("\n[TEST 3] VSE32.v v3, (x1)  base=40 → DCache[40..52]");
        int_rf[1] = 32'd40;
        du_i_instr = 32'h0200_E1A7;
        @(posedge clk); #1; du_i_instr = 32'h0000_0013;
        @(posedge clk); #1;  // IDLE→SWRITE_0, captura vs3
        @(posedge clk); #1;  // SWRITE_0→SWRITE_1, mem[40] escrito
        @(posedge clk); #1;  // SWRITE_1→SWRITE_2, mem[44] escrito
        @(posedge clk); #1;  // SWRITE_2→SWRITE_3, mem[48] escrito
        @(posedge clk); #1;  // SWRITE_3→IDLE,     mem[52] escrito

        #1;
        $display("  DCache tras store de v3:");
        $display("    mem[40]:  "); check(mem[40],  32'hDEAD_BEEF);
        $display("    mem[44]:  "); check(mem[44],  32'hCAFE_BABE);
        $display("    mem[48]:  "); check(mem[48],  32'h1234_5678);
        $display("    mem[52]:  "); check(mem[52],  32'h9ABC_DEF0);

        // =================================================================
        // TEST 4: VSE32.v v5, (x1)  base=60
        //   Instruccion: 32'h0200_E2A7  (rs1=x1, vs3=v5)
        //   Escribe vregisters[5] en mem[60..72]
        // =================================================================
        @(posedge clk); #1;
        $display("\n[TEST 4] VSE32.v v5, (x1)  base=60 → DCache[60..72]");
        int_rf[1] = 32'd60;
        du_i_instr = 32'h0200_E2A7;
        @(posedge clk); #1; du_i_instr = 32'h0000_0013;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;

        #1;
        $display("  DCache tras store de v5:");
        $display("    mem[60]:  "); check(mem[60],  32'h0000_0001);
        $display("    mem[64]:  "); check(mem[64],  32'h0000_0002);
        $display("    mem[68]:  "); check(mem[68],  32'h0000_0003);
        $display("    mem[72]:  "); check(mem[72],  32'h0000_0004);

        // =================================================================
        // TEST 5: VLSE32.v v7, (x1), x2  base=100, stride=4
        //   Instruccion: 32'h0A02_E387  (rs1=x1, rs2=x2, mop=10, vd=v7)
        //   Accede: mem[100], mem[104], mem[108], mem[112]
        //   Esperado en vregisters[7]:
        //   {0xD4D4D4D4, 0xC3C3C3C3, 0xB2B2B2B2, 0xA1A1A1A1}
        // =================================================================
        @(posedge clk); #1;
        $display("\n[TEST 5] VLSE32.v v7, (x1), x2  base=100, stride=4 → vregisters[7]");
        int_rf[1] = 32'd100;
        int_rf[2] = 32'd4;
        du_i_instr = 32'h0A20_E387;
        @(posedge clk); #1; du_i_instr = 32'h0000_0013;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;

        read_addr = 5'd7; #1;
        $display("  vregisters[7] tras carga strided:");
        check(read_data, {32'hD4D4_D4D4, 32'hC3C3_C3C3, 32'hB2B2_B2B2, 32'hA1A1_A1A1});

        // =================================================================
        // TEST 6: VSSE32.v v3, (x1), x2  base=80, stride=8
        //   Instruccion: 32'h0A02_E1A7  (rs1=x1, rs2=x2, mop=10, vs3=v3)
        //   Escribe vregisters[3] en mem[80], mem[88], mem[96], mem[104]
        // =================================================================
        @(posedge clk); #1;
        $display("\n[TEST 6] VSSE32.v v3, (x1), x2  base=80, stride=8 → DCache[80,88,96,104]");
        int_rf[1] = 32'd80;
        int_rf[2] = 32'd8;
        du_i_instr = 32'h0A20_E1A7;
        @(posedge clk); #1; du_i_instr = 32'h0000_0013;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;

        #1;
        $display("  DCache tras store strided de v3:");
        $display("    mem[80]:   "); check(mem[80],  32'hDEAD_BEEF);
        $display("    mem[88]:   "); check(mem[88],  32'hCAFE_BABE);
        $display("    mem[96]:   "); check(mem[96],  32'h1234_5678);
        $display("    mem[104]:  "); check(mem[104], 32'h9ABC_DEF0);

        // Pre-inicializar memoria para test de offsets (indexed)
        mem[112] = 32'd0;
        mem[116] = 32'd8;
        mem[120] = 32'd4;
        mem[124] = 32'd12;

        // =================================================================
        // TEST 7: VLE32.v v2, (x1)  base=112  — carga offsets en v2
        //   Instruccion: 32'h0200_E107  (rs1=x1, vd=v2)
        //   v2 = {12, 4, 8, 0}
        // =================================================================
        @(posedge clk); #1;
        $display("\n[TEST 7] VLE32.v v2, (x1)  base=112 → v2={12,4,8,0} (prep indexed)");
        int_rf[1] = 32'd112;
        du_i_instr = 32'h0200_E107;
        @(posedge clk); #1; du_i_instr = 32'h0000_0013;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;

        read_addr = 5'd2; #1;
        $display("  vregisters[2] tras carga:");
        check(read_data, {32'd12, 32'd4, 32'd8, 32'd0});

        // =================================================================
        // TEST 8: vluxei32.v v9, (x1), v2  base=20
        //   Instruccion: 32'h0620_E487  (rs1=x1, vs2=v2, mop=01, vd=v9)
        //   offsets en v2: {0, 8, 4, 12}
        //   accede: mem[20+0]=1, mem[20+8]=3, mem[20+4]=2, mem[20+12]=4
        //   esperado v9 = {4, 2, 3, 1}
        // =================================================================
        @(posedge clk); #1;
        $display("\n[TEST 8] vluxei32.v v9, (x1), v2  base=20 → v9={4,2,3,1}");
        int_rf[1] = 32'd20;
        du_i_instr = 32'h0620_E487;
        @(posedge clk); #1; du_i_instr = 32'h0000_0013;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;

        read_addr = 5'd9; #1;
        $display("  vregisters[9] tras carga indexed:");
        check(read_data, {32'd4, 32'd2, 32'd3, 32'd1});

        // =================================================================
        // TEST 9: vsuxei32.v v9, (x1), v2  base=70
        //   Instruccion: 32'h0620_E4A7  (rs1=x1, vs2=v2, mop=01, vs3=v9)
        //   offsets v2: {0, 8, 4, 12} → escribe en mem[70,78,74,82]
        //   v9 = {4,2,3,1} → mem[70]=1, mem[74]=3, mem[78]=2, mem[82]=4
        // =================================================================
        @(posedge clk); #1;
        $display("\n[TEST 9] vsuxei32.v v9, (x1), v2  base=70 → DCache[70,78,74,82]");
        int_rf[1] = 32'd70;
        du_i_instr = 32'h0620_E4A7;
        @(posedge clk); #1; du_i_instr = 32'h0000_0013;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;

        #1;
        $display("  DCache tras store indexed de v9:");
        $display("    mem[70]:  "); check(mem[70], 32'd1);
        $display("    mem[78]:  "); check(mem[78], 32'd3);
        $display("    mem[74]:  "); check(mem[74], 32'd2);
        $display("    mem[82]:  "); check(mem[82], 32'd4);

        // =================================================================
        $display("\n=== Resultado: %0d PASS  %0d FAIL ===", pass, fail);
        #100;
        $finish;
    end

endmodule
