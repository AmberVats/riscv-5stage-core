//=============================================================================
// Module: alu
// Description: Arithmetic Logic Unit & Branch Comparator for RV32I instructions.
//=============================================================================

`timescale 1ns / 1ps
import rv32_pkg::*;

module alu (
    input  logic [31:0]   op_a,
    input  logic [31:0]   op_b,
    input  alu_op_t       alu_op,
    input  branch_type_t  branch_type,
    output logic [31:0]   result,
    output logic          branch_taken
);

    logic [4:0] shamt;
    assign shamt = op_b[4:0];

    // ALU Core Arithmetic and Logic operations
    always_comb begin
        case (alu_op)
            ALU_ADD:  result = op_a + op_b;
            ALU_SUB:  result = op_a - op_b;
            ALU_SLL:  result = op_a << shamt;
            ALU_SLT:  result = ($signed(op_a) < $signed(op_b)) ? 32'd1 : 32'd0;
            ALU_SLTU: result = (op_a < op_b) ? 32'd1 : 32'd0;
            ALU_XOR:  result = op_a ^ op_b;
            ALU_SRL:  result = op_a >> shamt;
            ALU_SRA:  result = $signed(op_a) >>> shamt;
            ALU_OR:   result = op_a | op_b;
            ALU_AND:  result = op_a & op_b;
            ALU_PASS: result = op_b;
            default:  result = 32'd0;
        endcase
    end

    // Branch Condition Evaluation
    always_comb begin
        case (branch_type)
            BR_BEQ:  branch_taken = (op_a == op_b);
            BR_BNE:  branch_taken = (op_a != op_b);
            BR_BLT:  branch_taken = ($signed(op_a) < $signed(op_b));
            BR_BGE:  branch_taken = ($signed(op_a) >= $signed(op_b));
            BR_BLTU: branch_taken = (op_a < op_b);
            BR_BGEU: branch_taken = (op_a >= op_b);
            default: branch_taken = 1'b0;
        endcase
    end

endmodule
