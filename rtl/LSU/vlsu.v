// =============================================================================
// Unidad de Carga y Almacenamiento Vectorial (VLSU)
// Opcode segun especificacion RVV: 0000111 (LOAD-FP)
// Instrucciones soportadas: VLE32.v (unit-stride), VL1RE32.v (registro completo), VLM.v (mascara)
// =============================================================================


// =============================================================================
// DECODIFICADOR
// Extrae y decodifica los campos de una instruccion de carga RVV de 32 bits.
// Logica puramente combinacional.
//
// Formato de instruccion (especificacion RVV):
//  31   29 28  27   26 25 24  20 19   15 14  12 11   7 6      0
// [ nf ] [mew][mop][vm][ lumop ][ rs1  ][width][  vd  ][ opcode ]
// =============================================================================

module vlsu_decoder (
    input  wire [31:0] i_instr,

    output wire [4:0]  o_vd,       // registro vectorial destino
    output wire [4:0]  o_rs1,      // indice del registro escalar con la direccion base
    output wire [2:0]  o_width,    // ancho de elemento efectivo (EEW): 000=8b, 101=16b, 110=32b, 111=64b
    output wire        o_vm,       // 1=sin mascara, 0=enmascarado con v0
    output wire [4:0]  o_lumop,    // submodo de unit-stride
    output wire [1:0]  o_mop,      // modo de direccionamiento: 00=unit-stride
    output wire [2:0]  o_nf,       // numero de campos menos uno (NFIELDS-1)

    output wire        o_is_unit_stride, // VLE<eew>.v  (lumop=00000)
    output wire        o_is_whole_reg,   // VL1RE32.v   (lumop=01000)
    output wire        o_is_mask_load,   // VLM.v       (lumop=01011)
    output wire        o_valid_opcode    // opcode valido: 0000111
);

    wire [6:0] opcode;
    assign opcode = i_instr[6:0];

    // Extraccion directa de campos segun posicion de bits del spec
    assign o_vd    = i_instr[11:7];
    assign o_width = i_instr[14:12];
    assign o_rs1   = i_instr[19:15];
    assign o_lumop = i_instr[24:20];
    assign o_vm    = i_instr[25];
    assign o_mop   = i_instr[27:26];
    assign o_nf    = i_instr[31:29];

    // Senales derivadas: tipo de instruccion segun combinacion de mop y lumop
    assign o_valid_opcode   = (opcode  == 7'b0000111);
    assign o_is_unit_stride = o_valid_opcode && (o_mop == 2'b00) && (o_lumop == 5'b00000);
    assign o_is_whole_reg   = o_valid_opcode && (o_mop == 2'b00) && (o_lumop == 5'b01000);
    assign o_is_mask_load   = o_valid_opcode && (o_mop == 2'b00) && (o_lumop == 5'b01011);

endmodule


// =============================================================================
// VLSU TOP (maquina de estados + acceso a memoria + acceso a registros vectoriales)
//
// Nota sobre rs1:
//   El decodificador extrae o_rs1 (indice del registro escalar) segun el spec.
//   Por ahora, sin interfaz con el procesador host, la direccion base llega
//   directamente como i_base_addr desde el testbench.
//   Cuando se integre el host, i_base_addr se conectara a la salida del
//   banco de registros escalares indexado por o_rs1.
// =============================================================================

module vlsu (
    input  wire        clk,
    input  wire        rst,

    input  wire        i_valid,          // instruccion valida en la entrada
    input  wire [31:0] i_instr,          // instruccion RVV de 32 bits
    input  wire [31:0] i_base_addr,      // direccion base (simula salida de rs1 del host)

    // Interfaz con DCache
    output wire [31:0] o_mem_addr,       // direccion de acceso a memoria
    output wire        o_mem_read_en,    // habilita lectura combinacional de DCache
    input  wire [31:0] i_mem_rdata,      // dato leido desde DCache

    // Interfaz con banco de registros vectoriales
    output wire        o_vrf_we,         // write enable al registro vectorial
    output wire [4:0]  o_vrf_addr,       // indice del registro vectorial destino
    output wire [127:0] o_vrf_data,      // dato de 128 bits a escribir

    // Interfaz con scoreboard (en ve_top)
    output wire        o_busy,           // LSU ocupado, no aceptar nueva instruccion
    output wire        o_scoreboard_set, // pulso: marcar vd como ocupado
    output wire        o_scoreboard_clr, // pulso: liberar vd al terminar
    output wire [4:0]  o_vd             // registro destino reclamado
);

    // -------------------------------------------------------------------------
    // Instancia del decodificador
    // -------------------------------------------------------------------------
    wire [4:0]  dec_vd;
    wire        dec_is_mask_load;
    wire        dec_valid_opcode;

    vlsu_decoder decoder (
        .i_instr          (i_instr),
        .o_vd             (dec_vd),
        .o_rs1            (),               // no usado hasta integrar host
        .o_width          (),
        .o_vm             (),
        .o_lumop          (),
        .o_mop            (),
        .o_nf             (),
        .o_is_unit_stride (),
        .o_is_whole_reg   (),
        .o_is_mask_load   (dec_is_mask_load),
        .o_valid_opcode   (dec_valid_opcode)
    );

    // -------------------------------------------------------------------------
    // Estados de la FSM
    // -------------------------------------------------------------------------
    localparam IDLE      = 3'd0;
    localparam ACCESS_0  = 3'd1;  // lee mem[base+0]  → asm_buf[31:0]
    localparam ACCESS_1  = 3'd2;  // lee mem[base+4]  → asm_buf[63:32]
    localparam ACCESS_2  = 3'd3;  // lee mem[base+8]  → asm_buf[95:64]
    localparam ACCESS_3  = 3'd4;  // lee mem[base+12] → asm_buf[127:96]
    localparam WRITEBACK = 3'd5;  // escribe asm_buf[127:0] al banco de registros vectoriales

    // -------------------------------------------------------------------------
    // Registros internos
    // -------------------------------------------------------------------------
    reg [2:0]   state;
    reg [4:0]   vd_reg;           // registro destino capturado al inicio de la operacion
    reg [31:0]  base_addr_reg;    // direccion base capturada al inicio de la operacion
    reg         is_mask_reg;      // indica si la instruccion es VLM (carga de mascara)
    reg [127:0] asm_buf;              // asm_buffer de ensamblaje: acumula los 4 accesos de 32 bits

    // -------------------------------------------------------------------------
    // Logica secuencial: transiciones de estado y captura de datos
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            state         <= IDLE;
            vd_reg        <= 5'b0;
            base_addr_reg <= 32'b0;
            is_mask_reg   <= 1'b0;
            asm_buf           <= 128'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (i_valid && dec_valid_opcode) begin
                        vd_reg        <= dec_vd;
                        base_addr_reg <= i_base_addr;
                        is_mask_reg   <= dec_is_mask_load;
                        state         <= ACCESS_0;
                    end
                end

                ACCESS_0: begin
                    asm_buf[31:0] <= i_mem_rdata;
                    // VLM solo necesita 1 acceso (ceil(vl/8) = 1 byte con vl=4 fijo)
                    state <= is_mask_reg ? WRITEBACK : ACCESS_1;
                end

                ACCESS_1: begin
                    asm_buf[63:32] <= i_mem_rdata;
                    state      <= ACCESS_2;
                end

                ACCESS_2: begin
                    asm_buf[95:64] <= i_mem_rdata;
                    state      <= ACCESS_3;
                end

                ACCESS_3: begin
                    asm_buf[127:96] <= i_mem_rdata;
                    state       <= WRITEBACK;
                end

                WRITEBACK: begin
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Logica combinacional: salidas hacia DCache
    // La lectura de DCache es combinacional, la direccion se presenta en el
    // mismo ciclo en que estamos en el estado ACCESS correspondiente
    // -------------------------------------------------------------------------
    assign o_mem_addr = (state == ACCESS_0) ? base_addr_reg          :
                        (state == ACCESS_1) ? base_addr_reg + 32'd4  :
                        (state == ACCESS_2) ? base_addr_reg + 32'd8  :
                        (state == ACCESS_3) ? base_addr_reg + 32'd12 :
                        32'b0;

    assign o_mem_read_en = (state == ACCESS_0) || (state == ACCESS_1) ||
                           (state == ACCESS_2) || (state == ACCESS_3);

    // -------------------------------------------------------------------------
    // Logica combinacional: salidas hacia banco de registros vectoriales
    // VLM escribe solo el byte bajo (mascara de 4 elementos) en v0
    // -------------------------------------------------------------------------
    assign o_vrf_we   = (state == WRITEBACK);
    assign o_vrf_addr = vd_reg;
    assign o_vrf_data = is_mask_reg ? {120'b0, asm_buf[7:0]} : asm_buf;

    // -------------------------------------------------------------------------
    // Logica combinacional: salidas hacia scoreboard en ve_top
    // -------------------------------------------------------------------------
    assign o_scoreboard_set = (state == IDLE) && i_valid && dec_valid_opcode;
    assign o_scoreboard_clr = (state == WRITEBACK);

    assign o_busy = (state != IDLE);
    assign o_vd   = vd_reg;

endmodule
