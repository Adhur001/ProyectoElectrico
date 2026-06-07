`include "../module/core/ALU.sv"
`include "../module/core/decode.sv"
`include "../module/Vregisters/vregisters.sv"

// Decode + Execute wrapper
// Input:  clk, reset, instruction
// Flow:   decode_unit -> vregisters <-> ALU_array (writeback loop)
// sel=1 -> dummy_data_in + dummy_addr load directly into vregisters (for testing)
// sel=0 -> ALU result writes back into vregisters (normal operation)
module decode_execute (
    input logic         clk,
    input logic         reset,
    input logic         enable_decode,
    input logic [31:0]  instruction,
    input logic [127:0] dummy_data_in,  // test: pre-load register data
    input logic [4:0]   dummy_addr,
    input logic         sel           // test: 1=load dummy, 0=ALU writeback
);

    // ── Decode outputs ────────────────────────────────────────────────── //
    logic [4:0] addr_vs1;
    logic [4:0] addr_vs2;
    logic [4:0] addr_wb_dec;
    logic       wr_en;
    logic       enable_ALU;
    logic [2:0] alu_op;

    decode_unit decoder (
        .clk          (clk),
        .reset        (reset),
        .enable_decode(enable_decode),
        .instruction  (instruction),
        .alu_op       (alu_op),
        .addr_A       (addr_vs1),
        .addr_B       (addr_vs2),
        .addr_W       (addr_wb_dec),
        .write        (wr_en),
        .enable_ALU   (enable_ALU)
    );

    // ── Register file ─────────────────────────────────────────────────── //
    logic [127:0] vs1_data, vs2_data, vd_data_wb, data_selected;
    logic [4:0]   addr_w;
    logic         wr_en_final;
    // Writeback mux: dummy data for testing, or ALU result for normal ops
    assign data_selected = sel ? dummy_data_in : vd_data_wb;
    assign addr_w        = sel ? dummy_addr    : addr_wb_dec;
    assign wr_en_final   = sel ? 1'b1          : wr_en;  // force write during pre-load

    vregisters Vregs (
        .clk    (clk),
        .write  (wr_en_final),
        .addr_A (addr_vs1),
        .addr_B (addr_vs2),
        .addr_W (addr_w),
        .data_in(data_selected),
        .data_A (vs1_data),
        .data_B (vs2_data)
    );

    // ── Lane slicing: 128-bit → 4 × 32-bit ───────────────────────────── //
    logic [31:0] vs1_lanes [4];
    logic [31:0] vs2_lanes [4];
    logic [31:0] vd_lanes  [4];

    assign vs1_lanes[0] = vs1_data[127:96];
    assign vs1_lanes[1] = vs1_data[95:64];
    assign vs1_lanes[2] = vs1_data[63:32];
    assign vs1_lanes[3] = vs1_data[31:0];

    assign vs2_lanes[0] = vs2_data[127:96];
    assign vs2_lanes[1] = vs2_data[95:64];
    assign vs2_lanes[2] = vs2_data[63:32];
    assign vs2_lanes[3] = vs2_data[31:0];

    // Reassemble ALU lanes → 128-bit writeback into vregisters
    assign vd_data_wb = {vd_lanes[0], vd_lanes[1], vd_lanes[2], vd_lanes[3]};

    // ── Execute: 4-lane SIMD ALU ──────────────────────────────────────── //
    ALU_array #(.SIZE(32), .N(4)) alu (
        .enable (enable_ALU),
        .alu_op (alu_op),
        .in_A   (vs1_lanes),
        .in_B   (vs2_lanes),
        .out    (vd_lanes)
    );

endmodule
