// =============================================================================
// Generador combinacional de accesos LSU vectorial
//
// Un vector de 128 bits contiene 4 elementos de 32 bits. El DCache tiene dos
// puertos (A y B), por lo que se procesan 2 elementos por ciclo en 2 fases:
//
//   i_phase = 2'b00 → ACCESS_01: elem_0 → puerto A,  elem_1 → puerto B
//   i_phase = 2'b01 → ACCESS_23: elem_2 → puerto A,  elem_3 → puerto B
//
// El modulo upstream avanza i_phase entre ciclos. Este modulo solo traduce
// la fase actual a senales de bus; no tiene estado interno.
// i_en = 0 desactiva todos los enables de DCache.
// =============================================================================

module vlsu (
    input  wire [1:0]   i_phase,      // 2'b00=ACCESS_01  2'b01=ACCESS_23
    input  wire         i_en,         // habilita cualquier acceso a memoria

    input  wire         i_is_load,
    input  wire         i_is_store,
    input  wire         i_is_mask_op, // solo accede al primer elemento de la fase
    input  wire         i_is_strided,
    input  wire         i_is_indexed,

    input  wire [31:0]  i_base_addr,
    input  wire [31:0]  i_stride,
    input  wire [127:0] i_offset_buf, // vs2: offsets para acceso indexado (un offset de 32b por elemento)

    input  wire [127:0] i_wdata,      // vs3: datos a escribir en stores (4 palabras de 32b empaquetadas)

    // Interfaz con DCache — puerto A (elemento par de cada fase)
    output reg  [31:0]  o_mem_addr,
    output reg          o_mem_read_en,
    output reg          o_mem_write_en,
    output reg  [31:0]  o_mem_wdata,
    output reg  [3:0]   o_mem_byte_en,

    // Interfaz con DCache — puerto B (elemento impar de cada fase)
    output reg  [31:0]  o_mem_addr_b,
    output reg          o_mem_read_en_b,
    output reg          o_mem_write_en_b,
    output reg  [31:0]  o_mem_wdata_b,
    output reg  [3:0]   o_mem_byte_en_b
);

    // -------------------------------------------------------------------------
    // Calculo de direcciones para los 4 elementos
    //
    // step: salto entre elementos consecutivos en bytes.
    //   - Strided:    usa i_stride (puede ser cualquier valor, incluso negativo)
    //   - Unit-stride e indexed: 4 bytes (un word de 32b)
    //
    // Modos de direccionamiento:
    //   - Unit-stride: base, base+4,        base+8,        base+12
    //   - Strided:     base, base+stride,   base+stride*2, base+stride*3
    //   - Indexed:     base+offset[0],      base+offset[1], ...  (offsets de vs2)
    //
    // Las cuatro direcciones se calculan siempre; el case del bloque always
    // selecciona cuales enviar al DCache segun la fase activa.
    // -------------------------------------------------------------------------

    wire [31:0] step = i_is_strided ? i_stride : 32'd4;

    wire [31:0] addr_0 = i_is_indexed ? (i_base_addr + i_offset_buf[31:0])   : i_base_addr;
    wire [31:0] addr_1 = i_is_indexed ? (i_base_addr + i_offset_buf[63:32])  : (i_base_addr + step);
    wire [31:0] addr_2 = i_is_indexed ? (i_base_addr + i_offset_buf[95:64])  : (i_base_addr + step * 2);
    wire [31:0] addr_3 = i_is_indexed ? (i_base_addr + i_offset_buf[127:96]) : (i_base_addr + step * 3);

    // -------------------------------------------------------------------------
    // Generacion de senales de control segun fase
    // -------------------------------------------------------------------------

    always @(*) begin
        // Defaults: ambos puertos desactivados (i_en=0 o fase invalida)
        o_mem_addr       = 32'b0;
        o_mem_read_en    = 1'b0;
        o_mem_write_en   = 1'b0;
        o_mem_wdata      = 32'b0;
        o_mem_byte_en    = 4'b1111;

        o_mem_addr_b     = 32'b0;
        o_mem_read_en_b  = 1'b0;
        o_mem_write_en_b = 1'b0;
        o_mem_wdata_b    = 32'b0;
        o_mem_byte_en_b  = 4'b1111;

        if (i_en) begin
            case (i_phase)

                // -------------------------------------------------------------
                // ACCESS_01: accede a elem_0 (puerto A) y elem_1 (puerto B)
                //
                // Con i_is_mask_op solo se accede a elem_0:
                //   - Puerto B queda desactivado (read/write_en = 0)
                //   - byte_en del puerto A se reduce a 4'b0001 (solo byte 0)
                // -------------------------------------------------------------
                2'b00: begin
                    // Puerto A → elem_0
                    o_mem_addr        = addr_0;
                    o_mem_read_en     = i_is_load;
                    o_mem_write_en    = i_is_store;
                    o_mem_wdata       = i_wdata[31:0];
                    o_mem_byte_en     = i_is_mask_op ? 4'b0001 : 4'b1111;

                    // Puerto B → elem_1 (desactivado si mask_op)
                    o_mem_addr_b      = addr_1;
                    o_mem_read_en_b   = i_is_load  && !i_is_mask_op;
                    o_mem_write_en_b  = i_is_store && !i_is_mask_op;
                    o_mem_wdata_b     = i_wdata[63:32];
                    o_mem_byte_en_b   = 4'b1111;
                end

                // -------------------------------------------------------------
                // ACCESS_23: accede a elem_2 (puerto A) y elem_3 (puerto B)
                //
                // Ambos puertos siempre activos; mask_op solo afecta ACCESS_01.
                // -------------------------------------------------------------
                2'b01: begin
                    // Puerto A → elem_2
                    o_mem_addr        = addr_2;
                    o_mem_read_en     = i_is_load;
                    o_mem_write_en    = i_is_store;
                    o_mem_wdata       = i_wdata[95:64];
                    o_mem_byte_en     = 4'b1111;

                    // Puerto B → elem_3
                    o_mem_addr_b      = addr_3;
                    o_mem_read_en_b   = i_is_load;
                    o_mem_write_en_b  = i_is_store;
                    o_mem_wdata_b     = i_wdata[127:96];
                    o_mem_byte_en_b   = 4'b1111;
                end

                default: ; // fase invalida con i_en=1 → puertos desactivados por defaults
            endcase
        end
    end

endmodule
