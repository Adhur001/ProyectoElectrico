// Tester for decode_execute wrapper

module tester (
    output logic         clk,
    output logic         reset,
    output logic         enable_decode,
    output logic [4:0]   dummy_addr,
    output logic [31:0]  instruction,
    output logic [127:0] dummy_data_in,
    output logic         sel
);

initial begin
    // ── Init ─────────────────────────────────────────────────────────── //
    clk           = 1;
    reset         = 1;
    enable_decode = 0;
    dummy_addr    = '0;
    sel           = 1;
    dummy_data_in = '0;
    instruction   = '0;

    #10 reset = 0;

    // load v1 
    #5;
    dummy_data_in = {4{32'hDEAD_BEEF}};
    dummy_addr    = 5'd6;        // addr_w mux → v1
    #10;

    // load v2
    dummy_data_in = {4{32'h0404_9292}};
    dummy_addr    = 5'd7;        // addr_w mux → v2
    #10;

    // testing vadd
    sel           = 0;           // ALU result feeds back into vregisters
    dummy_data_in = '0;
    dummy_addr    = '0;
    instruction   = 32'b000000_0_00111_00110_000_00100_1010111; // VADD v4, v6, v7, vm
    enable_decode = 1;
    #10 enable_decode = 0;

    #20 $finish;
end

always #5 clk = ~clk;

endmodule
