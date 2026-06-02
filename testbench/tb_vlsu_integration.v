// Testbench de integracion: VLSU + banco de registros vectoriales
// Verifica el flujo completo: memoria → VLSU → vregisters
// Se instancian vlsu y vregisters y se conectan directamente.
//
// Nota: vregisters protege v0 de escritura (addr_w != 0).
// Por esta razon VLM no se prueba aqui hasta resolver ese conflicto.

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

    wire [31:0]  o_mem_addr;
    wire         o_mem_read_en;
    reg  [31:0]  i_mem_rdata;

    wire         o_vrf_we;
    wire [4:0]   o_vrf_addr;
    wire [127:0] o_vrf_data;

    wire         o_busy;
    wire         o_scoreboard_set;
    wire         o_scoreboard_clr;
    wire [4:0]   o_vd;

    // -------------------------------------------------------------------------
    // Señales del banco de registros vectoriales
    // -------------------------------------------------------------------------
    reg  [4:0]   read_addr;
    wire [127:0] read_data;

    // -------------------------------------------------------------------------
    // Modelo de memoria combinacional (simula DCache)
    // -------------------------------------------------------------------------
    reg [31:0] mem [0:127];

    always @(*) begin
        if (o_mem_read_en)
            i_mem_rdata = mem[o_mem_addr[6:0]];
        else
            i_mem_rdata = 32'b0;
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
        .o_mem_addr       (o_mem_addr),
        .o_mem_read_en    (o_mem_read_en),
        .i_mem_rdata      (i_mem_rdata),
        .o_vrf_we         (o_vrf_we),
        .o_vrf_addr       (o_vrf_addr),
        .o_vrf_data       (o_vrf_data),
        .o_busy           (o_busy),
        .o_scoreboard_set (o_scoreboard_set),
        .o_scoreboard_clr (o_scoreboard_clr),
        .o_vd             (o_vd)
    );

    // -------------------------------------------------------------------------
    // Instancia del banco de registros vectoriales
    // Puerto de escritura conectado directamente al VLSU
    // Puerto de lectura (addr_a) disponible para verificacion
    // -------------------------------------------------------------------------
    vregisters vrf (
        .clk     (clk),
        .rst     (rst),
        .we      (o_vrf_we),
        .addr_w  (o_vrf_addr),
        .data_in (o_vrf_data),
        .addr_a  (read_addr),
        .addr_b  (5'b0),
        .data_a  (read_data),
        .data_b  ()
    );

    // -------------------------------------------------------------------------
    // Contadores de resultado
    // -------------------------------------------------------------------------
    integer pass = 0, fail = 0;

    // monitor interno: imprime estado y registros clave en cada flanco de subida
    always @(posedge clk) begin
        $display("[t=%0t] state=%0d vd_reg=%0d base=%0d i_valid=%b vrf_we=%b vrf_addr=%0d",
                 $time, lsu.state, lsu.vd_reg, lsu.base_addr_reg,
                 i_valid, o_vrf_we, o_vrf_addr);
    end

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

        // Inicializar memoria
        // Test 1 (VLE32.v v3, base=0): words 0, 4, 8, 12
        mem[0]  = 32'hDEAD_BEEF;
        mem[4]  = 32'hCAFE_BABE;
        mem[8]  = 32'h1234_5678;
        mem[12] = 32'h9ABC_DEF0;

        // Test 2 (VLE32.v v5, base=20): words 20, 24, 28, 32
        mem[20] = 32'h0000_0001;
        mem[24] = 32'h0000_0002;
        mem[28] = 32'h0000_0003;
        mem[32] = 32'h0000_0004;

        // Reset
        i_valid = 0; i_instr = 0; i_base_addr = 0; read_addr = 0;
        rst = 1;
        @(posedge clk); @(posedge clk);
        #1; rst = 0;
        @(posedge clk); #1;

        // =================================================================
        // TEST 1: VLE32.v v3, (x0)  base=0
        //   Instruccion: 32'h0200_6187
        //   Esperado en vregisters[3]:
        //   {0x9ABCDEF0, 0x12345678, 0xCAFEBABE, 0xDEADBEEF}
        // =================================================================
        $display("\n[TEST 1] VLE32.v v3, (x0)  base=0 → vregisters[3]");

        // asignar entradas #1 despues del flanco para evitar race condition
        i_instr     = 32'h0200_6187;
        i_base_addr = 32'd0;
        i_valid     = 1;
        @(posedge clk); #1; // IDLE → ACCESS_0
        i_valid = 0;

        // esperar los 4 accesos + WRITEBACK
        @(posedge clk); #1; // ACCESS_0 → ACCESS_1
        @(posedge clk); #1; // ACCESS_1 → ACCESS_2
        @(posedge clk); #1; // ACCESS_2 → ACCESS_3
        @(posedge clk); #1; // ACCESS_3 → WRITEBACK
        @(posedge clk); #1; // WRITEBACK → IDLE  (escritura en vrf ocurre aqui)

        // leer de vuelta desde el banco de registros
        read_addr = 5'd3;
        #1;

        $display("  Leyendo vregisters[3] tras la carga:");
        $display("    vrf[3][127:0]:  ");
        check(read_data, {32'h9ABC_DEF0, 32'h1234_5678, 32'hCAFE_BABE, 32'hDEAD_BEEF});

        // =================================================================
        // TEST 2: VLE32.v v5, (x0)  base=20
        //   Instruccion: 32'h0200_6287
        //   Esperado en vregisters[5]:
        //   {0x00000004, 0x00000003, 0x00000002, 0x00000001}
        // =================================================================
        @(posedge clk); #1;
        $display("\n[TEST 2] VLE32.v v5, (x0)  base=20 → vregisters[5]");

        i_instr     = 32'h0200_6287;
        i_base_addr = 32'd20;
        i_valid     = 1;
        @(posedge clk); #1; // IDLE → ACCESS_0
        i_valid = 0;

        @(posedge clk); #1; // ACCESS_0 → ACCESS_1
        @(posedge clk); #1; // ACCESS_1 → ACCESS_2
        @(posedge clk); #1; // ACCESS_2 → ACCESS_3
        @(posedge clk); #1; // ACCESS_3 → WRITEBACK
        @(posedge clk); #1; // WRITEBACK → IDLE

        read_addr = 5'd5;
        #1;

        $display("  Leyendo vregisters[5] tras la carga:");
        $display("    vrf[5][127:0]:  ");
        check(read_data, {32'h0000_0004, 32'h0000_0003, 32'h0000_0002, 32'h0000_0001});

        // =================================================================
        // TEST 3: verificar que vregisters[3] no fue modificado por el test 2
        // =================================================================
        $display("\n[TEST 3] vregisters[3] no modificado por test 2");
        read_addr = 5'd3;
        #1;
        $display("    vrf[3] intacto: ");
        check(read_data, {32'h9ABC_DEF0, 32'h1234_5678, 32'hCAFE_BABE, 32'hDEAD_BEEF});

        // =================================================================
        $display("\n=== Resultado: %0d PASS  %0d FAIL ===", pass, fail);
        $finish;
    end

endmodule
