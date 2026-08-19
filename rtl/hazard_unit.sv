//=============================================================================
// Module: hazard_unit
// Description: Pipeline Hazard Detection and Stall/Flush Control Unit.
//              Handles:
//              1. Load-Use Data Hazards (1-cycle interlock stall)
//              2. Branch / Jump Misprediction Recovery (Pipeline Flushes)
//              3. Memory Subsystem AXI Stalls
//=============================================================================

`timescale 1ns / 1ps

module hazard_unit (
    // Inputs from Decode Stage (IF/ID)
    input  logic [4:0] if_id_rs1,
    input  logic [4:0] if_id_rs2,

    // Inputs from Execute Stage (ID/EX)
    input  logic [4:0] id_ex_rd,
    input  logic       id_ex_mem_read,

    // Control Hazard Inputs (from Execute Stage)
    input  logic       branch_mispredicted,

    // Memory Bus Stalls
    input  logic       imem_stall,
    input  logic       dmem_stall,

    // Stall and Flush Outputs
    output logic       stall_pc,
    output logic       stall_if_id,
    output logic       stall_id_ex,
    output logic       stall_ex_mem,
    output logic       stall_mem_wb,

    output logic       flush_if_id,
    output logic       flush_id_ex,
    output logic       flush_ex_mem
);

    logic load_use_hazard;

    // Load-Use Data Hazard Detection:
    // If instruction in EX is a LOAD and destination matches source of ID instruction
    always_comb begin
        load_use_hazard = id_ex_mem_read && (id_ex_rd != 5'd0) &&
                          ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2));
    end

    // Stall & Flush Control Generation
    always_comb begin
        // Defaults
        stall_pc     = 1'b0;
        stall_if_id  = 1'b0;
        stall_id_ex  = 1'b0;
        stall_ex_mem = 1'b0;
        stall_mem_wb = 1'b0;

        flush_if_id  = 1'b0;
        flush_id_ex  = 1'b0;
        flush_ex_mem = 1'b0;

        // 1. Memory Subsystem Stalls
        if (dmem_stall || imem_stall) begin
            stall_pc     = 1'b1;
            stall_if_id  = 1'b1;
            stall_id_ex  = 1'b1;
            stall_ex_mem = 1'b1;
            stall_mem_wb = 1'b1;
        end
        // 2. Control Hazard (Branch Misprediction in EX)
        else if (branch_mispredicted) begin
            flush_if_id = 1'b1;
            flush_id_ex = 1'b1;
        end
        // 3. Load-Use Data Hazard
        else if (load_use_hazard) begin
            stall_pc    = 1'b1;
            stall_if_id = 1'b1;
            flush_id_ex = 1'b1; // Inject NOP bubble into EX
        end
    end

endmodule
