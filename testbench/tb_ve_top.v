`timescale 1ns/1ps
module tb_ve_top;
    reg        clk, rst;
    reg        i_valid;
    reg [31:0] i_instr;
    reg        i_is_vx;
    reg [31:0] i_scalar;
    reg [31:0] i_base_addr;
    reg [31:0] i_stride;

    // DCache simulada (la ve_top expone la interfaz externamente)
    wire [31:0] o_mem_addr;
    wire        o_mem_read_en;
    reg  [31:0] i_mem_rdata;
    wire        o_mem_write_en;
    wire [31:0] o_mem_wdata;
    wire [3:0]  o_mem_byte_en;

    // Modelo de DCache combinacional
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

    ve_top dut (
        .clk           (clk),
        .rst           (rst),
        .i_valid       (i_valid),
        .i_instr       (i_instr),
        .i_is_vx       (i_is_vx),
        .i_scalar      (i_scalar),
        .i_base_addr   (i_base_addr),
        .i_stride      (i_stride),
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

    // Envia una instruccion ALU y espera que complete el pipeline (3 ciclos)
    task send_alu;
        input [31:0] instr;
        begin
            @(posedge clk); #1;
            i_valid = 1;
            i_instr = instr;
            i_is_vx = 0;
            i_scalar = 0;
            @(posedge clk); #1;
            i_valid = 0;
            i_instr = 0;
            repeat(2) @(posedge clk); #1;
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

        rst = 1; i_valid = 0; i_instr = 0; i_is_vx = 0; i_scalar = 0;
        i_base_addr = 0; i_stride = 0;
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
