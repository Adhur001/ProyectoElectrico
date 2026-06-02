`timescale 1ns/1ps
module tb_ve_top;
    reg       clk, rst;
    reg       i_valid;
    reg [2:0] i_funct3;
    reg [4:0] i_rs1, i_rs2, i_rd;

    ve_top dut (
        .clk      (clk),
        .rst      (rst),
        .i_valid  (i_valid),
        .i_funct3 (i_funct3),
        .i_rs1    (i_rs1),
        .i_rs2    (i_rs2),
        .i_rd     (i_rd)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer pass = 0, fail = 0;

    task send_instr;
        input         valid;
        input  [2:0]  funct3;
        input  [4:0]  rs1, rs2, rd;
        begin
            i_valid  = valid;
            i_funct3 = funct3;
            i_rs1    = rs1;
            i_rs2    = rs2;
            i_rd     = rd;
            @(posedge clk); #1;
            i_valid = 0;
            i_funct3 = 0; i_rs1 = 0; i_rs2 = 0; i_rd = 0;
            // Wait remaining 2 cycles for the result to reach WB and commit.
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
        $display("=== vext_top integration tests ===");

        // -- Reset --
        rst = 1; i_valid = 0;
        i_funct3 = 0; i_rs1 = 0; i_rs2 = 0; i_rd = 0;
        repeat(2) @(posedge clk); #1;
        rst = 0;

        // -- Pre-load operand registers using hierarchical assignment --
        // v1 = {10, 10, 10, 10} (each lane = 32'hA)
        // v2 = {20, 20, 20, 20} (each lane = 32'h14)
        dut.vregfile.regs[1] = {4{32'hA}};
        dut.vregfile.regs[2] = {4{32'h14}};
        dut.vregfile.regs[5] = {4{32'hFF00FF00}};
        dut.vregfile.regs[6] = {4{32'h0F0F0F0F}};
        dut.vregfile.regs[7] = {4{32'hAAAAAAAA}};
        dut.vregfile.regs[8] = {4{32'h55555555}};
        #1;

        // -- VADD v3 = v1 + v2 : {10+20, ...} = {30, 30, 30, 30} --
        $display("Test: VADD v3 = v1 + v2");
        send_instr(1, 3'b000, 5'd1, 5'd2, 5'd3);
        check_reg(5'd3, {4{32'h1E}});  // 0x1E = 30

        // -- VSUB v4 = v2 - v1 : {20-10, ...} = {10, 10, 10, 10} --
        $display("Test: VSUB v4 = v2 - v1");
        send_instr(1, 3'b001, 5'd2, 5'd1, 5'd4);
        check_reg(5'd4, {4{32'hA}});

        // -- VAND v9 = v5 & v6 : {FF00FF00 & 0F0F0F0F, ...} = {0F000F00, ...} --
        $display("Test: VAND v9 = v5 & v6");
        send_instr(1, 3'b010, 5'd5, 5'd6, 5'd9);
        check_reg(5'd9, {4{32'h0F000F00}});

        // -- VOR v10 = v7 | v8 : {AA...|55...} = {FF..., ...} --
        $display("Test: VOR v10 = v7 | v8");
        send_instr(1, 3'b011, 5'd7, 5'd8, 5'd10);
        check_reg(5'd10, {4{32'hFFFFFFFF}});

        // -- VXOR v11 = v7 ^ v8 : {AA...^55...} = {FF..., ...} --
        $display("Test: VXOR v11 = v7 ^ v8");
        send_instr(1, 3'b100, 5'd7, 5'd8, 5'd11);
        check_reg(5'd11, {4{32'hFFFFFFFF}});

        // -- v0 es un registro normal, acepta escritura (spec RVV) --
        $display("Test: VADD v0 = v1 + v2 (v0 es escribible)");
        send_instr(1, 3'b000, 5'd1, 5'd2, 5'd0);
        check_reg(5'd0, {4{32'h1E}});  // 10+20 = 30 = 0x1E

        // -- VADD v12 = v0 + v2 : v0=30, v2=20 → 50 = 0x32 --
        $display("Test: VADD v12 = v0 + v2 (v0 como fuente con valor 30)");
        send_instr(1, 3'b000, 5'd0, 5'd2, 5'd12);
        check_reg(5'd12, {4{32'h32}});  // 30+20 = 50 = 0x32

        $display("=== Results: %0d passed, %0d failed ===", pass, fail);
        $finish;
    end
endmodule
