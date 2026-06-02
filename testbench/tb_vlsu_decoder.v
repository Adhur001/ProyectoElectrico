// Testbench para vlsu_decoder
// Verifica los tres tipos de carga: unit-stride, registro completo y mascara
// Tambien prueba la deteccion de opcode invalido y el bit vm (con/sin mascara)

`timescale 1ns/1ps

module tb_vlsu;

    reg  [31:0] instr;

    wire [4:0]  vd;
    wire [4:0]  rs1;
    wire [2:0]  width;
    wire        vm;
    wire [4:0]  lumop;
    wire [1:0]  mop;
    wire [2:0]  nf;
    wire        is_unit_stride;
    wire        is_whole_reg;
    wire        is_mask_load;
    wire        valid_opcode;

    // Instancia del decodificador bajo prueba
    vlsu_decoder dut (
        .i_instr          (instr),
        .o_vd             (vd),
        .o_rs1            (rs1),
        .o_width          (width),
        .o_vm             (vm),
        .o_lumop          (lumop),
        .o_mop            (mop),
        .o_nf             (nf),
        .o_is_unit_stride (is_unit_stride),
        .o_is_whole_reg   (is_whole_reg),
        .o_is_mask_load   (is_mask_load),
        .o_valid_opcode   (valid_opcode)
    );

    integer pass = 0, fail = 0;

    // Tarea auxiliar: compara un campo de salida contra su valor esperado
    task check_field;
        input [63:0] got;
        input [63:0] expected;
        input [95:0] name;
        begin
            if (got === expected) begin
                $display("  PASS: %s = %0d", name, got);
                pass = pass + 1;
            end else begin
                $display("  FAIL: %s  obtenido=%0d  esperado=%0d", name, got, expected);
                fail = fail + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_vlsu.vcd");
        $dumpvars(0, tb_vlsu);

        $display("=== tb_vlsu: Decodificador VLSU ===\n");

        // -----------------------------------------------------------
        // TEST 1: VLE32.v v3, (x1)  — unit-stride, EEW=32, sin mascara
        //   Campos: nf=000 mew=0 mop=00 vm=1 lumop=00000
        //           rs1=00001 width=110 vd=00011 opcode=0000111
        //   Hex: 32'h0200_E187
        // -----------------------------------------------------------
        instr = 32'h0200_E187;
        #1;
        $display("[TEST 1] VLE32.v v3, (x1)  (unit-stride, EEW=32, sin mascara)");
        check_field(valid_opcode,   1,        "valid_opcode  ");
        check_field(is_unit_stride, 1,        "is_unit_stride");
        check_field(is_whole_reg,   0,        "is_whole_reg  ");
        check_field(is_mask_load,   0,        "is_mask_load  ");
        check_field(vd,             3,        "vd            ");
        check_field(rs1,            1,        "rs1           ");
        check_field(width,    3'b110,         "width         ");
        check_field(vm,             1,        "vm            ");
        check_field(lumop,   5'b00000,        "lumop         ");
        check_field(mop,      2'b00,          "mop           ");

        // -----------------------------------------------------------
        // TEST 2: VL1RE32.v v5, (x2)  — carga de registro completo
        //   Campos: nf=000 mew=0 mop=00 vm=1 lumop=01000
        //           rs1=00010 width=110 vd=00101 opcode=0000111
        //   Hex: 32'h0281_6287
        // -----------------------------------------------------------
        instr = 32'h0281_6287;
        #1;
        $display("\n[TEST 2] VL1RE32.v v5, (x2)  (registro completo)");
        check_field(valid_opcode,   1,        "valid_opcode  ");
        check_field(is_unit_stride, 0,        "is_unit_stride");
        check_field(is_whole_reg,   1,        "is_whole_reg  ");
        check_field(is_mask_load,   0,        "is_mask_load  ");
        check_field(vd,             5,        "vd            ");
        check_field(rs1,            2,        "rs1           ");
        check_field(lumop,   5'b01000,        "lumop         ");

        // -----------------------------------------------------------
        // TEST 3: VLM.v v0, (x3)  — carga de mascara
        //   Campos: nf=000 mew=0 mop=00 vm=1 lumop=01011
        //           rs1=00011 width=000 vd=00000 opcode=0000111
        //   Hex: 32'h02B1_8007
        // -----------------------------------------------------------
        instr = 32'h02B1_8007;
        #1;
        $display("\n[TEST 3] VLM.v v0, (x3)  (carga de mascara)");
        check_field(valid_opcode,   1,        "valid_opcode  ");
        check_field(is_unit_stride, 0,        "is_unit_stride");
        check_field(is_whole_reg,   0,        "is_whole_reg  ");
        check_field(is_mask_load,   1,        "is_mask_load  ");
        check_field(vd,             0,        "vd            ");
        check_field(rs1,            3,        "rs1           ");
        check_field(width,    3'b000,         "width         ");
        check_field(lumop,   5'b01011,        "lumop         ");

        // -----------------------------------------------------------
        // TEST 4: VLE32.v v7, (x4), v0.t  — unit-stride con mascara
        //   Campos: nf=000 mew=0 mop=00 vm=0 lumop=00000
        //           rs1=00100 width=110 vd=00111 opcode=0000111
        //   Hex: 32'h0002_6387
        // -----------------------------------------------------------
        instr = 32'h0002_6387;
        #1;
        $display("\n[TEST 4] VLE32.v v7, (x4), v0.t  (unit-stride, con mascara)");
        check_field(valid_opcode,   1,        "valid_opcode  ");
        check_field(is_unit_stride, 1,        "is_unit_stride");
        check_field(vm,             0,        "vm            ");
        check_field(vd,             7,        "vd            ");
        check_field(rs1,            4,        "rs1           ");

        // -----------------------------------------------------------
        // TEST 5: opcode invalido — ADDI x0, x0, 0 (NOP de RISC-V)
        //   Hex: 32'h0000_0013  opcode=0010011 (no es carga vectorial)
        // -----------------------------------------------------------
        instr = 32'h0000_0013;
        #1;
        $display("\n[TEST 5] Opcode invalido (NOP 0x00000013)");
        check_field(valid_opcode,   0,        "valid_opcode  ");
        check_field(is_unit_stride, 0,        "is_unit_stride");
        check_field(is_whole_reg,   0,        "is_whole_reg  ");
        check_field(is_mask_load,   0,        "is_mask_load  ");

        // -----------------------------------------------------------
        $display("\n=== Resultado: %0d PASS  %0d FAIL ===", pass, fail);
        $finish;
    end

endmodule
