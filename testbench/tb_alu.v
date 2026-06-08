`timescale 1ns/1ps
module tb_alu;
    reg  [3:0]  alu_op;
    reg  [31:0] in_a, in_b;
    wire [31:0] out;

    alu #(.SIZE(32)) dut (
        .alu_op (alu_op),
        .in_a   (in_a),
        .in_b   (in_b),
        .out    (out)
    );

    integer pass = 0, fail = 0;

    task check;
        input [31:0] expected;
        begin
            #1;
            if (out === expected) begin
                $display("  PASS: op=%04b  a=%08h  b=%08h -> %08h", alu_op, in_a, in_b, out);
                pass = pass + 1;
            end else begin
                $display("  FAIL: op=%04b  a=%08h  b=%08h -> got %08h, expected %08h",
                         alu_op, in_a, in_b, out, expected);
                fail = fail + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_alu.vcd");
        $dumpvars(0, tb_alu);
        $display("=== ALU unit tests ===");

        $display("-- VADD (4'b0000) --");
        alu_op = 4'b0000;
        in_a = 32'd10;       in_b = 32'd20;       check(32'd30);
        in_a = 32'hFFFFFFFF; in_b = 32'd1;         check(32'd0);
        in_a = 32'd0;        in_b = 32'd0;         check(32'd0);

        $display("-- VSUB (4'b1000) --");
        alu_op = 4'b1000;
        in_a = 32'd50;       in_b = 32'd15;        check(32'd35);
        in_a = 32'd0;        in_b = 32'd1;         check(32'hFFFFFFFF);
        in_a = 32'hABCD;     in_b = 32'hABCD;      check(32'd0);

        $display("-- VSLL (4'b0001) --");
        alu_op = 4'b0001;
        in_a = 32'h00000001; in_b = 32'd4;         check(32'h00000010);
        in_a = 32'h00000001; in_b = 32'd31;        check(32'h80000000);
        in_a = 32'hFFFFFFFF; in_b = 32'd0;         check(32'hFFFFFFFF);
        in_a = 32'h80000000; in_b = 32'd1;         check(32'h00000000);

        $display("-- VSLT (4'b0010) --");
        alu_op = 4'b0010;
        in_a = 32'd5;        in_b = 32'd10;        check(32'd1);
        in_a = 32'd10;       in_b = 32'd5;         check(32'd0);
        in_a = 32'd5;        in_b = 32'd5;         check(32'd0);
        in_a = 32'hFFFFFFFF; in_b = 32'd0;         check(32'd1);
        in_a = 32'd1;        in_b = 32'hFFFFFFFF;  check(32'd0);

        $display("-- VSLTU (4'b0011) --");
        alu_op = 4'b0011;
        in_a = 32'd5;        in_b = 32'd10;        check(32'd1);
        in_a = 32'd10;       in_b = 32'd5;         check(32'd0);
        in_a = 32'hFFFFFFFF; in_b = 32'd0;         check(32'd0);
        in_a = 32'd0;        in_b = 32'hFFFFFFFF;  check(32'd1);

        $display("-- VXOR (4'b0100) --");
        alu_op = 4'b0100;
        in_a = 32'hAAAAAAAA; in_b = 32'h55555555;  check(32'hFFFFFFFF);
        in_a = 32'hFFFFFFFF; in_b = 32'hFFFFFFFF;  check(32'h00000000);
        in_a = 32'hDEADBEEF; in_b = 32'h00000000;  check(32'hDEADBEEF);

        $display("-- VSRL (4'b0101) --");
        alu_op = 4'b0101;
        in_a = 32'h80000000; in_b = 32'd1;         check(32'h40000000);
        in_a = 32'hF0000000; in_b = 32'd4;         check(32'h0F000000);
        in_a = 32'hFFFFFFFF; in_b = 32'd0;         check(32'hFFFFFFFF);
        in_a = 32'hFFFFFFFF; in_b = 32'd31;        check(32'h00000001);

        $display("-- VSRA (4'b1101) --");
        alu_op = 4'b1101;
        in_a = 32'h80000000; in_b = 32'd1;         check(32'hC0000000);
        in_a = 32'hF0000000; in_b = 32'd4;         check(32'hFF000000);
        in_a = 32'h7FFFFFFF; in_b = 32'd1;         check(32'h3FFFFFFF);
        in_a = 32'hFFFFFFFF; in_b = 32'd31;        check(32'hFFFFFFFF);

        $display("-- VOR (4'b0110) --");
        alu_op = 4'b0110;
        in_a = 32'hF0F00000; in_b = 32'h00000F0F;  check(32'hF0F00F0F);
        in_a = 32'hAAAAAAAA; in_b = 32'h55555555;  check(32'hFFFFFFFF);
        in_a = 32'h00000000; in_b = 32'h00000000;  check(32'h00000000);

        $display("-- VAND (4'b0111) --");
        alu_op = 4'b0111;
        in_a = 32'hFF00FF00; in_b = 32'h0F0F0F0F;  check(32'h0F000F00);
        in_a = 32'hFFFFFFFF; in_b = 32'h00000000;  check(32'h00000000);
        in_a = 32'hAAAAAAAA; in_b = 32'hFFFFFFFF;  check(32'hAAAAAAAA);

        $display("-- Default --");
        alu_op = 4'b1001; in_a = 32'hFFFFFFFF; in_b = 32'hFFFFFFFF; check(32'h0);
        alu_op = 4'b1010; in_a = 32'hFFFFFFFF; in_b = 32'hFFFFFFFF; check(32'h0);

        $display("=== Results: %0d passed, %0d failed ===", pass, fail);
        $finish;
    end
endmodule
