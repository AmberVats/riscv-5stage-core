//=============================================================================
// Module: forwarding_unit
// Description: Full Bypass RAW Data Forwarding Unit.
//              Eliminates pipeline stalls by forwarding updated register values
//              from EX/MEM and MEM/WB stages directly into ALU inputs in EX stage.
//=============================================================================

`timescale 1ns / 1ps

module forwarding_unit (
    // Source Register Addresses from Execute Stage (ID/EX)
    input  logic [4:0] id_ex_rs1,
    input  logic [4:0] id_ex_rs2,

    // Destination Register & Write Enable from EX/MEM Stage
    input  logic [4:0] ex_mem_rd,
    input  logic       ex_mem_reg_write,

    // Destination Register & Write Enable from MEM/WB Stage
    input  logic [4:0] mem_wb_rd,
    input  logic       mem_wb_reg_write,

    // Forwarding Multiplexer Control Outputs:
    // 2'b00: Use register file value (no forwarding)
    // 2'b10: Forward from EX/MEM stage
    // 2'b01: Forward from MEM/WB stage
    output logic [1:0] forward_a,
    output logic [1:0] forward_b
);

    // Forwarding for Operand A (rs1)
    always_comb begin
        if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs1)) begin
            forward_a = 2'b10; // Forward from EX/MEM
        end else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs1)) begin
            forward_a = 2'b01; // Forward from MEM/WB
        end else begin
            forward_a = 2'b00; // No forwarding
        end
    end

    // Forwarding for Operand B (rs2)
    always_comb begin
        if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs2)) begin
            forward_b = 2'b10; // Forward from EX/MEM
        end else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs2)) begin
            forward_b = 2'b01; // Forward from MEM/WB
        end else begin
            forward_b = 2'b00; // No forwarding
        end
    end

endmodule
