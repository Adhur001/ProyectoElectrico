// Testbench combinacional para vlsu (generador de accesos LSU vectorial).
// Verifica: generacion de direcciones, enables y rutas de datos para
// unit-stride, strided, indexed, mask load (VLM) y mask store (VSM).
`timescale 1ns/1ps

module tb_vlsu_integration;

    reg  [1:0]   i_phase;
    reg          i_en;
    reg          i_is_load;
    reg          i_is_store;
    reg          i_is_mask_op;
    reg          i_is_strided;
    reg          i_is_indexed;
    reg  [31:0]  i_base_addr;
    reg  [31:0]  i_stride;
    reg  [127:0] i_offset_buf;
    reg  [127:0] i_wdata;

    wire [31:0]  o_mem_addr,    o_mem_addr_b;
    wire         o_mem_read_en, o_mem_read_en_b;
    wire         o_mem_write_en,o_mem_write_en_b;
    wire [31:0]  o_mem_wdata,   o_mem_wdata_b;
    wire [3:0]   o_mem_byte_en, o_mem_byte_en_b;

    vlsu dut (
        .i_phase         (i_phase),
        .i_en            (i_en),
        .i_is_load       (i_is_load),
        .i_is_store      (i_is_store),
        .i_is_mask_op    (i_is_mask_op),
        .i_is_strided    (i_is_strided),
        .i_is_indexed    (i_is_indexed),
        .i_base_addr     (i_base_addr),
        .i_stride        (i_stride),
        .i_offset_buf    (i_offset_buf),
        .i_wdata         (i_wdata),
        .o_mem_addr      (o_mem_addr),
        .o_mem_read_en   (o_mem_read_en),
        .o_mem_write_en  (o_mem_write_en),
        .o_mem_wdata     (o_mem_wdata),
        .o_mem_byte_en   (o_mem_byte_en),
        .o_mem_addr_b    (o_mem_addr_b),
        .o_mem_read_en_b (o_mem_read_en_b),
        .o_mem_write_en_b(o_mem_write_en_b),
        .o_mem_wdata_b   (o_mem_wdata_b),
        .o_mem_byte_en_b (o_mem_byte_en_b)
    );

    integer pass = 0, fail = 0;

    task chk32;
        input [31:0] got;
        input [31:0] exp;
        input [63:0] tag;
        begin
            if (got === exp) begin
                $display("    PASS %0d", tag);
                pass = pass + 1;
            end else begin
                $display("    FAIL %0d: got %h  expected %h", tag, got, exp);
                fail = fail + 1;
            end
        end
    endtask

    task chk1;
        input got;
        input exp;
        input [63:0] tag;
        begin
            if (got === exp) begin
                $display("    PASS %0d", tag);
                pass = pass + 1;
            end else begin
                $display("    FAIL %0d: got %b  expected %b", tag, got, exp);
                fail = fail + 1;
            end
        end
    endtask

    // Default: todos los controles apagados
    task reset_inputs;
        begin
            i_en = 0; i_phase = 2'b00;
            i_is_load = 0; i_is_store = 0; i_is_mask_op = 0;
            i_is_strided = 0; i_is_indexed = 0;
            i_base_addr = 0; i_stride = 0;
            i_offset_buf = 0; i_wdata = 0;
        end
    endtask

    initial begin
        $display("=== tb_vlsu_integration ===");
        reset_inputs; #2;

        // =====================================================================
        // TEST 1: Unit-stride load, ACCESS_01
        //   base=0x100, step=4 (default)
        //   Espera: addr_A=0x100, addr_B=0x104, read_en=1, read_en_b=1
        // =====================================================================
        $display("\n[TEST 1] Unit-stride load ACCESS_01");
        i_en = 1; i_is_load = 1; i_base_addr = 32'h100; #1;
        chk32(o_mem_addr,    32'h100, 1);
        chk32(o_mem_addr_b,  32'h104, 2);
        chk1 (o_mem_read_en,   1'b1,  3);
        chk1 (o_mem_read_en_b, 1'b1,  4);
        chk1 (o_mem_write_en,  1'b0,  5);

        // =====================================================================
        // TEST 2: Unit-stride load, ACCESS_23
        //   Espera: addr_A=0x108, addr_B=0x10C
        // =====================================================================
        $display("\n[TEST 2] Unit-stride load ACCESS_23");
        i_phase = 2'b01; #1;
        chk32(o_mem_addr,    32'h108, 6);
        chk32(o_mem_addr_b,  32'h10C, 7);
        chk1 (o_mem_read_en,   1'b1,  8);

        // =====================================================================
        // TEST 3: Strided load, ACCESS_01 (stride=8)
        //   base=0x200, stride=8
        //   Espera: addr_A=0x200, addr_B=0x208
        // =====================================================================
        $display("\n[TEST 3] Strided load ACCESS_01 (stride=8)");
        reset_inputs; #1;
        i_en = 1; i_is_load = 1; i_is_strided = 1;
        i_base_addr = 32'h200; i_stride = 32'd8; i_phase = 2'b00; #1;
        chk32(o_mem_addr,   32'h200, 9);
        chk32(o_mem_addr_b, 32'h208, 10);

        // =====================================================================
        // TEST 4: Strided load, ACCESS_23
        //   Espera: addr_A=0x210, addr_B=0x218
        // =====================================================================
        $display("\n[TEST 4] Strided load ACCESS_23");
        i_phase = 2'b01; #1;
        chk32(o_mem_addr,   32'h210, 11);
        chk32(o_mem_addr_b, 32'h218, 12);

        // =====================================================================
        // TEST 5: Indexed load, ACCESS_01
        //   base=0x300, offsets={0x40,0x30,0x20,0x10} (elem3..elem0 en [127:0])
        //   Espera: addr_A=0x310, addr_B=0x320
        // =====================================================================
        $display("\n[TEST 5] Indexed load ACCESS_01");
        reset_inputs; #1;
        i_en = 1; i_is_load = 1; i_is_indexed = 1;
        i_base_addr  = 32'h300;
        i_offset_buf = {32'h40, 32'h30, 32'h20, 32'h10}; // [127:96]=off3, [31:0]=off0
        i_phase = 2'b00; #1;
        chk32(o_mem_addr,   32'h310, 13);
        chk32(o_mem_addr_b, 32'h320, 14);

        // =====================================================================
        // TEST 6: Indexed load, ACCESS_23
        //   Espera: addr_A=0x330, addr_B=0x340
        // =====================================================================
        $display("\n[TEST 6] Indexed load ACCESS_23");
        i_phase = 2'b01; #1;
        chk32(o_mem_addr,   32'h330, 15);
        chk32(o_mem_addr_b, 32'h340, 16);

        // =====================================================================
        // TEST 7: Unit-stride store, ACCESS_01
        //   wdata = {0xDDDD,0xCCCC,0xBBBB,0xAAAA} (word3..word0)
        //   Espera: write_en=1, wdata_A=0xAAAA, wdata_B=0xBBBB
        // =====================================================================
        $display("\n[TEST 7] Unit-stride store ACCESS_01");
        reset_inputs; #1;
        i_en = 1; i_is_store = 1; i_base_addr = 32'h100;
        i_wdata = {32'hDDDD, 32'hCCCC, 32'hBBBB, 32'hAAAA};
        i_phase = 2'b00; #1;
        chk32(o_mem_addr,    32'h100,  17);
        chk32(o_mem_addr_b,  32'h104,  18);
        chk1 (o_mem_write_en,   1'b1,  19);
        chk1 (o_mem_write_en_b, 1'b1,  20);
        chk32(o_mem_wdata,   32'hAAAA, 21);
        chk32(o_mem_wdata_b, 32'hBBBB, 22);
        chk1 (o_mem_read_en,    1'b0,  23);

        // =====================================================================
        // TEST 8: Unit-stride store, ACCESS_23
        //   Espera: wdata_A=0xCCCC, wdata_B=0xDDDD
        // =====================================================================
        $display("\n[TEST 8] Unit-stride store ACCESS_23");
        i_phase = 2'b01; #1;
        chk32(o_mem_addr,    32'h108,  24);
        chk32(o_mem_addr_b,  32'h10C,  25);
        chk32(o_mem_wdata,   32'hCCCC, 26);
        chk32(o_mem_wdata_b, 32'hDDDD, 27);

        // =====================================================================
        // TEST 9: VLM — mask load, ACCESS_01
        //   Espera: read_en_A=1, read_en_B=0, byte_en no aplica (es lectura)
        // =====================================================================
        $display("\n[TEST 9] VLM mask load ACCESS_01");
        reset_inputs; #1;
        i_en = 1; i_is_load = 1; i_is_mask_op = 1;
        i_base_addr = 32'h400; i_phase = 2'b00; #1;
        chk1(o_mem_read_en,   1'b1, 28);
        chk1(o_mem_read_en_b, 1'b0, 29);

        // =====================================================================
        // TEST 10: VSM — mask store, ACCESS_01
        //   Espera: write_en_A=1, write_en_B=0, byte_en_A=0001
        // =====================================================================
        $display("\n[TEST 10] VSM mask store ACCESS_01");
        reset_inputs; #1;
        i_en = 1; i_is_store = 1; i_is_mask_op = 1;
        i_base_addr = 32'h400;
        i_wdata = {32'hDDDD, 32'hCCCC, 32'hBBBB, 32'hAAAA};
        i_phase = 2'b00; #1;
        chk1 (o_mem_write_en,   1'b1,     30);
        chk1 (o_mem_write_en_b, 1'b0,     31);
        chk32(o_mem_byte_en,    32'h1,    32); // 4'b0001 zero-extended
        chk32(o_mem_wdata,      32'hAAAA, 33);

        // =====================================================================
        // TEST 11: i_en=0 desactiva todos los enables
        // =====================================================================
        $display("\n[TEST 11] i_en=0 desactiva salidas");
        i_en = 0; i_is_load = 1; i_is_store = 1; #1;
        chk1(o_mem_read_en,    1'b0, 34);
        chk1(o_mem_read_en_b,  1'b0, 35);
        chk1(o_mem_write_en,   1'b0, 36);
        chk1(o_mem_write_en_b, 1'b0, 37);

        $display("\n=== Resultado: %0d PASS  %0d FAIL ===", pass, fail);
        $finish;
    end

endmodule
