// Single 128-bit register
module vregister (
    input  logic         clk,
    input  logic         write,
    input  logic [127:0] data_in,
    output logic [127:0] data_out
);
    logic [127:0] register;

    always @(posedge clk) begin
        if (write)
            register <= data_in;
    end

    assign data_out = register;
endmodule


// 32-entry register file
module vregisters (
    input  logic         clk,
    input  logic         write,
    input  logic [4:0]   addr_A,
    input  logic [4:0]   addr_B,
    input  logic [4:0]   addr_W,
    input  logic [127:0] data_in,
    output logic [127:0] data_A,
    output logic [127:0] data_B 
);

    logic        write_en [32];
    logic [127:0] reg_out [32];

    genvar i;
    for (i = 0; i < 32; i++) begin : reg_array
        assign write_en[i] = write && (addr_W == i); 

        vregister reg_inst (
            .clk     (clk),
            .write   (write_en[i]),
            .data_in (data_in),
            .data_out(reg_out[i])
        );
    end

    assign data_A = reg_out[addr_A];  // <-- data_A
    assign data_B = reg_out[addr_B];  // <-- data_B

endmodule
