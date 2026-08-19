//=============================================================================
// Package: rv32_pkg
// Description: Type definitions, opcodes, instruction formats, and pipeline
//              structures for the RV32IM 5-stage core.
//=============================================================================

`timescale 1ns / 1ps

package rv32_pkg;

    // Major Opcodes (Bits [6:0])
    localparam logic [6:0] OPC_OP       = 7'b0110011; // R-type: ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND, MUL, DIV
    localparam logic [6:0] OPC_OP_IMM   = 7'b0010011; // I-type: ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
    localparam logic [6:0] OPC_LUI      = 7'b0110111; // U-type: LUI
    localparam logic [6:0] OPC_AUIPC    = 7'b0010111; // U-type: AUIPC
    localparam logic [6:0] OPC_JAL      = 7'b1101111; // J-type: JAL
    localparam logic [6:0] OPC_JALR     = 7'b1100111; // I-type: JALR
    localparam logic [6:0] OPC_BRANCH   = 7'b1100011; // B-type: BEQ, BNE, BLT, BGE, BLTU, BGEU
    localparam logic [6:0] OPC_LOAD     = 7'b0000011; // I-type: LB, LH, LW, LBU, LHU
    localparam logic [6:0] OPC_STORE    = 7'b0100011; // S-type: SB, SH, SW
    localparam logic [6:0] OPC_SYSTEM   = 7'b1110011; // ECALL, EBREAK, CSRs

    // ALU Operation Control Codes
    typedef enum logic [3:0] {
        ALU_ADD  = 4'b0000,
        ALU_SUB  = 4'b0001,
        ALU_SLL  = 4'b0010,
        ALU_SLT  = 4'b0011,
        ALU_SLTU = 4'b0100,
        ALU_XOR  = 4'b0101,
        ALU_SRL  = 4'b0110,
        ALU_SRA  = 4'b0111,
        ALU_OR   = 4'b1000,
        ALU_AND  = 4'b1001,
        ALU_PASS = 4'b1010
    } alu_op_t;

    // RV32M Operation Control Codes
    typedef enum logic [2:0] {
        M_NONE   = 3'b000,
        M_MUL    = 3'b001,
        M_MULH   = 3'b010,
        M_MULHSU = 3'b011,
        M_MULHU  = 3'b100,
        M_DIV    = 3'b101,
        M_DIVU   = 3'b110,
        M_REM    = 3'b111
    } mul_op_t;

    // Branch Condition Types
    typedef enum logic [2:0] {
        BR_NONE = 3'b000,
        BR_BEQ  = 3'b001,
        BR_BNE  = 3'b010,
        BR_BLT  = 3'b011,
        BR_BGE  = 3'b100,
        BR_BLTU = 3'b101,
        BR_BGEU = 3'b110
    } branch_type_t;

    // Pipeline Register: IF / ID
    typedef struct packed {
        logic [31:0] pc;
        logic [31:0] instr;
        logic        pred_taken;
        logic [31:0] pred_target;
        logic        valid;
    } if_id_t;

    // Pipeline Register: ID / EX
    typedef struct packed {
        logic [31:0]        pc;
        logic [31:0]        rs1_data;
        logic [31:0]        rs2_data;
        logic [31:0]        imm;
        logic [4:0]         rs1_addr;
        logic [4:0]         rs2_addr;
        logic [4:0]         rd_addr;
        alu_op_t            alu_op;
        mul_op_t            mul_op;
        branch_type_t       branch_type;
        logic               alu_src_imm;
        logic               is_jump;
        logic               is_branch;
        logic               mem_read;
        logic               mem_write;
        logic [2:0]         mem_size; // funct3: byte, half, word, unsigned
        logic               reg_write;
        logic               pred_taken;
        logic [31:0]        pred_target;
        logic               valid;
    } id_ex_t;

    // Pipeline Register: EX / MEM
    typedef struct packed {
        logic [31:0] pc;
        logic [31:0] alu_result;
        logic [31:0] rs2_data; // Store data
        logic [4:0]  rd_addr;
        logic        mem_read;
        logic        mem_write;
        logic [2:0]  mem_size;
        logic        reg_write;
        logic        valid;
    } ex_mem_t;

    // Pipeline Register: MEM / WB
    typedef struct packed {
        logic [31:0] alu_result;
        logic [31:0] mem_rdata;
        logic [4:0]  rd_addr;
        logic        mem_to_reg;
        logic        reg_write;
        logic        valid;
    } mem_wb_t;

endpackage
