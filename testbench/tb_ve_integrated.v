`timescale 1ns/1ps

module tb_ve_integrated;

reg        clk;
reg        rst;
reg        i_imem_wen;
reg [31:0] i_imem_addr;
reg [31:0] i_imem_data;

integer pass_count;
integer fail_count;

ve_integrated dut (
    .clk        (clk),
    .rst        (rst),
    .i_imem_wen (i_imem_wen),
    .i_imem_addr(i_imem_addr),
    .i_imem_data(i_imem_data)
);

initial clk = 0;
always #5 clk = ~clk;

task check;
    input [127:0] got;
    input [127:0] exp;
    input [255:0] name;
    begin
        if (got === exp) begin
            $display("PASS: %s", name);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL: %s  got=%h  exp=%h", name, got, exp);
            fail_count = fail_count + 1;
        end
    end
endtask

initial begin
    $dumpfile("tb_ve_integrated.vcd");
    $dumpvars(0, tb_ve_integrated);

    pass_count = 0;
    fail_count = 0;

    rst         = 1;
    i_imem_wen  = 0;
    i_imem_addr = 0;
    i_imem_data = 0;

    @(posedge clk); #1;
    @(posedge clk); #1;

    // ----------------------------------------------------------------
    // Cargar 64 instrucciones en ICache (direccionadas por palabra 0..63)
    // ----------------------------------------------------------------
    i_imem_wen = 1;

    // [0]  addi x3, x0, 5
    i_imem_addr =  0; i_imem_data = 32'h00500193; @(posedge clk); #1;
    // [1]  addi x4, x0, 10
    i_imem_addr =  1; i_imem_data = 32'h00A00213; @(posedge clk); #1;
    // [2]  addi x5, x0, 42
    i_imem_addr =  2; i_imem_data = 32'h02A00293; @(posedge clk); #1;
    // [3..7]  nop x5 (espera a que addi x5 llegue a WB antes de sw)
    i_imem_addr =  3; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr =  4; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr =  5; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr =  6; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr =  7; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [8]  sw x5, 0(x0)  ->  DCache[word 0] = 42
    i_imem_addr =  8; i_imem_data = 32'h00502023; @(posedge clk); #1;
    // [9..13]  nop x5 (espera a que el store se confirme antes del load)
    i_imem_addr =  9; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 10; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 11; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 12; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 13; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [14]  lw x6, 0(x0)  ->  x6 = DCache[word 0] = 42
    i_imem_addr = 14; i_imem_data = 32'h00002303; @(posedge clk); #1;
    // [15..19]  nop x5
    i_imem_addr = 15; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 16; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 17; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 18; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 19; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [20]  vadd v3, v1, v2  (funct7=0, rs2=v2, rs1=v1, funct3=000, rd=v3, op=1010111)
    i_imem_addr = 20; i_imem_data = 32'h002081D7; @(posedge clk); #1;
    // [21..24]  nop x4
    i_imem_addr = 21; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 22; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 23; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 24; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [25]  vsub v4, v2, v1  (funct7=0100000, rs2=v1, rs1=v2, funct3=000, rd=v4)
    //       Resultado: rs1-rs2 = v2-v1 = 200-100 = 100
    i_imem_addr = 25; i_imem_data = 32'h40110257; @(posedge clk); #1;
    // [26..29]  nop x4
    i_imem_addr = 26; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 27; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 28; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 29; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [30]  vand v5, v1, v2  (funct7=0, rs2=v2, rs1=v1, funct3=111, rd=v5)
    //       Resultado: 100&200 = 0x64&0xC8 = 0x40 = 64
    i_imem_addr = 30; i_imem_data = 32'h0020F2D7; @(posedge clk); #1;
    // [31..34]  nop x4
    i_imem_addr = 31; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 32; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 33; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 34; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [35]  vxor v6, v1, v2  (funct7=0, rs2=v2, rs1=v1, funct3=100, rd=v6)
    //       Resultado: 100^200 = 0x64^0xC8 = 0xAC = 172
    i_imem_addr = 35; i_imem_data = 32'h0020C357; @(posedge clk); #1;
    // [36..40]  nop x5 (espera a que addi x1 sea necesario)
    i_imem_addr = 36; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 37; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 38; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 39; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 40; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [41]  addi x1, x0, 16  (direccion base en bytes para vle32)
    i_imem_addr = 41; i_imem_data = 32'h01000093; @(posedge clk); #1;
    // [42..46]  nop x5 (espera a que x1 llegue a WB antes de que vle32 lo lea en decode)
    i_imem_addr = 42; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 43; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 44; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 45; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 46; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [47]  vle32 v8, (x1)  ->  v8 = {DCache[7],DCache[6],DCache[5],DCache[4]}
    //       = {444, 333, 222, 111}
    i_imem_addr = 47; i_imem_data = 32'h0200E407; @(posedge clk); #1;
    // [48..54]  nop x7 (2 fases LSU + vaciado del pipeline)
    i_imem_addr = 48; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 49; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 50; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 51; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 52; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 53; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 54; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [55]  addi x1, x0, 32  (direccion base en bytes para vse32)
    i_imem_addr = 55; i_imem_data = 32'h02000093; @(posedge clk); #1;
    // [56..60]  nop x5 (espera a que x1=32 llegue a WB antes de que vse32 lo lea en decode)
    i_imem_addr = 56; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 57; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 58; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 59; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 60; i_imem_data = 32'h00000013; @(posedge clk); #1;
    // [61]  vse32 v9, (x1)  ->  DCache[8..11] = {666,777,888,999}
    i_imem_addr = 61; i_imem_data = 32'h0200E4A7; @(posedge clk); #1;
    // [62..63]  nop x2
    i_imem_addr = 62; i_imem_data = 32'h00000013; @(posedge clk); #1;
    i_imem_addr = 63; i_imem_data = 32'h00000013; @(posedge clk); #1;

    i_imem_wen = 0;

    // Dos ciclos extra con i_we=0 para permitir que ICache se estabilice en modo lectura
    @(posedge clk); #1;
    @(posedge clk); #1;

    // ----------------------------------------------------------------
    // Desactivar reset; inicializar inmediatamente VRF y DCache antes
    // del siguiente flanco positivo para que el reset secuencial no los sobrescriba.
    // ----------------------------------------------------------------
    rst = 0;

    // v1 = {100,100,100,100}, v2 = {200,200,200,200}
    dut.vext.vregfile.regs[1] = {4{32'd100}};
    dut.vext.vregfile.regs[2] = {4{32'd200}};
    // Datos fuente de v9 para vse32: elem0=666, elem1=777, elem2=888, elem3=999
    dut.vext.vregfile.regs[9] = {32'd999, 32'd888, 32'd777, 32'd666};

    // Precargar palabras 4..7 de DCache (direcciones en bytes 16..28) para la prueba de vle32
    dut.dmem.pos4 = 32'd111;
    dut.dmem.pos5 = 32'd222;
    dut.dmem.pos6 = 32'd333;
    dut.dmem.pos7 = 32'd444;

    // Ejecutar suficientes ciclos para que todas las instrucciones terminen
    repeat(300) @(posedge clk);

    // ----------------------------------------------------------------
    // Verificaciones
    // ----------------------------------------------------------------

    // 1. ADDI escalar x3 = 5
    check(dut.RF.x3, 32'd5,   "x3 = 5 (addi)");
    // 2. ADDI escalar x4 = 10
    check(dut.RF.x4, 32'd10,  "x4 = 10 (addi)");
    // 3. ADDI escalar x5 = 42
    check(dut.RF.x5, 32'd42,  "x5 = 42 (addi)");
    // 4. SW escalar: DCache[0] debe ser 42
    check(dut.dmem.pos0, 32'd42, "dmem[0] = 42 (scalar store)");
    // 5. LW escalar: x6 cargado desde DCache[0] = 42
    check(dut.RF.x6, 32'd42,  "x6 = 42 (scalar load)");
    // 6. VADD vectorial: v3 = v1+v2 = 100+200 = 300
    check(dut.vext.vregfile.regs[3], {4{32'd300}}, "v3 = {300x4} (vadd)");
    // 7. VSUB vectorial: v4 = v2-v1 = 200-100 = 100
    check(dut.vext.vregfile.regs[4], {4{32'd100}}, "v4 = {100x4} (vsub)");
    // 8. VAND vectorial: v5 = v1&v2 = 100&200 = 64
    check(dut.vext.vregfile.regs[5], {4{32'd64}},  "v5 = {64x4}  (vand)");
    // 9. VXOR vectorial: v6 = v1^v2 = 100^200 = 172
    check(dut.vext.vregfile.regs[6], {4{32'd172}}, "v6 = {172x4} (vxor)");
    // 10. VLE32 vectorial: v8 = {444,333,222,111} desde DCache[4..7]
    check(dut.vext.vregfile.regs[8],
          {32'd444, 32'd333, 32'd222, 32'd111}, "v8 = {444,333,222,111} (vle32)");
    // 11-14. VSE32 vectorial: v9 almacenado en DCache[8..11]
    check(dut.dmem.pos8,  32'd666, "dmem[8]  = 666 (vse32 elem0)");
    check(dut.dmem.pos9,  32'd777, "dmem[9]  = 777 (vse32 elem1)");
    check(dut.dmem.pos10, 32'd888, "dmem[10] = 888 (vse32 elem2)");
    check(dut.dmem.pos11, 32'd999, "dmem[11] = 999 (vse32 elem3)");

    $display("Results: %0d PASS, %0d FAIL", pass_count, fail_count);
    $finish;
end

endmodule
