`timescale 1ns/1ps
module tb_ve_top;
    reg        clk, rst;

    // Instruccion al decode unit
    reg [31:0] du_i_instr;

    // Registro entero simulado: el decode lee rs1/rs2 de aqui
    reg [31:0] int_rf [0:31];

    // DCache simulada
    wire [31:0] o_mem_addr;
    wire        o_mem_read_en;
    reg  [31:0] i_mem_rdata;
    wire        o_mem_write_en;
    wire [31:0] o_mem_wdata;
    wire [3:0]  o_mem_byte_en;

    reg [31:0] mem [0:127];
    always @(*) begin
        if (o_mem_read_en) i_mem_rdata = mem[o_mem_addr[6:0]];
        else               i_mem_rdata = 32'b0;
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
        .STALL          (1'b0),
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
        // unused scalar pipeline outputs
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
        .o_mem_addr    (o_mem_addr),
        .o_mem_read_en (o_mem_read_en),
        .i_mem_rdata   (i_mem_rdata),
        .o_mem_write_en(o_mem_write_en),
        .o_mem_wdata   (o_mem_wdata),
        .o_mem_byte_en (o_mem_byte_en)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer pass = 0, fail = 0;

    // Envia instruccion ALU a traves del decode unit y espera pipeline (3 ciclos)
    // Latencia: 1 ciclo decode + 3 ciclos pipeline = 5 @posedge totales
    task send_alu;
        input [31:0] instr;
        begin
            @(posedge clk); #1;
            du_i_instr = instr;          // presentar instruccion al decode
            @(posedge clk); #1;          // decode captura → o_vec_valid=1
            du_i_instr = 32'h0000_0013; // NOP (ADDI x0,x0,0)
            @(posedge clk); #1;          // issue captura
            @(posedge clk); #1;          // execute captura
            @(posedge clk); #1;          // VRF write
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

    initial begin
        $dumpfile("tb_vext.vcd");
        $dumpvars(0, tb_ve_top);
        $display("=== ve_top integration tests ===");

        rst = 1; du_i_instr = 32'h0000_0013;
        repeat(2) @(posedge clk); #1;
        rst = 0;

        // Pre-cargar registros operando via acceso jerarquico
        dut.vregfile.regs[1] = {4{32'hA}};        // v1 = {10,10,10,10}
        dut.vregfile.regs[2] = {4{32'h14}};       // v2 = {20,20,20,20}
        dut.vregfile.regs[5] = {4{32'hFF00FF00}};
        dut.vregfile.regs[6] = {4{32'h0F0F0F0F}};
        dut.vregfile.regs[7] = {4{32'hAAAAAAAA}};
        dut.vregfile.regs[8] = {4{32'h55555555}};

        // VADD v3 = v1 + v2 : {30,...}  instr=32'h002081D7
        $display("Test: VADD v3 = v1 + v2");
        send_alu(32'h002081D7);
        check_reg(5'd3, {4{32'h1E}});

        // VSUB v4 = v2 - v1 : {10,...}  funct7[5]=1,funct3=000,rs2=1,rs1=2,rd=4
        $display("Test: VSUB v4 = v2 - v1");
        send_alu(32'h40110257);
        check_reg(5'd4, {4{32'hA}});

        // VAND v9 = v5 & v6  funct7=0,funct3=111,rs2=6,rs1=5,rd=9
        $display("Test: VAND v9 = v5 & v6");
        send_alu(32'h0062F4D7);
        check_reg(5'd9, {4{32'h0F000F00}});

        // VOR v10 = v7 | v8  funct7=0,funct3=110,rs2=8,rs1=7,rd=10
        $display("Test: VOR v10 = v7 | v8");
        send_alu(32'h0083E557);
        check_reg(5'd10, {4{32'hFFFFFFFF}});

        // VXOR v11 = v7 ^ v8  instr=32'h0083C5D7
        $display("Test: VXOR v11 = v7 ^ v8");
        send_alu(32'h0083C5D7);
        check_reg(5'd11, {4{32'hFFFFFFFF}});

        // VADD v0 = v1 + v2 (v0 es escribible)  instr=32'h00208057
        $display("Test: VADD v0 = v1 + v2 (v0 es escribible)");
        send_alu(32'h00208057);
        check_reg(5'd0, {4{32'h1E}});

        // VADD v12 = v0 + v2 : v0=30, v2=20 → 50  instr=32'h00200657
        $display("Test: VADD v12 = v0 + v2 (v0 como fuente con valor 30)");
        send_alu(32'h00200657);
        check_reg(5'd12, {4{32'h32}});

        $display("=== Results: %0d passed, %0d failed ===", pass, fail);
        $finish;
    end
endmodule
