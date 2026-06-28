`timescale 1ns/1ps
module tb_vregisters;
    reg        clk, rst, we;
    reg [4:0]  addr_a, addr_b, addr_w;
    reg [127:0] data_in;
    wire [127:0] data_a, data_b;

    vregisters dut (
        .clk     (clk),
        .rst     (rst),
        .we      (we),
        .addr_a  (addr_a),
        .addr_b  (addr_b),
        .addr_w  (addr_w),
        .data_in (data_in),
        .data_a  (data_a),
        .data_b  (data_b)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer pass = 0, fail = 0;
    task check_a;
        input [127:0] expected;
         begin
            if (data_a === expected) begin
                $display("  PASS data_a: got %h", data_a);
                pass = pass + 1;
            end else begin
                $display("  FAIL data_a: got %h, expected %h", data_a, expected);
                fail = fail + 1;
            end
        end
    endtask

    task check_b;
        input [127:0] expected;
        begin
            if (data_b === expected) begin
                $display("  PASS data_b: got %h", data_b);
                pass = pass + 1;
            end else begin
                $display("  FAIL data_b: got %h, expected %h", data_b, expected);
                fail = fail + 1;
            end
        end
    endtask

        // en este initial se espera a un posedge del clk para mandar las instrucciones  
initial begin
        $dumpfile("tb_vregfile.vcd");
        $dumpvars(0, tb_vregisters);
        $display("=== vregfile unit tests ===");

        // -- Reset --
        rst = 1; we = 0;
        addr_a = 0; addr_b = 0; addr_w = 0; data_in = 128'hFFFF;
        @(posedge clk); #1;
        rst = 0;

        // -- Write v1 --
        $display("Test: write v1 = {4{32'hEEEEEEEE}}");
        we = 1; addr_w = 5'd1; data_in = {4{32'hEEEEEEEE}};
        @(posedge clk); #1;
        we = 0;
        addr_a = 5'd1;
        #1;
        check_a({4{32'hEEEEEEEE}});

        // -- Overwrite v1 --
        $display("Test: overwrite v1 = {4{32'hAAAAAAAA}}");
        we = 1; addr_w = 5'd1; data_in = {4{32'hAAAAAAAA}};
        @(posedge clk); #1;
        we = 0;
        addr_a = 5'd1;
        #1;
        check_a({4{32'hAAAAAAAA}});

        // -- Dual-port read: write v2 and v3, read simultaneously --
        $display("Test: dual-port read v2/v3");
        we = 1;
        addr_w = 5'd2; data_in = {4{32'hAAAAAAAA}};
        @(posedge clk); #1;
        addr_w = 5'd3; data_in = {4{32'h55555555}};
        @(posedge clk); #1;
        we = 0;
        addr_a = 5'd2; addr_b = 5'd3;
        #1;
        check_a({4{32'hAAAAAAAA}});
        check_b({4{32'h55555555}});

        // -- No write when we=0 --
        $display("Test: no write when we=0");
        we = 0; addr_w = 5'd2; data_in = 128'hDDDD;
        @(posedge clk); #1;
        addr_a = 5'd2;
        #1;
        check_a({4{32'hAAAAAAAA}}); // must retain previous value

        // -- Reset clears all registers --
        $display("Test: reset clears all registers");
        rst = 1;
        @(posedge clk); #1;
        rst = 0;
        addr_a = 5'd1; addr_b = 5'd3;
        #1;
        check_a(128'b0);
        check_b(128'b0);

        $display("=== Results: %0d passed, %0d failed ===", pass, fail);
        $finish;
    end
endmodule
