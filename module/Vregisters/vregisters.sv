// Single 128-bit register
module vregister (
    input  logic        clk,
    input  logic        write,
    input  logic [127:0] data_in,
    output logic [127:0] data_out
);
    logic [127:0] register;

    always @(posedge clk) begin
        if (write)
            register <= data_in;
    end

    assign data_out = register;  // always readable

endmodule


// 32-entry register file
module vregisters (
    input  logic        clk,
    input  logic        write,
    input  logic [4:0]  addr,       // 5 bits → 32 addresses
    input  logic [127:0] data_in,
    output logic [127:0] data_out
);

    // write enable for each register
    logic write_en [32];

    // output of each register
    logic [127:0] reg_out [32];

    // address decoder — only enable the selected register
    genvar i;
    for (i = 0; i < 32; i++) begin : reg_array
        assign write_en[i] = write && (addr == i);

        vregister reg_inst (
            .clk     (clk),
            .write   (write_en[i]),
            .data_in (data_in),
            .data_out(reg_out[i])
        );
    end

    // read: just mux the selected register's output
    assign data_out = reg_out[addr];

endmodule
