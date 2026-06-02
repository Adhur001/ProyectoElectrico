module vregisters (
    input         clk,
    input         rst,
    input         we,
    input  [4:0]  addr_a,
    input  [4:0]  addr_b,
    input  [4:0]  addr_w,
    input  [127:0] data_in,
    output [127:0] data_a,
    output [127:0] data_b
);
    reg [127:0] regs [0:31];

    integer j;
    always @(posedge clk) begin
        if (rst) begin
            for (j = 0; j < 32; j = j + 1)
                regs[j] <= 128'b0;
        end else if (we) begin
            regs[addr_w] <= data_in;
        end
    end

    // v0 es el registro de mascara, puede leerse y escribirse libremente (spec RVV)
    assign data_a = regs[addr_a];
    assign data_b = regs[addr_b];
endmodule
