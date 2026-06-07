`timescale 1ns/1ps
module tb_ve_top;
    reg        clk, rst;
    reg        i_valid;
    reg  [6:0] i_funct7;
    reg  [2:0] i_funct3;
    reg  [4:0] i_rs1, i_rs2, i_rd;
    reg         i_is_vx;
    reg  [31:0] i_scalar;

    ve_top dut (
        .clk      (clk),
        .rst      (rst),
        .i_valid  (i_valid),
        .i_funct7 (i_funct7),
        .i_funct3 (i_funct3),
        .i_rs1    (i_rs1),
        .i_rs2    (i_rs2),
        .i_rd     (i_rd),
        .i_is_vx  (i_is_vx),
        .i_scalar (i_scalar)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer pass = 0, fail = 0;

    task send_vv;
        input         funct7_5;
        input  [2:0]  funct3;
        input  [4:0]  rs1, rs2, rd;
        begin
            i_valid   = 1'b1;
            i_funct7  = {1'b0, funct7_5, 5'b0};
            i_funct3  = funct3;
            i_rs1     = rs1;
            i_rs2     = rs2;
            i_rd      = rd;
            i_is_vx   = 1'b0;
            i_scalar  = 32'b0;
            @(posedge clk); #1;
            i_valid = 1'b0; i_funct7 = 7'b0; i_funct3 = 3'b0;
            i_rs1 = 5'b0; i_rs2 = 5'b0; i_rd = 5'b0;
            repeat(2) @(posedge clk); #1;
        end
    endtask

    task send_vx;
        input         funct7_5;
        input  [2:0]  funct3;
        input  [4:0]  rs1, rd;
        input  [31:0] scalar;
        begin
            i_valid   = 1'b1;
            i_funct7  = {1'b0, funct7_5, 5'b0};
            i_funct3  = funct3;
            i_rs1     = rs1;
            i_rs2     = 5'b0;
            i_rd      = rd;
            i_is_vx   = 1'b1;
            i_scalar  = scalar;
            @(posedge clk); #1;
            i_valid = 1'b0; i_funct7 = 7'b0; i_funct3 = 3'b0;
            i_rs1 = 5'b0; i_rs2 = 5'b0; i_rd = 5'b0;
            i_is_vx = 1'b0; i_scalar = 32'b0;
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
        $dumpfile("tb_ve_top.vcd");
        $dumpvars(0, tb_ve_top);
        $display("=== ve_top integration tests ===");

        rst = 1; i_valid = 0; i_funct7 = 0; i_funct3 = 0;
        i_rs1 = 0; i_rs2 = 0; i_rd = 0; i_is_vx = 0; i_scalar = 0;
        repeat(2) @(posedge clk); #1;
        rst = 0;

        dut.vregfile.regs[1]  = {4{32'd10}};
        dut.vregfile.regs[2]  = {4{32'd20}};
        dut.vregfile.regs[5]  = {4{32'hFF00FF00}};
        dut.vregfile.regs[6]  = {4{32'h0F0F0F0F}};
        dut.vregfile.regs[7]  = {4{32'hAAAAAAAA}};
        dut.vregfile.regs[8]  = {4{32'h55555555}};
        dut.vregfile.regs[9]  = {4{32'd1}};
        dut.vregfile.regs[10] = {4{32'h80000000}};
        dut.vregfile.regs[11] = {4{32'hFFFFFFFF}};
        #1;

        $display("--- VV operations ---");

        $display("Test VV: VADD v3=v1+v2");
        send_vv(1'b0, 3'b000, 5'd1, 5'd2, 5'd3);
        check_reg(5'd3, {4{32'd30}});

        $display("Test VV: VSUB v4=v2-v1");
        send_vv(1'b1, 3'b000, 5'd2, 5'd1, 5'd4);
        check_reg(5'd4, {4{32'd10}});

        $display("Test VV: VSLL v12=v9<<v9");
        send_vv(1'b0, 3'b001, 5'd9, 5'd9, 5'd12);
        check_reg(5'd12, {4{32'd2}});

        $display("Test VV: VSLT v13=(v11<v1)");
        send_vv(1'b0, 3'b010, 5'd11, 5'd1, 5'd13);
        check_reg(5'd13, {4{32'd1}});

        $display("Test VV: VSLTU v14=(v1<v11)");
        send_vv(1'b0, 3'b011, 5'd1, 5'd11, 5'd14);
        check_reg(5'd14, {4{32'd1}});

        $display("Test VV: VXOR v15=v7^v8");
        send_vv(1'b0, 3'b100, 5'd7, 5'd8, 5'd15);
        check_reg(5'd15, {4{32'hFFFFFFFF}});

        $display("Test VV: VSRL v16=v10>>v9");
        send_vv(1'b0, 3'b101, 5'd10, 5'd9, 5'd16);
        check_reg(5'd16, {4{32'h40000000}});

        $display("Test VV: VSRA v17=v10>>>v9");
        send_vv(1'b1, 3'b101, 5'd10, 5'd9, 5'd17);
        check_reg(5'd17, {4{32'hC0000000}});

        $display("Test VV: VOR v18=v7|v8");
        send_vv(1'b0, 3'b110, 5'd7, 5'd8, 5'd18);
        check_reg(5'd18, {4{32'hFFFFFFFF}});

        $display("Test VV: VAND v19=v5&v6");
        send_vv(1'b0, 3'b111, 5'd5, 5'd6, 5'd19);
        check_reg(5'd19, {4{32'h0F000F00}});

        $display("--- v0 protection ---");

        $display("Test: write to v0 is discarded");
        send_vv(1'b0, 3'b000, 5'd1, 5'd2, 5'd0);
        check_reg(5'd0, 128'b0);

        $display("Test: VADD v20=v0+v2 (v0 as source = 0)");
        send_vv(1'b0, 3'b000, 5'd0, 5'd2, 5'd20);
        check_reg(5'd20, {4{32'd20}});

        $display("--- VX (vector-scalar) operations ---");

        $display("Test VX: VADD v21=v1+scalar(5)");
        send_vx(1'b0, 3'b000, 5'd1, 5'd21, 32'd5);
        check_reg(5'd21, {4{32'd15}});

        $display("Test VX: VSUB v22=v2-scalar(7)");
        send_vx(1'b1, 3'b000, 5'd2, 5'd22, 32'd7);
        check_reg(5'd22, {4{32'd13}});

        $display("Test VX: VAND v23=v5&scalar(0x0F0F0F0F)");
        send_vx(1'b0, 3'b111, 5'd5, 5'd23, 32'h0F0F0F0F);
        check_reg(5'd23, {4{32'h0F000F00}});

        $display("Test VX: VSRL v24=v10>>scalar(4)");
        send_vx(1'b0, 3'b101, 5'd10, 5'd24, 32'd4);
        check_reg(5'd24, {4{32'h08000000}});

        $display("Test VX: VSRA v25=v10>>>scalar(4)");
        send_vx(1'b1, 3'b101, 5'd10, 5'd25, 32'd4);
        check_reg(5'd25, {4{32'hF8000000}});

        $display("=== Results: %0d passed, %0d failed ===", pass, fail);
        $finish;
    end
endmodule
