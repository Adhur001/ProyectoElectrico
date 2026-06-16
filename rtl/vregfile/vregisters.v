module vregisters (
    input         clk,
    input         rst,
    input         we,
    input  [4:0]  addr_a,
    input  [4:0]  addr_b,
    input  [4:0]  addr_c,    // puerto dedicado para lectura del VLSU (vs3 en stores)
    input  [4:0]  addr_d,    // puerto dedicado para lectura del VLSU (vs2 en indexed)
    input  [4:0]  addr_w,
    input  [127:0] data_in,
    output [127:0] data_a,
    output [127:0] data_b,
    output [127:0] data_c,
    output [127:0] data_d
);
    reg [127:0] regs [0:31];

    integer j;
    always @(posedge clk) begin
        if (rst) begin      // El reset pone todos los registros zero  
            for (j = 0; j < 32; j = j + 1)
                regs[j] <= 128'b0;
        end else if (we) begin
            regs[addr_w] <= data_in;
        end
    end

    // v0 es el registro de mascara, puede leerse y escribirse libremente (spec RVV)
    assign data_a = regs[addr_a];
    assign data_b = regs[addr_b];
    assign data_c = regs[addr_c];
    assign data_d = regs[addr_d];
endmodule
