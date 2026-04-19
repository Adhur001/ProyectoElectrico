# Vector SM — Instruction Set Architecture (ISA) Definition
> Version 0.1 — Educational RISC-V based Vector SM

---

## Overview

This ISA is designed for an educational vector extension processor.
It extends a RISC-V 32-bit fixed-width instruction encoding with vector operations.
Each instruction operates on **N lanes** in parallel, where N is a hardware parameter (default 4).

Each lane operates on **32-bit** data elements.  
The vector register file holds **32 vector registers**, each **128-bit wide** (4 x 32-bit lanes).

---

## Instruction Format

All instructions are **32 bits wide** using the **R-type** encoding from RISC-V:

```
31      25 24    20 19    15 14  12 11     7 6      0
[ funct7 ] [ rs2  ] [ rs1  ] [funct3] [ rd  ] [opcode]
   7 bits    5 bits   5 bits   3 bits   5 bits   7 bits
```

| Field    | Bits     | Description                        |
|----------|----------|------------------------------------|
| `opcode` | [6:0]    | Identifies the instruction class   |
| `rd`     | [11:7]   | Destination vector register        |
| `funct3` | [14:12]  | Selects operation within the class |
| `rs1`    | [19:15]  | First source vector register       |
| `rs2`    | [24:20]  | Second source vector register      |
| `funct7` | [31:25]  | Reserved / future use (set to 0)   |

---

## Opcode

All vector ALU instructions share a single opcode:

| Opcode      | Binary      | Description          |
|-------------|-------------|----------------------|
| `VALU`      | `1010111`   | Vector ALU operation |

> This opcode is unused by the standard RISC-V ISA, avoiding conflicts.

---

## Operations (funct3 encoding)

| Mnemonic | funct3 | Operation                  | Description                        |
|----------|--------|----------------------------|------------------------------------|
| `VADD`   | `000`  | `rd = rs1 + rs2`           | Vector addition                    |
| `VSUB`   | `001`  | `rd = rs1 - rs2`           | Vector subtraction                 |
| `VAND`   | `010`  | `rd = rs1 & rs2`           | Bitwise AND                        |
| `VOR`    | `011`  | `rd = rs1 \| rs2`          | Bitwise OR                         |
| `VXOR`   | `100`  | `rd = rs1 ^ rs2`           | Bitwise XOR                        |

All operations execute **lane-by-lane in parallel**:

```
rd[lane_i] = rs1[lane_i] OP rs2[lane_i]   for i in 0..N-1
```

---

## Register File

| Property          | Value                        |
|-------------------|------------------------------|
| Number of registers | 32 (`v0` – `v31`)          |
| Register width    | 128 bits                     |
| Lane width        | 32 bits                      |
| Number of lanes   | 4 (parameterizable)          |
| Read ports        | 2 (rs1, rs2 simultaneously)  |
| Write ports       | 1 (rd)                       |

### Lane layout inside a 128-bit register

```
 127      96  95       64  63       32  31        0
[ lane 0  ] [  lane 1  ] [  lane 2  ] [  lane 3  ]
```

---

## Instruction Encoding Examples

### `VADD v3, v1, v2` — add v1 and v2, store in v3

```
funct7    rs2    rs1   funct3   rd     opcode
0000000  00010  00001   000   00011  1010111
```

Binary: `0000000_00010_00001_000_00011_1010111`  
Hex: `0x00208FB7`

### `VSUB v5, v2, v4` — subtract v4 from v2, store in v5

```
funct7    rs2    rs1   funct3   rd     opcode
0000000  00100  00010   001   00101  1010111
```

Hex: `0x004110B7` (approximate — assemble with tool for exact value)

### `VAND v1, v1, v2` — AND v1 and v2, store in v1

```
funct7    rs2    rs1   funct3   rd     opcode
0000000  00010  00001   010   00001  1010111
```

---

## ALU Control Signal Mapping

The decode stage produces a 3-bit `alu_op` signal from `funct3`:

| `funct3` | `alu_op` | Operation |
|----------|----------|-----------|
| `000`    | `000`    | ADD       |
| `001`    | `001`    | SUB       |
| `010`    | `010`    | AND       |
| `011`    | `011`    | OR        |
| `100`    | `100`    | XOR       |

> For this ISA version, `alu_op` maps 1:1 with `funct3`.  
> This will change when immediate and memory instructions are added.

---

## Pipeline Stages (Phase 2 target)

```
┌─────────┐    ┌─────────┐    ┌─────────────┐    ┌───────────┐
│  FETCH  │──▶│ DECODE  │──▶│   EXECUTE   │──▶│ WRITEBACK │
│         │    │         │    │  ALU_array  │    │ vregisters│
│ imem[PC]│    │ vdecode │    │ valu_control│    │           │
│ PC+4    │    │         │    │             │    │           │
└─────────┘    └─────────┘    └─────────────┘    └───────────┘
```

---

## Future Extensions (not yet implemented)

| Mnemonic  | funct3 | Description                        |
|-----------|--------|------------------------------------|
| `VSLL`    | `101`  | Vector shift left logical          |
| `VSRL`    | `110`  | Vector shift right logical         |
| `VCEQ`    | `111`  | Vector compare equal → predicate   |
| `VCLT`    | —      | Vector compare less-than           |
| `VLOAD`   | —      | Load vector from scratchpad        |
| `VSTORE`  | —      | Store vector to scratchpad         |

---

## Version History

| Version | Description                        |
|---------|------------------------------------|
| 0.1     | Initial — ADD, SUB, AND, OR, XOR   |
