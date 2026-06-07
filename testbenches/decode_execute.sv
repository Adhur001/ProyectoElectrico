`include "../wrappers/decode_execute.sv"
`include "../testers/decode_execute.sv"

module decode_execute_tb ();

    logic         clk;
    logic         reset;
    logic         enable_decode;
    logic [4:0]   dummy_addr;
    logic [31:0]  instruction;
    logic [127:0] dummy_data_in;
    logic         sel;

    // ── DUT ──────────────────────────────────────────────────────────── //
    decode_execute DUT (
        .clk          (clk),
        .reset        (reset),
        .enable_decode(enable_decode),
        .instruction  (instruction),
        .dummy_data_in(dummy_data_in),
        .dummy_addr   (dummy_addr),
        .sel          (sel)
    );

    // ── Stimulus ─────────────────────────────────────────────────────── //
    tester TB (
        .clk          (clk),
        .reset        (reset),
        .enable_decode(enable_decode),
        .dummy_addr   (dummy_addr),
        .instruction  (instruction),
        .dummy_data_in(dummy_data_in),
        .sel          (sel)
    );

    // ── Waveform dump ─────────────────────────────────────────────────── //
    initial begin
        $dumpfile("waves.vcd");
        $dumpvars(0, decode_execute_tb);
    end

endmodule
