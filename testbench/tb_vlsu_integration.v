// Testbench de integracion: VLSU + banco de registros vectoriales + DCache
// Verifica el flujo completo de cargas y stores vectoriales

`timescale 1ns/1ps

module tb_vlsu_integration;

    // -------------------------------------------------------------------------
    // Reloj y reset
    // -------------------------------------------------------------------------
    reg clk, rst;
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Señales del VLSU
    // -------------------------------------------------------------------------
    reg         i_valid;
    reg  [31:0] i_instr;
    reg  [31:0] i_base_addr;
    reg  [31:0] i_stride;

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
    // Instancia del VLSU
    // -------------------------------------------------------------------------
    vlsu lsu (
        .clk              (clk),
        .rst              (rst),
        .i_valid          (i_valid),
        .i_instr          (i_instr),
        .i_base_addr      (i_base_addr),
        .i_stride         (i_stride),
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
    // Puerto de escritura: conectado al VLSU (cargas)
    // Puerto de lectura A: conectado al VLSU (stores, via o_vs3)
    // Puerto de lectura B: disponible para verificacion
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
        .addr_c  (5'b0),         // no usado en este testbench
        .addr_d  (o_vs2),        // VLSU: lectura de vs2 (indexed offsets)
        .data_a  (i_vrf_rdata),  // dato de vs3 → VLSU
        .data_b  (read_data),
        .data_c  (),
        .data_d  (i_vrf_offset)  // offsets de vs2 → VLSU
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

        // Test 5 (VLSE32 strided, base=100, stride=4)
        mem[100] = 32'hA1A1_A1A1;
        mem[104] = 32'hB2B2_B2B2;
        mem[108] = 32'hC3C3_C3C3;
        mem[112] = 32'hD4D4_D4D4;

        i_valid = 0; i_instr = 0; i_base_addr = 0; i_stride = 0; read_addr = 0;
        rst = 1;
        @(posedge clk); @(posedge clk);
        #1; rst = 0;
        @(posedge clk); #1;

        // =================================================================
        // TEST 1: VLE32.v v3, (x0)  base=0 → vregisters[3]
        //   Instruccion: 32'h0200_6187
        //   Esperado: {0x9ABCDEF0, 0x12345678, 0xCAFEBABE, 0xDEADBEEF}
        // =================================================================
        $display("\n[TEST 1] VLE32.v v3, (x0)  base=0 → vregisters[3]");

        i_instr     = 32'h0200_6187;
        i_base_addr = 32'd0;
        i_valid     = 1;
        @(posedge clk); #1; i_valid = 0;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1; // WRITEBACK → IDLE

        read_addr = 5'd3; #1;
        $display("  vregisters[3] tras carga:");
        $display("    vrf[3][127:0]:  ");
        check(read_data, {32'h9ABC_DEF0, 32'h1234_5678, 32'hCAFE_BABE, 32'hDEAD_BEEF});

        // =================================================================
        // TEST 2: VLE32.v v5, (x0)  base=20 → vregisters[5]
        //   Instruccion: 32'h0200_6287
        //   Esperado: {0x00000004, 0x00000003, 0x00000002, 0x00000001}
        // =================================================================
        @(posedge clk); #1;
        $display("\n[TEST 2] VLE32.v v5, (x0)  base=20 → vregisters[5]");

        i_instr     = 32'h0200_6287;
        i_base_addr = 32'd20;
        i_valid     = 1;
        @(posedge clk); #1; i_valid = 0;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;

        read_addr = 5'd5; #1;
        $display("  vregisters[5] tras carga:");
        $display("    vrf[5][127:0]:  ");
        check(read_data, {32'h0000_0004, 32'h0000_0003, 32'h0000_0002, 32'h0000_0001});

        // =================================================================
        // TEST 3: VSE32.v v3, (x0)  base=40
        //   Instruccion: 32'h0200_61A7
        //   Escribe vregisters[3] = {0x9ABCDEF0,...,0xDEADBEEF} en mem[40..52]
        // =================================================================
        @(posedge clk); #1;
        $display("\n[TEST 3] VSE32.v v3, (x0)  base=40 → DCache[40..52]");

        i_instr     = 32'h0200_61A7;
        i_base_addr = 32'd40;
        i_valid     = 1;
        @(posedge clk); #1; i_valid = 0;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1; // SWRITE_3 → IDLE

        #1;
        $display("  DCache tras store de v3:");
        $display("    mem[40]:  "); check(mem[40],  32'hDEAD_BEEF);
        $display("    mem[44]:  "); check(mem[44],  32'hCAFE_BABE);
        $display("    mem[48]:  "); check(mem[48],  32'h1234_5678);
        $display("    mem[52]:  "); check(mem[52],  32'h9ABC_DEF0);

        // =================================================================
        // TEST 4: VSE32.v v5, (x0)  base=60
        //   Instruccion: 32'h0200_62A7
        //   Escribe vregisters[5] = {0x4, 0x3, 0x2, 0x1} en mem[60..72]
        // =================================================================
        @(posedge clk); #1;
        $display("\n[TEST 4] VSE32.v v5, (x0)  base=60 → DCache[60..72]");

        i_instr     = 32'h0200_62A7;
        i_base_addr = 32'd60;
        i_valid     = 1;
        @(posedge clk); #1; i_valid = 0;
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
        // TEST 5: VLSE32.v v7, (x0), stride=4  base=100
        //   Accede: mem[100], mem[104], mem[108], mem[112]
        //   Esperado en vregisters[7]:
        //   {0xD4D4D4D4, 0xC3C3C3C3, 0xB2B2B2B2, 0xA1A1A1A1}
        //   Instruccion: VLSE32.v v7,(x0),x0  mop=10 vd=7 rs1=0 rs2=0
        //   Hex: 32'h0A00_6387
        // =================================================================
        @(posedge clk); #1;
        $display("\n[TEST 5] VLSE32.v v7, (x0), stride=4  base=100 → vregisters[7]");

        i_instr     = 32'h0A00_6387;  // VLSE32.v v7, (x0), x0
        i_base_addr = 32'd100;
        i_stride    = 32'd4;
        i_valid     = 1;
        @(posedge clk); #1; i_valid = 0;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;

        read_addr = 5'd7; #1;
        $display("  vregisters[7] tras carga strided:");
        $display("    vrf[7][127:0]:  ");
        check(read_data, {32'hD4D4_D4D4, 32'hC3C3_C3C3, 32'hB2B2_B2B2, 32'hA1A1_A1A1});

        // =================================================================
        // TEST 6: VSSE32.v v3, (x0), stride=8  base=80
        //   Instruccion: 32'h0A00_61A7 — VSSE32.v v3,(x0),x0
        //   Escribe vregisters[3] en mem[80], mem[88], mem[96], mem[104]
        //   vregisters[3] = {0x9ABCDEF0, 0x12345678, 0xCAFEBABE, 0xDEADBEEF}
        // =================================================================
        @(posedge clk); #1;
        $display("\n[TEST 6] VSSE32.v v3, (x0), stride=8  base=80 → DCache[80,88,96,104]");

        i_instr     = 32'h0A00_61A7;  // VSSE32.v v3, (x0), x0
        i_base_addr = 32'd80;
        i_stride    = 32'd8;
        i_valid     = 1;
        @(posedge clk); #1; i_valid = 0;
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

        // Re-inicializa mem[112] para indexed (test 5 lo tenia en D4D4D4D4)
        // Esta asignacion ocurre en tiempo de simulacion, despues de que test 5 ya leyo mem[112]
        mem[112] = 32'd0;
        mem[116] = 32'd8;
        mem[120] = 32'd4;
        mem[124] = 32'd12;

        // =================================================================
        // TEST 7: VLE32.v v2, (x0)  base=112  — carga offsets en v2
        //   v2 = {12, 4, 8, 0}   (offsets para accesos desordenados)
        //   Instruccion: 32'h02006107
        // =================================================================
        @(posedge clk); #1;
        $display("\n[TEST 7] VLE32.v v2, (x0)  base=112 → v2={12,4,8,0} (prep indexed)");

        i_instr     = 32'h02006107;
        i_base_addr = 32'd112;
        i_valid     = 1;
        @(posedge clk); #1; i_valid = 0;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;

        read_addr = 5'd2; #1;
        $display("  vregisters[2] tras carga:");
        check(read_data, {32'd12, 32'd4, 32'd8, 32'd0});

        // =================================================================
        // TEST 8: vluxei32.v v9, (x0), v2  base=20
        //   offsets en v2: {0, 8, 4, 12}
        //   accede: mem[20+0]=1, mem[20+8]=3, mem[20+4]=2, mem[20+12]=4
        //   esperado v9 = {4, 2, 3, 1}
        //   Instruccion: 32'h06206487
        // =================================================================
        @(posedge clk); #1;
        $display("\n[TEST 8] vluxei32.v v9, (x0), v2  base=20 → v9={4,2,3,1}");

        i_instr     = 32'h06206487;
        i_base_addr = 32'd20;
        i_valid     = 1;
        @(posedge clk); #1; i_valid = 0;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;

        read_addr = 5'd9; #1;
        $display("  vregisters[9] tras carga indexed:");
        check(read_data, {32'd4, 32'd2, 32'd3, 32'd1});

        // =================================================================
        // TEST 9: vsuxei32.v v9, (x0), v2  base=70
        //   offsets en v2: {0, 8, 4, 12} → escribe en mem[70,78,74,82]
        //   v9 = {4,2,3,1} → mem[70]=1, mem[74]=3, mem[78]=2, mem[82]=4
        //   Instruccion: 32'h062064A7
        // =================================================================
        @(posedge clk); #1;
        $display("\n[TEST 9] vsuxei32.v v9, (x0), v2  base=70 → DCache[70,78,74,82]");

        i_instr     = 32'h062064A7;
        i_base_addr = 32'd70;
        i_valid     = 1;
        @(posedge clk); #1; i_valid = 0;
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
