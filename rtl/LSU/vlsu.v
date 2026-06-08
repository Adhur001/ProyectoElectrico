// =============================================================================
// Unidad de Carga y Almacenamiento Vectorial (VLSU)
// Opcodes segun especificacion RVV:
//   0000111 (LOAD-FP)  — cargas vectoriales
//   0100111 (STORE-FP) — almacenamientos vectoriales
// Instrucciones soportadas:
//   Unit-stride:     VLE32.v, VL1RE32.v, VLM.v, VSE32.v, VS1R.v, VSM.v
//   Constant-stride: VLSE32.v, VSSE32.v
// =============================================================================


// =============================================================================
// VLSU TOP
//
// Nota sobre rs1:
//   Sin interfaz con el host, la direccion base llega como i_base_addr
//   desde el testbench. Al integrar el host, i_base_addr se conectara
//   a la salida del banco de registros escalares indexado por o_rs1.
//
// Nota sobre i_vrf_rdata / o_vs3:
//   Para stores el VLSU necesita leer vs3 del banco de registros vectoriales.
//   o_vs3 presenta el indice combinatorialmenete; i_vrf_rdata debe conectarse
//   al puerto de lectura del VRF en ve_top. En el testbench se maneja directo.
// =============================================================================

module vlsu (
    input  wire        clk,
    input  wire        rst,

    input  wire        i_valid,           // instruccion valida (viene de o_vec_lsu_valid del decode)

    // Campos pre-decodificados — vienen de Modified_DecodeUnit
    input  wire [4:0]  i_vd,             // registro vectorial destino (carga) / fuente (store)
    input  wire [4:0]  i_vs2,            // registro de offsets vs2 (indexed) / stride rs2
    input  wire        i_is_load,        // opcode == 0000111
    input  wire        i_is_store,       // opcode == 0100111
    input  wire        i_is_mask_op,     // variante mascara (VLM / VSM)
    input  wire        i_is_strided,     // modo constant-stride (mop=10)
    input  wire        i_is_indexed,     // modo indexed-unordered (mop=01)
    input  wire [31:0] i_base_addr,      // valor de rs1 leido del RF escalar (direccion base)
    input  wire [31:0] i_stride,         // valor de rs2 leido del RF escalar (stride)

    // Interfaz con DCache
    output wire [31:0] o_mem_addr,        // direccion de acceso
    output wire        o_mem_read_en,     // habilita lectura combinacional (cargas)
    input  wire [31:0] i_mem_rdata,       // dato leido desde DCache
    output wire        o_mem_write_en,    // habilita escritura sincrona (stores)
    output wire [31:0] o_mem_wdata,       // dato a escribir en DCache
    output wire [3:0]  o_mem_byte_en,     // byte enables (VSM usa 4'b0001)

    // Interfaz con banco de registros vectoriales
    output wire        o_vrf_we,          // write enable (cargas: writeback)
    output wire [4:0]  o_vrf_addr,        // indice del registro destino
    output wire [127:0] o_vrf_data,       // dato de 128 bits a escribir
    input  wire [127:0] i_vrf_rdata,      // dato de 128 bits leido de vs3 (stores, puerto C)
    output wire [4:0]   o_vs3,            // indice del registro fuente vs3 (stores)
    input  wire [127:0] i_vrf_offset,     // dato de 128 bits leido de vs2 (indexed, puerto D)
    output wire [4:0]   o_vs2,            // indice del registro de offsets vs2 (indexed)

    // Interfaz con scoreboard (en ve_top)
    output wire        o_busy,            // VLSU ocupado
    output wire        o_scoreboard_set,  // pulso: marcar vd como ocupado (cargas)
    output wire        o_scoreboard_clr,  // pulso: liberar vd al terminar carga
    output wire [4:0]  o_vd              // registro destino reclamado (cargas)
);

    // -------------------------------------------------------------------------
    // Estados de la FSM
    // -------------------------------------------------------------------------
    localparam IDLE      = 4'd0;
    localparam ACCESS_0  = 4'd1;  // carga: lee mem[base+0]   → asm_buf[31:0]
    localparam ACCESS_1  = 4'd2;  // carga: lee mem[base+4]   → asm_buf[63:32]
    localparam ACCESS_2  = 4'd3;  // carga: lee mem[base+8]   → asm_buf[95:64]
    localparam ACCESS_3  = 4'd4;  // carga: lee mem[base+12]  → asm_buf[127:96]
    localparam WRITEBACK = 4'd5;  // carga: escribe asm_buf al VRF
    localparam SWRITE_0  = 4'd6;  // store: escribe asm_buf[31:0]   → mem[base+0]
    localparam SWRITE_1  = 4'd7;  // store: escribe asm_buf[63:32]  → mem[base+4]
    localparam SWRITE_2  = 4'd8;  // store: escribe asm_buf[95:64]  → mem[base+8]
    localparam SWRITE_3  = 4'd9;  // store: escribe asm_buf[127:96] → mem[base+12]

    // -------------------------------------------------------------------------
    // Registros internos
    // -------------------------------------------------------------------------
    reg [3:0]   state;
    reg [4:0]   vd_reg;           // destino (carga) o fuente (store)
    reg [4:0]   vs2_reg;          // registro de offsets capturado al inicio (indexed)
    reg [31:0]  base_addr_reg;    // direccion base capturada al inicio
    reg [31:0]  stride_reg;       // stride en bytes capturado al inicio (VLSE/VSSE)
    reg         is_mask_reg;      // operacion de mascara (VLM / VSM)
    reg         is_store_reg;     // indica que la operacion activa es un store
    reg         is_strided_reg;   // indica modo constant-stride (mop=10)
    reg         is_indexed_reg;   // indica modo indexed (mop=01)
    reg [127:0] asm_buf;          // buffer de 128 bits (ensamblaje en carga, diseccion en store)
    reg [127:0] offset_buf;       // offsets de vs2 capturados al inicio (indexed)

    // -------------------------------------------------------------------------
    // Logica secuencial
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            state          <= IDLE;
            vd_reg         <= 5'b0;
            vs2_reg        <= 5'b0;
            base_addr_reg  <= 32'b0;
            stride_reg     <= 32'b0;
            is_mask_reg    <= 1'b0;
            is_store_reg   <= 1'b0;
            is_strided_reg <= 1'b0;
            is_indexed_reg <= 1'b0;
            asm_buf        <= 128'b0;
            offset_buf     <= 128'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (i_valid) begin
                        vd_reg         <= i_vd;
                        vs2_reg        <= i_vs2;
                        base_addr_reg  <= i_base_addr;
                        stride_reg     <= i_stride;
                        is_mask_reg    <= i_is_mask_op;
                        is_store_reg   <= i_is_store;
                        is_strided_reg <= i_is_strided;
                        is_indexed_reg <= i_is_indexed;
                        // captura los offsets de vs2 para indexed (puerto D del VRF)
                        offset_buf     <= i_vrf_offset;
                        if (i_is_store) begin
                            // captura los 128 bits de vs3 desde el VRF (puerto C)
                            asm_buf <= i_vrf_rdata;
                            state   <= SWRITE_0;
                        end else begin
                            state   <= ACCESS_0;
                        end
                    end
                end

                // --- Estados de carga ---
                ACCESS_0: begin
                    asm_buf[31:0] <= i_mem_rdata;
                    state <= is_mask_reg ? WRITEBACK : ACCESS_1;
                end
                ACCESS_1: begin
                    asm_buf[63:32] <= i_mem_rdata;
                    state          <= ACCESS_2;
                end
                ACCESS_2: begin
                    asm_buf[95:64] <= i_mem_rdata;
                    state          <= ACCESS_3;
                end
                ACCESS_3: begin
                    asm_buf[127:96] <= i_mem_rdata;
                    state           <= WRITEBACK;
                end
                WRITEBACK: begin
                    state <= IDLE;
                end

                // --- Estados de store ---
                SWRITE_0: begin
                    // VSM: solo 1 escritura (byte bajo de la mascara)
                    state <= is_mask_reg ? IDLE : SWRITE_1;
                end
                SWRITE_1: state <= SWRITE_2;
                SWRITE_2: state <= SWRITE_3;
                SWRITE_3: state <= IDLE;

                default: state <= IDLE;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Logica combinacional: DCache
    // -------------------------------------------------------------------------
    // Generacion de direcciones segun modo:
    //   unit-stride:  base + i*4
    //   strided:      base + i*stride
    //   indexed:      base + vs2[i]  (cada offset es un word de 32 bits en offset_buf)
    wire [31:0] step = is_strided_reg ? stride_reg : 32'd4;

    wire [31:0] addr_0 = is_indexed_reg ? (base_addr_reg + offset_buf[31:0])   : base_addr_reg;
    wire [31:0] addr_1 = is_indexed_reg ? (base_addr_reg + offset_buf[63:32])  : (base_addr_reg + step);
    wire [31:0] addr_2 = is_indexed_reg ? (base_addr_reg + offset_buf[95:64])  : (base_addr_reg + (step*2));
    wire [31:0] addr_3 = is_indexed_reg ? (base_addr_reg + offset_buf[127:96]) : (base_addr_reg + (step*3));

    assign o_mem_addr =
        (state == ACCESS_0 || state == SWRITE_0) ? addr_0 :
        (state == ACCESS_1 || state == SWRITE_1) ? addr_1 :
        (state == ACCESS_2 || state == SWRITE_2) ? addr_2 :
        (state == ACCESS_3 || state == SWRITE_3) ? addr_3 :
        32'b0;

    assign o_mem_read_en  = (state == ACCESS_0) || (state == ACCESS_1) ||
                            (state == ACCESS_2) || (state == ACCESS_3);

    assign o_mem_write_en = (state == SWRITE_0) || (state == SWRITE_1) ||
                            (state == SWRITE_2) || (state == SWRITE_3);

    // VSM escribe solo el byte bajo de la mascara
    assign o_mem_byte_en = (is_mask_reg && state == SWRITE_0) ? 4'b0001 : 4'b1111;

    assign o_mem_wdata =
        (state == SWRITE_0) ? asm_buf[31:0]   :
        (state == SWRITE_1) ? asm_buf[63:32]  :
        (state == SWRITE_2) ? asm_buf[95:64]  :
        (state == SWRITE_3) ? asm_buf[127:96] :
        32'b0;

    // -------------------------------------------------------------------------
    // Logica combinacional: banco de registros vectoriales
    // -------------------------------------------------------------------------
    assign o_vrf_we   = (state == WRITEBACK);
    assign o_vrf_addr = vd_reg;
    assign o_vrf_data = is_mask_reg ? {120'b0, asm_buf[7:0]} : asm_buf;

    // o_vs3: presenta el indice de vs3 combinacionalmente en IDLE para que
    // i_vrf_rdata este listo antes del flanco que captura asm_buf
    assign o_vs3 = (state == IDLE) ? i_vd : vd_reg;

    // o_vs2: presenta el indice de vs2 combinacionalmente en IDLE para que
    // i_vrf_offset este listo antes del flanco que captura offset_buf
    assign o_vs2 = (state == IDLE) ? i_vs2 : vs2_reg;

    // -------------------------------------------------------------------------
    // Logica combinacional: scoreboard
    // Solo las cargas reclaman un registro destino
    // -------------------------------------------------------------------------
    assign o_scoreboard_set = (state == IDLE) && i_valid && i_is_load;
    assign o_scoreboard_clr = (state == WRITEBACK);

    assign o_busy = (state != IDLE);
    assign o_vd   = vd_reg;

endmodule
