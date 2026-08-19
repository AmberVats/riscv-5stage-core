//=============================================================================
// Module: mul_div
// Description: RV32M Hardware Multiplier and Divider Unit.
//              Implements MUL, MULH, MULHSU, MULHU, DIV, DIVU, REM, REMU
//              with complete RISC-V ISA compliant corner case handling.
//=============================================================================

`timescale 1ns / 1ps
import rv32_pkg::*;

module mul_div (
    input  logic [31:0] op_a,
    input  logic [31:0] op_b,
    input  mul_op_t     mul_op,
    output logic [31:0] result
);

    // Multiplications (64-bit signed/unsigned products)
    logic signed   [63:0] prod_ss;
    logic signed   [63:0] prod_su;
    logic unsigned [63:0] prod_uu;

    assign prod_ss = $signed(op_a) * $signed(op_b);
    assign prod_su = $signed(op_a) * $signed({1'b0, op_b});
    assign prod_uu = op_a * op_b;

    // Corner case checks for division
    logic div_by_zero;
    logic div_overflow;

    assign div_by_zero  = (op_b == 32'd0);
    assign div_overflow = (op_a == 32'h8000_0000) && (op_b == 32'hFFFF_FFFF);

    always_comb begin
        case (mul_op)
            M_MUL:    result = prod_ss[31:0];
            M_MULH:   result = prod_ss[63:32];
            M_MULHSU: result = prod_su[63:32];
            M_MULHU:  result = prod_uu[63:32];

            M_DIV: begin
                if (div_by_zero)       result = 32'hFFFF_FFFF; // RISC-V spec: -1 on div-by-zero
                else if (div_overflow) result = 32'h8000_0000; // Overflow: dividend unchanged
                else                   result = $signed(op_a) / $signed(op_b);
            end

            M_DIVU: begin
                if (div_by_zero) result = 32'hFFFF_FFFF;
                else             result = op_a / op_b;
            end

            M_REM: begin
                if (div_by_zero)       result = op_a;
                else if (div_overflow) result = 32'd0;
                else                   result = $signed(op_a) % $signed(op_b);
            end

            M_REMU: begin
                if (div_by_zero) result = op_a;
                else             result = op_a % op_b;
            end

            default: result = 32'd0;
        endcase
    end

endmodule
