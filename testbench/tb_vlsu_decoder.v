// Testbench para vlsu_decoder
// Verifica cargas: unit-stride, registro completo, mascara, constant-stride
// Verifica stores: unit-stride, registro completo, mascara, constant-stride
// Verifica deteccion de opcode invalido y bit vm

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

    // cargas
    wire        is_load;
    wire        is_unit_stride;
    wire        is_whole_reg;
    wire        is_mask_load;

    // stores
    wire        is_store;
    wire        is_unit_store;
    wire        is_whole_store;
    wire        is_mask_store;

    // constant-stride
    wire        is_strided_load;
    wire        is_strided_store;

    vlsu_decoder dut (
        .i_instr            (instr),
        .o_vd               (vd),
        .o_rs1              (rs1),
        .o_rs2              (),
        .o_width            (width),
        .o_vm               (vm),
        .o_lumop            (lumop),
        .o_mop              (mop),
        .o_nf               (nf),
        .o_is_load          (is_load),
        .o_is_unit_stride   (is_unit_stride),
        .o_is_whole_reg     (is_whole_reg),
        .o_is_mask_load     (is_mask_load),
        .o_is_store         (is_store),
        .o_is_unit_store    (is_unit_store),
        .o_is_whole_store   (is_whole_store),
        .o_is_mask_store    (is_mask_store),
        .o_is_strided_load  (is_strided_load),
        .o_is_strided_store (is_strided_store)
    );

    integer pass = 0, fail = 0;

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
        // TEST 1: VLE32.v v3, (x1)  — carga unit-stride, sin mascara
        //   nf=000 mew=0 mop=00 vm=1 lumop=00000
        //   rs1=00001 width=110 vd=00011 opcode=0000111
        //   Hex: 32'h0200_E187
        // -----------------------------------------------------------
        instr = 32'h0200_E187;
        #1;
        $display("[TEST 1] VLE32.v v3, (x1)  (carga unit-stride, sin mascara)");
        check_field(is_load,        1,       "is_load       ");
        check_field(is_store,       0,       "is_store      ");
        check_field(is_unit_stride, 1,       "is_unit_stride");
        check_field(is_whole_reg,   0,       "is_whole_reg  ");
        check_field(is_mask_load,   0,       "is_mask_load  ");
        check_field(vd,             3,       "vd            ");
        check_field(rs1,            1,       "rs1           ");
        check_field(width,    3'b110,        "width         ");
        check_field(vm,             1,       "vm            ");
        check_field(lumop,   5'b00000,       "lumop         ");

        // -----------------------------------------------------------
        // TEST 2: VL1RE32.v v5, (x2)  — carga registro completo
        //   lumop=01000  Hex: 32'h0281_6287
        // -----------------------------------------------------------
        instr = 32'h0281_6287;
        #1;
        $display("\n[TEST 2] VL1RE32.v v5, (x2)  (carga registro completo)");
        check_field(is_load,      1,         "is_load       ");
        check_field(is_store,     0,         "is_store      ");
        check_field(is_whole_reg, 1,         "is_whole_reg  ");
        check_field(vd,           5,         "vd            ");
        check_field(rs1,          2,         "rs1           ");
        check_field(lumop,  5'b01000,        "lumop         ");

        // -----------------------------------------------------------
        // TEST 3: VLM.v v0, (x3)  — carga de mascara
        //   lumop=01011  Hex: 32'h02B1_8007
        // -----------------------------------------------------------
        instr = 32'h02B1_8007;
        #1;
        $display("\n[TEST 3] VLM.v v0, (x3)  (carga de mascara)");
        check_field(is_load,      1,         "is_load       ");
        check_field(is_store,     0,         "is_store      ");
        check_field(is_mask_load, 1,         "is_mask_load  ");
        check_field(vd,           0,         "vd            ");
        check_field(rs1,          3,         "rs1           ");
        check_field(width,  3'b000,          "width         ");
        check_field(lumop,  5'b01011,        "lumop         ");

        // -----------------------------------------------------------
        // TEST 4: VSE32.v v3, (x1)  — store unit-stride, sin mascara
        //   nf=000 mew=0 mop=00 vm=1 sumop=00000
        //   rs1=00001 width=110 vs3=00011 opcode=0100111
        //   Hex: 32'h0200_E1A7
        // -----------------------------------------------------------
        instr = 32'h0200_E1A7;
        #1;
        $display("\n[TEST 4] VSE32.v v3, (x1)  (store unit-stride, sin mascara)");
        check_field(is_load,       0,        "is_load       ");
        check_field(is_store,      1,        "is_store      ");
        check_field(is_unit_store, 1,        "is_unit_store ");
        check_field(is_whole_store,0,        "is_whole_store");
        check_field(is_mask_store, 0,        "is_mask_store ");
        check_field(vd,            3,        "vs3           ");
        check_field(rs1,           1,        "rs1           ");
        check_field(width,   3'b110,         "width         ");
        check_field(vm,            1,        "vm            ");
        check_field(lumop,  5'b00000,        "sumop         ");

        // -----------------------------------------------------------
        // TEST 5: VS1R.v v5, (x2)  — store registro completo
        //   sumop=01000  Hex: 32'h0281_62A7
        // -----------------------------------------------------------
        instr = 32'h0281_62A7;
        #1;
        $display("\n[TEST 5] VS1R.v v5, (x2)  (store registro completo)");
        check_field(is_load,       0,        "is_load       ");
        check_field(is_store,      1,        "is_store      ");
        check_field(is_whole_store,1,        "is_whole_store");
        check_field(vd,            5,        "vs3           ");
        check_field(rs1,           2,        "rs1           ");
        check_field(lumop,  5'b01000,        "sumop         ");

        // -----------------------------------------------------------
        // TEST 6: VSM.v v0, (x3)  — store de mascara
        //   sumop=01011  Hex: 32'h02B1_8027
        // -----------------------------------------------------------
        instr = 32'h02B1_8027;
        #1;
        $display("\n[TEST 6] VSM.v v0, (x3)  (store de mascara)");
        check_field(is_load,      0,         "is_load       ");
        check_field(is_store,     1,         "is_store      ");
        check_field(is_mask_store,1,         "is_mask_store ");
        check_field(vd,           0,         "vs3           ");
        check_field(rs1,          3,         "rs1           ");
        check_field(width,  3'b000,          "width         ");
        check_field(lumop,  5'b01011,        "sumop         ");

        // -----------------------------------------------------------
        // TEST 7: VLSE32.v v3, (x1), x2  — carga constant-stride
        //   mop=10, rs2=x2 (stride), vd=v3, rs1=x1
        //   Hex: 32'h0A20_E187
        // -----------------------------------------------------------
        instr = 32'h0A20_E187;
        #1;
        $display("\n[TEST 7] VLSE32.v v3, (x1), x2  (carga constant-stride)");
        check_field(is_load,          1,   "is_load         ");
        check_field(is_store,         0,   "is_store        ");
        check_field(is_strided_load,  1,   "is_strided_load ");
        check_field(is_strided_store, 0,   "is_strided_store");
        check_field(is_unit_stride,   0,   "is_unit_stride  ");
        check_field(vd,               3,   "vd              ");
        check_field(rs1,              1,   "rs1             ");
        check_field(mop,         2'b10,   "mop             ");

        // -----------------------------------------------------------
        // TEST 8: VSSE32.v v3, (x1), x2  — store constant-stride
        //   mop=10, rs2=x2 (stride), vs3=v3, rs1=x1
        //   Hex: 32'h0A20_E1A7
        // -----------------------------------------------------------
        instr = 32'h0A20_E1A7;
        #1;
        $display("\n[TEST 8] VSSE32.v v3, (x1), x2  (store constant-stride)");
        check_field(is_load,          0,   "is_load         ");
        check_field(is_store,         1,   "is_store        ");
        check_field(is_strided_load,  0,   "is_strided_load ");
        check_field(is_strided_store, 1,   "is_strided_store");
        check_field(is_unit_store,    0,   "is_unit_store   ");
        check_field(vd,               3,   "vs3             ");
        check_field(rs1,              1,   "rs1             ");
        check_field(mop,         2'b10,   "mop             ");

        // -----------------------------------------------------------
        // TEST 9: opcode invalido (NOP RISC-V)
        //   Hex: 32'h0000_0013  opcode=0010011
        // -----------------------------------------------------------
        instr = 32'h0000_0013;
        #1;
        $display("\n[TEST 9] Opcode invalido (NOP 0x00000013)");
        check_field(is_load,          0,   "is_load         ");
        check_field(is_store,         0,   "is_store        ");
        check_field(is_unit_stride,   0,   "is_unit_stride  ");
        check_field(is_unit_store,    0,   "is_unit_store   ");
        check_field(is_strided_load,  0,   "is_strided_load ");
        check_field(is_strided_store, 0,   "is_strided_store");
        check_field(is_mask_load,     0,   "is_mask_load    ");
        check_field(is_mask_store,    0,   "is_mask_store   ");

        // -----------------------------------------------------------
        $display("\n=== Resultado: %0d PASS  %0d FAIL ===", pass, fail);
        $finish;
    end

endmodule
