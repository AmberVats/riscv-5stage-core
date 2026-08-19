//=============================================================================
// Module: regfile
// Description: 32x32-bit Dual-Read Single-Write RISC-V Register File.
//              Register x0 is hardwired to zero.
//              Includes write-to-read internal bypass for same-cycle WB-to-ID forwarding.
//=============================================================================

`timescale 1ns / 1ps

module regfile (
    input  logic        clk,
    input  logic        rst_n,

    // Read Port 1 (rs1)
    input  logic [4:0]  rs1_addr,
    output logic [31:0] rs1_data,

    // Read Port 2 (rs2)
    input  logic [4:0]  rs2_addr,
    output logic [31:0] rs2_data,

    // Write Port (rd from WB stage)
    input  logic        we,
    input  logic [4:0]  rd_addr,
    input  logic [31:0] rd_data
);

    logic [31:0] regs [0:31];

    // Read Port 1 with zero check and write-bypass
    always_comb begin
        if (rs1_addr == 5'd0) begin
            rs1_data = 32'd0;
        end else if (we && (rd_addr == rs1_addr)) begin
            rs1_data = rd_data; // Internal same-cycle forwarding
        end else begin
            rs1_data = regs[rs1_addr];
        end
    end

    // Read Port 2 with zero check and write-bypass
    always_comb begin
        if (rs2_addr == 5'd0) begin
            rs2_data = 32'd0;
        end else if (we && (rd_addr == rs2_addr)) begin
            rs2_data = rd_data;
        end else begin
            rs2_data = regs[rs2_addr];
        end
    end

    // Synchronous Write Port
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 32; i++) begin
                regs[i] <= 32'd0;
            end
        end else if (we && (rd_addr != 5'd0)) begin
            regs[rd_addr] <= rd_data;
        end
    end

endmodule
