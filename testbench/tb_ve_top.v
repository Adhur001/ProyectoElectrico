`timescale 1ns/1ps
module tb_ve_top;
    reg        clk, rst;

    // Instruccion al decode unit
    reg [31:0] du_i_instr;

    // Registro entero simulado: el decode lee rs1/rs2 de aqui
    reg [31:0] int_rf [0:31];

    // DCache simulada — puerto A
    wire [31:0] o_mem_addr;
    wire        o_mem_read_en;
    reg  [31:0] i_mem_rdata;
    wire        o_mem_write_en;
    wire [31:0] o_mem_wdata;
    wire [3:0]  o_mem_byte_en;

    // DCache simulada — puerto B
    wire [31:0] o_mem_addr_b;
    wire        o_mem_read_en_b;
    reg  [31:0] i_mem_rdata_b;
    wire        o_mem_write_en_b;
    wire [31:0] o_mem_wdata_b;
    wire [3:0]  o_mem_byte_en_b;

    // Stall del pipeline vectorial hacia el decode escalar
    wire stall;

    reg [31:0] mem [0:127];

    // Modelo de DCache: lecturas combinacionales, escrituras sincronas
    always @(*) begin
        i_mem_rdata  = o_mem_read_en   ? mem[o_mem_addr[6:0]]   : 32'b0;
        i_mem_rdata_b = o_mem_read_en_b ? mem[o_mem_addr_b[6:0]] : 32'b0;
    end
    always @(posedge clk) begin
        if (o_mem_write_en) begin
            if (o_mem_byte_en[0]) mem[o_mem_addr[6:0]][7:0]   <= o_mem_wdata[7:0];
            if (o_mem_byte_en[1]) mem[o_mem_addr[6:0]][15:8]  <= o_mem_wdata[15:8];
            if (o_mem_byte_en[2]) mem[o_mem_addr[6:0]][23:16] <= o_mem_wdata[23:16];
            if (o_mem_byte_en[3]) mem[o_mem_addr[6:0]][31:24] <= o_mem_wdata[31:24];
        end
        if (o_mem_write_en_b) begin
            if (o_mem_byte_en_b[0]) mem[o_mem_addr_b[6:0]][7:0]   <= o_mem_wdata_b[7:0];
            if (o_mem_byte_en_b[1]) mem[o_mem_addr_b[6:0]][15:8]  <= o_mem_wdata_b[15:8];
            if (o_mem_byte_en_b[2]) mem[o_mem_addr_b[6:0]][23:16] <= o_mem_wdata_b[23:16];
            if (o_mem_byte_en_b[3]) mem[o_mem_addr_b[6:0]][31:24] <= o_mem_wdata_b[31:24];
        end
    end

    // -------------------------------------------------------------------------
    // Decode unit (Modified_DecodeUnit.v)
    // -------------------------------------------------------------------------
    wire [4:0]  du_o_rs1_addr, du_o_rs2_addr;
    wire [31:0] du_i_rs1_data, du_i_rs2_data;

    assign du_i_rs1_data = int_rf[du_o_rs1_addr];
    assign du_i_rs2_data = int_rf[du_o_rs2_addr];

    wire        du_o_vec_valid;
    wire [6:0]  du_o_vec_funct7;
    wire [2:0]  du_o_vec_funct3;
    wire [4:0]  du_o_vec_rs1, du_o_vec_rs2, du_o_vec_rd;
    wire        du_o_vec_is_vx;
    wire [31:0] du_o_vec_scalar;
    wire        du_o_vec_lsu_valid;
    wire        du_o_vec_is_load, du_o_vec_is_store;
    wire        du_o_vec_is_mask_op, du_o_vec_is_strided, du_o_vec_is_indexed;
    wire [31:0] du_o_vec_base_addr, du_o_vec_stride;

    decode du (
        .CLK            (clk),
        .RST            (rst),
        .FLUSH          (1'b0),
        .STALL          (stall),
        .i_instr        (du_i_instr),
        .i_pc           (32'b0),
        .i_bubble       (1'b0),
        .i_rs1_data     (du_i_rs1_data),
        .i_rs2_data     (du_i_rs2_data),
        .o_rs1_addr     (du_o_rs1_addr),
        .o_rs2_addr     (du_o_rs2_addr),
        .o_vec_valid    (du_o_vec_valid),
        .o_vec_funct7   (du_o_vec_funct7),
        .o_vec_funct3   (du_o_vec_funct3),
        .o_vec_rs1      (du_o_vec_rs1),
        .o_vec_rs2      (du_o_vec_rs2),
        .o_vec_rd       (du_o_vec_rd),
        .o_vec_is_vx    (du_o_vec_is_vx),
        .o_vec_scalar   (du_o_vec_scalar),
        .o_vec_lsu_valid  (du_o_vec_lsu_valid),
        .o_vec_is_load    (du_o_vec_is_load),
        .o_vec_is_store   (du_o_vec_is_store),
        .o_vec_is_mask_op (du_o_vec_is_mask_op),
        .o_vec_is_strided (du_o_vec_is_strided),
        .o_vec_is_indexed (du_o_vec_is_indexed),
        .o_vec_base_addr  (du_o_vec_base_addr),
        .o_vec_stride     (du_o_vec_stride),
        // outputs del pipeline escalar no usados aqui
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
        .o_write_on_reg ()
    );

    // -------------------------------------------------------------------------
    // ve_top DUT
    // -------------------------------------------------------------------------
    ve_top dut (
        .clk          (clk),
        .rst          (rst),
        .i_alu_valid  (du_o_vec_valid),
        .i_funct7     (du_o_vec_funct7),
        .i_funct3     (du_o_vec_funct3),
        .i_rs1        (du_o_vec_rs1),
        .i_rs2        (du_o_vec_rs2),
        .i_rd         (du_o_vec_rd),
        .i_is_vx      (du_o_vec_is_vx),
        .i_scalar     (du_o_vec_scalar),
        .i_lsu_valid  (du_o_vec_lsu_valid),
        .i_is_load    (du_o_vec_is_load),
        .i_is_store   (du_o_vec_is_store),
        .i_is_mask_op (du_o_vec_is_mask_op),
        .i_is_strided (du_o_vec_is_strided),
        .i_is_indexed (du_o_vec_is_indexed),
        .i_base_addr  (du_o_vec_base_addr),
        .i_stride     (du_o_vec_stride),
        .o_stall         (stall),
        .o_mem_addr      (o_mem_addr),
        .o_mem_read_en   (o_mem_read_en),
        .i_mem_rdata     (i_mem_rdata),
        .o_mem_write_en  (o_mem_write_en),
        .o_mem_wdata     (o_mem_wdata),
        .o_mem_byte_en   (o_mem_byte_en),
        .o_mem_addr_b    (o_mem_addr_b),
        .o_mem_read_en_b (o_mem_read_en_b),
        .i_mem_rdata_b   (i_mem_rdata_b),
        .o_mem_write_en_b(o_mem_write_en_b),
        .o_mem_wdata_b   (o_mem_wdata_b),
        .o_mem_byte_en_b (o_mem_byte_en_b)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer pass = 0, fail = 0;

    // Envia una instruccion ALU a traves del decode y espera 4 etapas de pipeline.
    // Latencia total: 1 decode + 4 pipeline (Issue+Execute+MEM+WB) = 5 posedges
    task send_alu;
        input [31:0] instr;
        begin
            @(posedge clk); #1;
            du_i_instr = instr;
            @(posedge clk); #1; du_i_instr = 32'h0000_0013; // NOP
            @(posedge clk); #1; // Issue captura
            @(posedge clk); #1; // Execute
            @(posedge clk); #1; // MEM
            @(posedge clk); #1; // WB escribe VRF
        end
    endtask

    // Envia una instruccion LSU de carga y espera que complete.
    // Latencia: 1 decode + Issue + Execute(ACCESS_01) + MEM(ACCESS_23) + WB = 5 posedges
    task send_load;
        input [31:0] instr;
        begin
            @(posedge clk); #1;
            du_i_instr = instr;
            @(posedge clk); #1; du_i_instr = 32'h0000_0013;
            @(posedge clk); #1; // Issue
            @(posedge clk); #1; // Execute: ACCESS_01
            @(posedge clk); #1; // MEM: ACCESS_23
            @(posedge clk); #1; // WB: escribe VRF
        end
    endtask

    // Envia una instruccion LSU de store y espera que complete.
    // Latencia: 1 decode + Issue + Execute(SWRITE_01) + MEM(SWRITE_23) + WB(pass) = 5 posedges
    task send_store;
        input [31:0] instr;
        begin
            @(posedge clk); #1;
            du_i_instr = instr;
            @(posedge clk); #1; du_i_instr = 32'h0000_0013;
            @(posedge clk); #1; // Issue
            @(posedge clk); #1; // Execute: SWRITE_01
            @(posedge clk); #1; // MEM: SWRITE_23
            @(posedge clk); #1; // WB: pass-through (stores no escriben VRF)
        end
    endtask

    task check_reg;
        input [4:0]   addr;
        input [127:0] expected;
        begin
            if (dut.vregfile.regs[addr] === expected) begin
                $display("  PASS v%0d = %h", addr, dut.vregfile.regs[addr]);
                pass = pass + 1;
            end else begin
                $display("  FAIL v%0d: got %h, expected %h",
                         addr, dut.vregfile.regs[addr], expected);
                fail = fail + 1;
            end
        end
    endtask

    // Envia dos instrucciones consecutivas (gap de 1 ciclo) y espera que B complete.
    // Cuando B tiene dependencia RAW con A, la hazard unit inserta 3 burbujas automaticamente.
    task send_raw_consecutive;
        input [31:0] instr_a;
        input [31:0] instr_b;
        begin
            @(posedge clk); #1;
            du_i_instr = instr_a;
            @(posedge clk); #1;
            du_i_instr = instr_b;
            @(posedge clk); #1;
            du_i_instr = 32'h0000_0013;
            repeat(9) @(posedge clk); #1;
        end
    endtask

    task check_mem;
        input [6:0]  addr;
        input [31:0] expected;
        begin
            if (mem[addr] === expected) begin
                $display("  PASS mem[%0d] = %h", addr, mem[addr]);
                pass = pass + 1;
            end else begin
                $display("  FAIL mem[%0d]: got %h, expected %h",
                         addr, mem[addr], expected);
                fail = fail + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_vext.vcd");
        $dumpvars(0, tb_ve_top);
        $display("=== ve_top integration tests ===");

        rst = 1; du_i_instr = 32'h0000_0013;
        repeat(2) @(posedge clk); #1;
        rst = 0;

        // Pre-cargar registros vectoriales
        dut.vregfile.regs[1]  = {4{32'hA}};
        dut.vregfile.regs[2]  = {4{32'h14}};
        dut.vregfile.regs[5]  = {4{32'hFF00FF00}};
        dut.vregfile.regs[6]  = {4{32'h0F0F0F0F}};
        dut.vregfile.regs[7]  = {4{32'hAAAAAAAA}};
        dut.vregfile.regs[8]  = {4{32'h55555555}};

        // Pre-cargar DCache para pruebas de carga (indices = direcciones en bytes)
        // Bloque A: palabras a byte 0..12 (step=4, unit-stride)
        mem[0]  = 32'hDEAD_BEEF;
        mem[4]  = 32'hCAFE_BABE;
        mem[8]  = 32'h1234_5678;
        mem[12] = 32'h9ABC_DEF0;

        // Bloque B: palabras a byte 20..32 (base_addr=20)
        mem[20] = 32'h0000_0001;
        mem[24] = 32'h0000_0002;
        mem[28] = 32'h0000_0003;
        mem[32] = 32'h0000_0004;

        // Bloque C: stride/indexed tests (base=80, step=8)
        mem[80]  = 32'hA1A1_A1A1;
        mem[88]  = 32'hB2B2_B2B2;
        mem[96]  = 32'hC3C3_C3C3;
        mem[104] = 32'hD4D4_D4D4;

        // Bloque D: mask tests
        mem[110] = 32'h1234_5678;   // fuente VLM
        mem[114] = 32'h0000_0000;   // destino VSM (pre-inicializado)

        // =====================================================================
        // Tests ALU
        // =====================================================================

        // VADD v3 = v1 + v2 → {30,30,30,30}
        $display("\nTest ALU-1: VADD v3 = v1 + v2");
        send_alu(32'h002081D7);
        check_reg(5'd3, {4{32'h1E}});

        // VSUB v4 = v2 - v1 → {10,10,10,10}
        $display("\nTest ALU-2: VSUB v4 = v2 - v1");
        send_alu(32'h40110257);
        check_reg(5'd4, {4{32'hA}});

        // VAND v9 = v5 & v6
        $display("\nTest ALU-3: VAND v9 = v5 & v6");
        send_alu(32'h0062F4D7);
        check_reg(5'd9, {4{32'h0F000F00}});

        // VOR v10 = v7 | v8
        $display("\nTest ALU-4: VOR v10 = v7 | v8");
        send_alu(32'h0083E557);
        check_reg(5'd10, {4{32'hFFFFFFFF}});

        // VXOR v11 = v7 ^ v8
        $display("\nTest ALU-5: VXOR v11 = v7 ^ v8");
        send_alu(32'h0083C5D7);
        check_reg(5'd11, {4{32'hFFFFFFFF}});

        // VADD v0 = v1 + v2 (v0 es escribible)
        $display("\nTest ALU-6: VADD v0 = v1 + v2");
        send_alu(32'h00208057);
        check_reg(5'd0, {4{32'h1E}});

        // VADD v12 = v0 + v2 : 30+20=50
        $display("\nTest ALU-7: VADD v12 = v0 + v2");
        send_alu(32'h00200657);
        check_reg(5'd12, {4{32'h32}});

        // =====================================================================
        // Tests LSU — Load
        // VLE32.v: opcode=0000111, funct3=110, mop=00 (bits[27:26]), vm=1 (bit[25])
        // int_rf[1] = base_addr (rs1=x1)
        // =====================================================================

        // TEST LSU-1: VLE32.v v13, (x1)  base=0
        //   addr_0=0,4,8,12 → mem[0..12]
        //   Esperado v13 = {9ABCDEF0, 12345678, CAFEBABE, DEADBEEF}
        $display("\nTest LSU-1: VLE32.v v13, (x1)  base=0");
        int_rf[1] = 32'd0;
        send_load(32'h0200_E687);   // vd=v13, rs1=x1
        check_reg(5'd13, {32'h9ABC_DEF0, 32'h1234_5678, 32'hCAFE_BABE, 32'hDEAD_BEEF});

        // TEST LSU-2: VLE32.v v14, (x1)  base=20
        //   addr_0=20,24,28,32 → mem[20..32]
        //   Esperado v14 = {4,3,2,1}
        $display("\nTest LSU-2: VLE32.v v14, (x1)  base=20");
        int_rf[1] = 32'd20;
        send_load(32'h0200_E707);   // vd=v14, rs1=x1
        check_reg(5'd14, {32'd4, 32'd3, 32'd2, 32'd1});

        // =====================================================================
        // Tests LSU — Store
        // VSE32.v: opcode=0100111, funct3=110, mop=00, vm=1
        // vs3 codificado en el campo rd (bits[11:7])
        // =====================================================================

        // TEST LSU-3: VSE32.v v13, (x1)  base=40
        //   Escribe v13={9ABCDEF0,12345678,CAFEBABE,DEADBEEF} a mem[40,44,48,52]
        $display("\nTest LSU-3: VSE32.v v13, (x1)  base=40");
        int_rf[1] = 32'd40;
        send_store(32'h0200_E6A7);  // vs3=v13 (rd=13=01101), rs1=x1
        check_mem(7'd40, 32'hDEAD_BEEF);
        check_mem(7'd44, 32'hCAFE_BABE);
        check_mem(7'd48, 32'h1234_5678);
        check_mem(7'd52, 32'h9ABC_DEF0);

        // TEST LSU-4: VSE32.v v14, (x1)  base=60
        //   Escribe v14={4,3,2,1} a mem[60,64,68,72]
        $display("\nTest LSU-4: VSE32.v v14, (x1)  base=60");
        int_rf[1] = 32'd60;
        send_store(32'h0200_E727);  // vs3=v14 (rd=14=01110), rs1=x1
        check_mem(7'd60, 32'd1);
        check_mem(7'd64, 32'd2);
        check_mem(7'd68, 32'd3);
        check_mem(7'd72, 32'd4);

        // =====================================================================
        // Tests LSU — Strided
        // VLSE32.v: mop=10 (bits[27:26]), rs2=stride scalar register
        // VSSE32.v: same encoding, opcode=0100111
        // =====================================================================

        // TEST LSU-5: VLSE32.v v15, (x1=80), x2=8
        //   step=8 → addr: 80,88,96,104 → {D4D4D4D4,C3C3C3C3,B2B2B2B2,A1A1A1A1}
        $display("\nTest LSU-5: VLSE32.v v15, (x1=80), x2=8");
        int_rf[1] = 32'd80;
        int_rf[2] = 32'd8;
        send_load(32'h0A20_E787);
        check_reg(5'd15, {32'hD4D4_D4D4, 32'hC3C3_C3C3, 32'hB2B2_B2B2, 32'hA1A1_A1A1});

        // TEST LSU-6: VSSE32.v v15, (x1=100), x2=8
        //   Escribe v15 a mem[100,108,116,124] con step=8
        $display("\nTest LSU-6: VSSE32.v v15, (x1=100), x2=8");
        int_rf[1] = 32'd100;
        int_rf[2] = 32'd8;
        send_store(32'h0A20_E7A7);
        check_mem(7'd100, 32'hA1A1_A1A1);
        check_mem(7'd108, 32'hB2B2_B2B2);
        check_mem(7'd116, 32'hC3C3_C3C3);
        check_mem(7'd124, 32'hD4D4_D4D4);

        // =====================================================================
        // Tests LSU — Indexed
        // vluxei32.v: mop=01 (bits[27:26]), bits[24:20]=vs2 (vector register)
        // vsuxei32.v: same, opcode=0100111
        // v2 se carga con offsets {0,8,16,24} (un offset por elemento)
        // =====================================================================
        dut.vregfile.regs[2] = {32'd24, 32'd16, 32'd8, 32'd0};

        // TEST LSU-7: vluxei32.v v16, (x1=80), v2
        //   offsets v2={0,8,16,24} → addr: 80,88,96,104 → {D4,C3,B2,A1}
        $display("\nTest LSU-7: vluxei32.v v16, (x1=80), v2={0,8,16,24}");
        int_rf[1] = 32'd80;
        send_load(32'h0620_E807);
        check_reg(5'd16, {32'hD4D4_D4D4, 32'hC3C3_C3C3, 32'hB2B2_B2B2, 32'hA1A1_A1A1});

        // TEST LSU-8: vsuxei32.v v16, (x1=100), v2
        //   offsets {0,8,16,24} → escribe v16 a mem[100,108,116,124]
        $display("\nTest LSU-8: vsuxei32.v v16, (x1=100), v2={0,8,16,24}");
        int_rf[1] = 32'd100;
        send_store(32'h0620_E827);
        check_mem(7'd100, 32'hA1A1_A1A1);
        check_mem(7'd108, 32'hB2B2_B2B2);
        check_mem(7'd116, 32'hC3C3_C3C3);
        check_mem(7'd124, 32'hD4D4_D4D4);

        // =====================================================================
        // Tests LSU — Mask (VLM / VSM)
        // mop=00 (unit-stride), lumop=01011 → is_mask_op=1
        // VLM: carga 1 byte → VRF = {120'b0, byte[7:0]}
        // VSM: escribe 1 byte con byte_en=0001 (ACCESS_23 omitido)
        // =====================================================================

        // TEST LSU-9: VLM.v v17, (x1=110)
        //   mem[110]=0x12345678 → byte0=0x78 → v17={120'b0, 8'h78}
        $display("\nTest LSU-9: VLM.v v17, (x1=110)");
        int_rf[1] = 32'd110;
        send_load(32'h02B0_8887);
        check_reg(5'd17, {120'b0, 8'h78});

        // TEST LSU-10: VSM.v v17, (x1=114)
        //   v17[7:0]=0x78, byte_en=0001 → mem[114][7:0]=0x78
        $display("\nTest LSU-10: VSM.v v17, (x1=114)");
        int_rf[1] = 32'd114;
        send_store(32'h02B0_88A7);
        check_mem(7'd114, 32'h0000_0078);

        // =====================================================================
        // Tests RAW hazard — instrucciones back-to-back con dependencia de datos
        // =====================================================================

        // TEST RAW-1: VADD v20=v1+v2, luego inmediatamente VADD v21=v20+v1
        //   v1={4{0xA}}, v2 restaurado a {4{0x14}}
        //   A: v20 = v1 + v2 = {4{0x1E}}
        //   B: v21 = v20 + v1 = {4{0x28}} (usa resultado fresco de A)
        //   Sin hazard unit: v21 leeria v20 stale → resultado incorrecto
        $display("\nTest RAW-1: back-to-back VADD con dependencia RAW en v20");
        dut.vregfile.regs[2]  = {4{32'h14}};
        dut.vregfile.regs[20] = 128'hDEAD_BEEF_DEAD_BEEF_DEAD_BEEF_DEAD_BEEF;
        // VADD v20 = v1 + v2: 0x0020_8A57
        // VADD v21 = v20 + v1: 0x001A_0AD7
        send_raw_consecutive(32'h0020_8A57, 32'h001A_0AD7);
        check_reg(5'd20, {4{32'h1E}});
        check_reg(5'd21, {4{32'h28}});

        // TEST RAW-2: VADD v22=v1+v2, luego VSUB v23=v22-v1
        //   v1={4{0xA}}, v2={4{0x14}}
        //   A: v22 = v1 + v2 = {4{0x1E}}
        //   B: v23 = v22 - v1 = {4{0x14}}
        $display("\nTest RAW-2: back-to-back VADD/VSUB con dependencia RAW en v22");
        dut.vregfile.regs[22] = 128'hDEAD_BEEF_DEAD_BEEF_DEAD_BEEF_DEAD_BEEF;
        // VADD v22 = v1 + v2: rd=22=10110, rs1=v1=00001, rs2=v2=00010
        // 0000000_00010_00001_000_10110_1010111 = 0x0020_8B57
        // VSUB v23 = v22 - v1: funct7=0100000, rd=23=10111, rs1=v22=10110, rs2=v1=00001
        // 0100000_00001_10110_000_10111_1010111 = 0x401B_0BD7
        send_raw_consecutive(32'h0020_8B57, 32'h401B_0BD7);
        check_reg(5'd22, {4{32'h1E}});
        check_reg(5'd23, {4{32'h14}});

        $display("\n=== Results: %0d passed, %0d failed ===", pass, fail);
        $finish;
    end
endmodule
