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
// DECODIFICADOR
// Extrae y decodifica los campos de una instruccion RVV de 32 bits.
// Logica puramente combinacional.
//
// Formato (cargas y stores comparten posicion de campos):
//  31   29 28  27   26 25 24      20 19   15 14  12 11     7 6      0
// [ nf ] [mew][mop][vm][lumop/rs2 ][ rs1  ][width][vd/vs3 ][ opcode ]
//
// mop encoding:
//   00 = unit-stride   (bits[24:20] = lumop/sumop)
//   10 = strided       (bits[24:20] = rs2, indice del registro de stride)
//
// lumop/sumop (mop=00): 00000=unit-stride  01000=whole-reg  01011=mask
// =============================================================================

module vlsu_decoder (
    input  wire [31:0] i_instr,

    output wire [4:0]  o_vd,              // registro vectorial destino (carga) / fuente (store)
    output wire [4:0]  o_rs1,             // indice del registro escalar con la direccion base
    output wire [4:0]  o_rs2,             // indice del registro escalar de stride (mop=10)
    output wire [2:0]  o_width,           // EEW: 000=8b 101=16b 110=32b 111=64b
    output wire        o_vm,              // 1=sin mascara, 0=enmascarado con v0
    output wire [4:0]  o_lumop,           // lumop/sumop (mop=00) o rs2 idx (mop=10)
    output wire [1:0]  o_mop,             // modo de direccionamiento
    output wire [2:0]  o_nf,              // NFIELDS-1

    // tipo de instruccion — unit-stride (mop=00)
    output wire        o_is_load,         // opcode == 0000111
    output wire        o_is_unit_stride,  // VLE<eew>.v   (load,  lumop=00000)
    output wire        o_is_whole_reg,    // VL1RE32.v    (load,  lumop=01000)
    output wire        o_is_mask_load,    // VLM.v        (load,  lumop=01011)
    output wire        o_is_store,        // opcode == 0100111
    output wire        o_is_unit_store,   // VSE<eew>.v   (store, sumop=00000)
    output wire        o_is_whole_store,  // VS1R.v       (store, sumop=01000)
    output wire        o_is_mask_store,   // VSM.v        (store, sumop=01011)

    // tipo de instruccion — constant-stride (mop=10)
    output wire        o_is_strided_load, // VLSE<eew>.v
    output wire        o_is_strided_store,// VSSE<eew>.v

    // tipo de instruccion — indexed unordered (mop=01)
    output wire        o_is_indexed_load, // vluxei<eew>.v
    output wire        o_is_indexed_store // vsuxei<eew>.v
);

    wire [6:0] opcode;
    assign opcode = i_instr[6:0];

    // Extraccion directa de campos
    assign o_vd    = i_instr[11:7];
    assign o_width = i_instr[14:12];
    assign o_rs1   = i_instr[19:15];
    assign o_rs2   = i_instr[24:20];  // rs2 idx (usado como stride en mop=10)
    assign o_lumop = i_instr[24:20];  // mismo bits, alias semantico para mop=00
    assign o_vm    = i_instr[25];
    assign o_mop   = i_instr[27:26];
    assign o_nf    = i_instr[31:29];

    // Deteccion de opcode
    assign o_is_load  = (opcode == 7'b0000111);
    assign o_is_store = (opcode == 7'b0100111);

    // Sub-tipos unit-stride (mop=00)
    assign o_is_unit_stride = o_is_load  && (o_mop == 2'b00) && (o_lumop == 5'b00000);
    assign o_is_whole_reg   = o_is_load  && (o_mop == 2'b00) && (o_lumop == 5'b01000);
    assign o_is_mask_load   = o_is_load  && (o_mop == 2'b00) && (o_lumop == 5'b01011);
    assign o_is_unit_store  = o_is_store && (o_mop == 2'b00) && (o_lumop == 5'b00000);
    assign o_is_whole_store = o_is_store && (o_mop == 2'b00) && (o_lumop == 5'b01000);
    assign o_is_mask_store  = o_is_store && (o_mop == 2'b00) && (o_lumop == 5'b01011);

    // Constant-stride (mop=10)
    assign o_is_strided_load  = o_is_load  && (o_mop == 2'b10);
    assign o_is_strided_store = o_is_store && (o_mop == 2'b10);

    // Indexed unordered (mop=01)
    assign o_is_indexed_load  = o_is_load  && (o_mop == 2'b01);
    assign o_is_indexed_store = o_is_store && (o_mop == 2'b01);

endmodule


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

    input  wire        i_valid,           // instruccion valida en la entrada
    input  wire [31:0] i_instr,           // instruccion RVV de 32 bits
    input  wire [31:0] i_base_addr,       // direccion base (simula rs1 del host)
    input  wire [31:0] i_stride,          // stride en bytes (simula rs2, para VLSE/VSSE)

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
    // Instancia del decodificador
    // -------------------------------------------------------------------------
    wire [4:0]  dec_vd;
    wire [4:0]  dec_vs2;
    wire        dec_is_load;
    wire        dec_is_store;
    wire        dec_is_mask_load;
    wire        dec_is_mask_store;
    wire        dec_is_strided_load;
    wire        dec_is_strided_store;
    wire        dec_is_indexed_load;
    wire        dec_is_indexed_store;

    vlsu_decoder decoder (
        .i_instr            (i_instr),
        .o_vd               (dec_vd),
        .o_rs1              (),
        .o_rs2              (dec_vs2),
        .o_width            (),
        .o_vm               (),
        .o_lumop            (),
        .o_mop              (),
        .o_nf               (),
        .o_is_load          (dec_is_load),
        .o_is_unit_stride   (),
        .o_is_whole_reg     (),
        .o_is_mask_load     (dec_is_mask_load),
        .o_is_store         (dec_is_store),
        .o_is_unit_store    (),
        .o_is_whole_store   (),
        .o_is_mask_store    (dec_is_mask_store),
        .o_is_strided_load  (dec_is_strided_load),
        .o_is_strided_store (dec_is_strided_store),
        .o_is_indexed_load  (dec_is_indexed_load),
        .o_is_indexed_store (dec_is_indexed_store)
    );

    wire dec_valid_instr = dec_is_load || dec_is_store;
    wire dec_is_mask_op  = dec_is_mask_load || dec_is_mask_store;

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
                    if (i_valid && dec_valid_instr) begin
                        vd_reg         <= dec_vd;
                        vs2_reg        <= dec_vs2;
                        base_addr_reg  <= i_base_addr;
                        stride_reg     <= i_stride;
                        is_mask_reg    <= dec_is_mask_op;
                        is_store_reg   <= dec_is_store;
                        is_strided_reg <= dec_is_strided_load || dec_is_strided_store;
                        is_indexed_reg <= dec_is_indexed_load || dec_is_indexed_store;
                        // captura los offsets de vs2 para indexed (puerto D del VRF)
                        offset_buf     <= i_vrf_offset;
                        if (dec_is_store) begin
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
    assign o_vs3 = (state == IDLE) ? dec_vd : vd_reg;

    // o_vs2: presenta el indice de vs2 combinacionalmente en IDLE para que
    // i_vrf_offset este listo antes del flanco que captura offset_buf
    assign o_vs2 = (state == IDLE) ? dec_vs2 : vs2_reg;

    // -------------------------------------------------------------------------
    // Logica combinacional: scoreboard
    // Solo las cargas reclaman un registro destino
    // -------------------------------------------------------------------------
    assign o_scoreboard_set = (state == IDLE) && i_valid && dec_is_load;
    assign o_scoreboard_clr = (state == WRITEBACK);

    assign o_busy = (state != IDLE);
    assign o_vd   = vd_reg;

endmodule
