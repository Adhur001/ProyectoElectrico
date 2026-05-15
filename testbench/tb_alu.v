module tb_alu;
    reg  [2:0]  alu_op;
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
                $display("  PASS: op=%03b  a=%08h  b=%08h → %08h", alu_op, in_a, in_b, out);
                pass = pass + 1;
            end else begin
                $display("  FAIL: op=%03b  a=%08h  b=%08h → got %08h, expected %08h",
                         alu_op, in_a, in_b, out, expected);
                fail = fail + 1;
            end
        end
endtask

    initial begin
        $dumpfile("tb_alu.vcd");
        $dumpvars(0, tb_alu);
        $display("=== ALU unit tests ===");

        // VADD (000)
        alu_op = 3'b000;
        in_a = 32'd10;    in_b = 32'd20;    check(32'd30);
        in_a = 32'hFFFFFFFF; in_b = 32'd1;  check(32'd0); 
        in_a = 32'd0;     in_b = 32'd0;     check(32'd0);

        // VSUB (001)
        alu_op = 3'b001;
        in_a = 32'd50;    in_b = 32'd15;    check(32'd35);
        in_a = 32'd0;     in_b = 32'd1;     check(32'hFFFFFFFF); 
        in_a = 32'hABCD;  in_b = 32'hABCD;  check(32'd0);

        // VAND (010)
        alu_op = 3'b010;
        in_a = 32'hFF00FF00; in_b = 32'h0F0F0F0F; check(32'h0F000F00);
        in_a = 32'hFFFFFFFF; in_b = 32'h00000000; check(32'h00000000);
        in_a = 32'hAAAAAAAA; in_b = 32'hFFFFFFFF; check(32'hAAAAAAAA);

        // VOR (011)
        alu_op = 3'b011;
        in_a = 32'hF0F00000; in_b = 32'h00000F0F; check(32'hF0F00F0F);
        in_a = 32'h00000000; in_b = 32'h00000000; check(32'h00000000);
        in_a = 32'hAAAAAAAA; in_b = 32'h55555555; check(32'hFFFFFFFF);

        // VXOR (100)
        alu_op = 3'b100;
        in_a = 32'hAAAAAAAA; in_b = 32'h55555555; check(32'hFFFFFFFF);
        in_a = 32'hFFFFFFFF; in_b = 32'hFFFFFFFF; check(32'h00000000);
        in_a = 32'hDEADBEEF; in_b = 32'h00000000; check(32'hDEADBEEF);

        // Default (should output 0)
        alu_op = 3'b101; in_a = 32'hFFFFFFFF; in_b = 32'hFFFFFFFF; check(32'h0);
        alu_op = 3'b110; in_a = 32'hFFFFFFFF; in_b = 32'hFFFFFFFF; check(32'h0);
        alu_op = 3'b111; in_a = 32'hFFFFFFFF; in_b = 32'hFFFFFFFF; check(32'h0);

        $display("=== Results: %0d passed, %0d failed ===", pass, fail);
        $finish;
    end
endmodule

