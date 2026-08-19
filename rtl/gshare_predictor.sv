//=============================================================================
// Module: gshare_predictor
// Description: Dynamic Gshare Branch Predictor with 2-bit Saturating Counters
//              and Branch Target Buffer (BTB).
//=============================================================================

`timescale 1ns / 1ps

module gshare_predictor #(
    parameter int GHR_BITS    = 6,
    parameter int TABLE_SIZE  = 1 << GHR_BITS, // 64 entries
    parameter int BTB_ENTRIES = 64
) (
    input  logic        clk,
    input  logic        rst_n,

    // Prediction Interface (Fetch Stage)
    input  logic [31:0] fetch_pc,
    output logic        pred_taken,
    output logic [31:0] pred_target,

    // Update Interface (Execute Stage)
    input  logic        update_en,
    input  logic [31:0] update_pc,
    input  logic        actual_taken,
    input  logic [31:0] actual_target
);

    // Global History Register (GHR)
    logic [GHR_BITS-1:0] ghr;

    // Pattern History Table (PHT): 2-bit saturating counters
    // 00: Strongly Not Taken, 01: Weakly Not Taken, 10: Weakly Taken, 11: Strongly Taken
    logic [1:0] pht [0:TABLE_SIZE-1];

    // Branch Target Buffer (BTB)
    logic [31:0] btb_target [0:BTB_ENTRIES-1];
    logic [31:0] btb_tag    [0:BTB_ENTRIES-1];
    logic        btb_valid  [0:BTB_ENTRIES-1];

    // Prediction Hash Calculation
    logic [GHR_BITS-1:0] pred_index;
    logic [GHR_BITS-1:0] update_index;
    logic [5:0]          btb_fetch_idx;
    logic [5:0]          btb_update_idx;

    assign pred_index     = fetch_pc[GHR_BITS+1:2] ^ ghr;
    assign update_index   = update_pc[GHR_BITS+1:2] ^ ghr;
    assign btb_fetch_idx  = fetch_pc[7:2];
    assign btb_update_idx = update_pc[7:2];

    // Prediction Generation
    always_comb begin
        if (btb_valid[btb_fetch_idx] && (btb_tag[btb_fetch_idx] == fetch_pc)) begin
            pred_taken  = pht[pred_index][1]; // MSB determines direction (1 = taken)
            pred_target = btb_target[btb_fetch_idx];
        end else begin
            pred_taken  = 1'b0;
            pred_target = fetch_pc + 32'd4;
        end
    end

    // Synchronous Update
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ghr <= '0;
            for (int i = 0; i < TABLE_SIZE; i++) begin
                pht[i] <= 2'b01; // Initialize to Weakly Not Taken
            end
            for (int i = 0; i < BTB_ENTRIES; i++) begin
                btb_valid[i]  <= 1'b0;
                btb_tag[i]    <= '0;
                btb_target[i] <= '0;
            end
        end else if (update_en) begin
            // 1. Shift actual outcome into GHR
            ghr <= {ghr[GHR_BITS-2:0], actual_taken};

            // 2. Update 2-bit Saturating Counter in PHT
            if (actual_taken) begin
                if (pht[update_index] != 2'b11) begin
                    pht[update_index] <= pht[update_index] + 1'b1;
                end
            end else begin
                if (pht[update_index] != 2'b00) begin
                    pht[update_index] <= pht[update_index] - 1'b1;
                end
            end

            // 3. Update BTB entry on taken branches
            if (actual_taken) begin
                btb_valid[btb_update_idx]  <= 1'b1;
                btb_tag[btb_update_idx]    <= update_pc;
                btb_target[btb_update_idx] <= actual_target;
            end
        end
    end

endmodule
