//=============================================================================
// Module: riscv_core_top
// Description: Top-Level 5-Stage Pipelined RV32IM Processor Core.
//              Integrates:
//              1. Fetch Stage with Dynamic Gshare Branch Predictor & BTB
//              2. Decode Stage with RV32IM Decoder & 32x32 Register File
//              3. Execute Stage with ALU, M-Ext Multiplier/Divider & Forwarding
//              4. Memory Stage with Load/Store Alignment & AXI4-Lite Data Master
//              5. Write-back Stage
//              6. Pipeline Hazard Detection Unit & Full RAW Forwarding Network
//=============================================================================

`timescale 1ns / 1ps
import rv32_pkg::*;

module riscv_core_top (
    input  logic        clk,
    input  logic        rst_n,

    // Instruction Memory Interface (AXI4-Lite Read Only)
    output logic [31:0] m_axi_imem_araddr,
    output logic        m_axi_imem_arvalid,
    input  logic        m_axi_imem_arready,
    input  logic [31:0] m_axi_imem_rdata,
    input  logic [1:0]  m_axi_imem_rresp,
    input  logic        m_axi_imem_rvalid,
    output logic        m_axi_imem_rready,

    // Data Memory Interface (AXI4-Lite Master)
    output logic [31:0] m_axi_dmem_awaddr,
    output logic [2:0]  m_axi_dmem_awprot,
    output logic        m_axi_dmem_awvalid,
    input  logic        m_axi_dmem_awready,
    output logic [31:0] m_axi_dmem_wdata,
    output logic [3:0]  m_axi_dmem_wstrb,
    output logic        m_axi_dmem_wvalid,
    input  logic        m_axi_dmem_wready,
    input  logic [1:0]  m_axi_dmem_bresp,
    input  logic        m_axi_dmem_bvalid,
    output logic        m_axi_dmem_bready,
    output logic [31:0] m_axi_dmem_araddr,
    output logic [2:0]  m_axi_dmem_arprot,
    output logic        m_axi_dmem_arvalid,
    input  logic        m_axi_dmem_arready,
    input  logic [31:0] m_axi_dmem_rdata,
    input  logic [1:0]  m_axi_dmem_rresp,
    input  logic        m_axi_dmem_rvalid,
    output logic        m_axi_dmem_rready
);

    // Hazard & Stall Controls
    logic stall_pc, stall_if_id, stall_id_ex, stall_ex_mem, stall_mem_wb;
    logic flush_if_id, flush_id_ex, flush_ex_mem;
    logic branch_mispredicted;
    logic imem_stall, dmem_stall;

    // Forwarding Controls
    logic [1:0] forward_a, forward_b;

    // Pipeline Registers
    if_id_t  reg_if_id;
    id_ex_t  reg_id_ex;
    ex_mem_t reg_ex_mem;
    mem_wb_t reg_mem_wb;

    //-------------------------------------------------------------------------
    // 1. FETCH STAGE (IF)
    //-------------------------------------------------------------------------
    logic [31:0] pc, next_pc;
    logic [31:0] pc_plus_4;
    logic        pred_taken;
    logic [31:0] pred_target;
    logic [31:0] resolved_target;
    logic [31:0] fetched_instr;

    assign pc_plus_4 = pc + 32'd4;

    // Next PC Selection:
    // 1. Recovery on Misprediction from EX stage
    // 2. Dynamic Gshare prediction
    // 3. Sequential PC+4
    always_comb begin
        if (branch_mispredicted) begin
            next_pc = resolved_target;
        end else if (pred_taken) begin
            next_pc = pred_target;
        end else begin
            next_pc = pc_plus_4;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 32'h0000_0000;
        end else if (!stall_pc) begin
            pc <= next_pc;
        end
    end

    // Instruction Memory AXI4-Lite Request
    assign m_axi_imem_araddr  = pc;
    assign m_axi_imem_arvalid = 1'b1;
    assign m_axi_imem_rready  = 1'b1;
    assign fetched_instr      = m_axi_imem_rdata;
    assign imem_stall         = !m_axi_imem_rvalid;

    // Gshare Dynamic Predictor
    logic update_predictor_en;
    logic actual_branch_taken;
    logic [31:0] actual_branch_target;

    gshare_predictor u_gshare (
        .clk           (clk),
        .rst_n         (rst_n),
        .fetch_pc      (pc),
        .pred_taken    (pred_taken),
        .pred_target   (pred_target),
        .update_en     (update_predictor_en),
        .update_pc     (reg_id_ex.pc),
        .actual_taken  (actual_branch_taken),
        .actual_target (actual_branch_target)
    );

    // IF/ID Pipeline Barrier Register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_if_id <= '0;
        end else if (flush_if_id) begin
            reg_if_id <= '0;
        end else if (!stall_if_id) begin
            reg_if_id.pc          <= pc;
            reg_if_id.instr       <= fetched_instr;
            reg_if_id.pred_taken  <= pred_taken;
            reg_if_id.pred_target <= pred_target;
            reg_if_id.valid       <= 1'b1;
        end
    end

    //-------------------------------------------------------------------------
    // 2. DECODE STAGE (ID)
    //-------------------------------------------------------------------------
    logic [31:0] id_instr;
    logic [6:0]  opcode;
    logic [2:0]  funct3;
    logic [6:0]  funct7;
    logic [4:0]  rs1_addr, rs2_addr, rd_addr;
    logic [31:0] rs1_rdata, rs2_rdata;
    logic [31:0] imm_i, imm_s, imm_b, imm_u, imm_j, selected_imm;

    assign id_instr = reg_if_id.instr;
    assign opcode   = id_instr[6:0];
    assign funct3   = id_instr[14:12];
    assign funct7   = id_instr[31:25];
    assign rs1_addr = id_instr[19:15];
    assign rs2_addr = id_instr[24:20];
    assign rd_addr  = id_instr[11:7];

    // Immediate Field Generators
    assign imm_i = {{20{id_instr[31]}}, id_instr[31:20]};
    assign imm_s = {{20{id_instr[31]}}, id_instr[31:25], id_instr[11:7]};
    assign imm_b = {{19{id_instr[31]}}, id_instr[31], id_instr[7], id_instr[30:25], id_instr[11:8], 1'b0};
    assign imm_u = {id_instr[31:12], 12'h000};
    assign imm_j = {{11{id_instr[31]}}, id_instr[31], id_instr[19:12], id_instr[20], id_instr[30:21], 1'b0};

    // Immediate Selector
    always_comb begin
        case (opcode)
            OPC_OP_IMM, OPC_LOAD, OPC_JALR: selected_imm = imm_i;
            OPC_STORE:                       selected_imm = imm_s;
            OPC_BRANCH:                      selected_imm = imm_b;
            OPC_LUI, OPC_AUIPC:              selected_imm = imm_u;
            OPC_JAL:                         selected_imm = imm_j;
            default:                         selected_imm = 32'd0;
        endcase
    end

    // Instruction Decoder Control Signals
    alu_op_t      id_alu_op;
    mul_op_t      id_mul_op;
    branch_type_t id_branch_type;
    logic         id_alu_src_imm;
    logic         id_is_jump;
    logic         id_is_branch;
    logic         id_mem_read;
    logic         id_mem_write;
    logic         id_reg_write;

    always_comb begin
        id_alu_op      = ALU_ADD;
        id_mul_op      = M_NONE;
        id_branch_type = BR_NONE;
        id_alu_src_imm = 1'b0;
        id_is_jump     = 1'b0;
        id_is_branch   = 1'b0;
        id_mem_read    = 1'b0;
        id_mem_write   = 1'b0;
        id_reg_write   = 1'b0;

        case (opcode)
            OPC_OP: begin
                id_reg_write = 1'b1;
                if (funct7 == 7'b0000001) begin
                    // RV32M Extension
                    case (funct3)
                        3'b000: id_mul_op = M_MUL;
                        3'b001: id_mul_op = M_MULH;
                        3'b010: id_mul_op = M_MULHSU;
                        3'b011: id_mul_op = M_MULHU;
                        3'b100: id_mul_op = M_DIV;
                        3'b101: id_mul_op = M_DIVU;
                        3'b110: id_mul_op = M_REM;
                        3'b111: id_mul_op = M_REMU;
                    endcase
                end else begin
                    // RV32I Base ALU
                    case (funct3)
                        3'b000: id_alu_op = (funct7[5]) ? ALU_SUB : ALU_ADD;
                        3'b001: id_alu_op = ALU_SLL;
                        3'b010: id_alu_op = ALU_SLT;
                        3'b011: id_alu_op = ALU_SLTU;
                        3'b100: id_alu_op = ALU_XOR;
                        3'b101: id_alu_op = (funct7[5]) ? ALU_SRA : ALU_SRL;
                        3'b110: id_alu_op = ALU_OR;
                        3'b111: id_alu_op = ALU_AND;
                    endcase
                end
            end

            OPC_OP_IMM: begin
                id_reg_write   = 1'b1;
                id_alu_src_imm = 1'b1;
                case (funct3)
                    3'b000: id_alu_op = ALU_ADD;
                    3'b001: id_alu_op = ALU_SLL;
                    3'b010: id_alu_op = ALU_SLT;
                    3'b011: id_alu_op = ALU_SLTU;
                    3'b100: id_alu_op = ALU_XOR;
                    3'b101: id_alu_op = (funct7[5]) ? ALU_SRA : ALU_SRL;
                    3'b110: id_alu_op = ALU_OR;
                    3'b111: id_alu_op = ALU_AND;
                endcase
            end

            OPC_LUI: begin
                id_reg_write   = 1'b1;
                id_alu_src_imm = 1'b1;
                id_alu_op      = ALU_PASS;
            end

            OPC_LOAD: begin
                id_reg_write   = 1'b1;
                id_mem_read    = 1'b1;
                id_alu_src_imm = 1'b1;
                id_alu_op      = ALU_ADD;
            end

            OPC_STORE: begin
                id_mem_write   = 1'b1;
                id_alu_src_imm = 1'b1;
                id_alu_op      = ALU_ADD;
            end

            OPC_BRANCH: begin
                id_is_branch = 1'b1;
                case (funct3)
                    3'b000: id_branch_type = BR_BEQ;
                    3'b001: id_branch_type = BR_BNE;
                    3'b100: id_branch_type = BR_BLT;
                    3'b101: id_branch_type = BR_BGE;
                    3'b110: id_branch_type = BR_BLTU;
                    3'b111: id_branch_type = BR_BGEU;
                endcase
            end

            OPC_JAL, OPC_JALR: begin
                id_is_jump   = 1'b1;
                id_reg_write = 1'b1;
            end

            default: ;
        endcase
    end

    // Register File Instance
    logic [31:0] wb_commit_data;

    regfile u_regfile (
        .clk      (clk),
        .rst_n    (rst_n),
        .rs1_addr (rs1_addr),
        .rs1_data (rs1_rdata),
        .rs2_addr (rs2_addr),
        .rs2_data (rs2_rdata),
        .we       (reg_mem_wb.reg_write && reg_mem_wb.valid),
        .rd_addr  (reg_mem_wb.rd_addr),
        .rd_data  (wb_commit_data)
    );

    // ID/EX Pipeline Barrier Register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_id_ex <= '0;
        end else if (flush_id_ex) begin
            reg_id_ex <= '0;
        end else if (!stall_id_ex) begin
            reg_id_ex.pc          <= reg_if_id.pc;
            reg_id_ex.rs1_data    <= rs1_rdata;
            reg_id_ex.rs2_data    <= rs2_rdata;
            reg_id_ex.imm         <= selected_imm;
            reg_id_ex.rs1_addr    <= rs1_addr;
            reg_id_ex.rs2_addr    <= rs2_addr;
            reg_id_ex.rd_addr     <= rd_addr;
            reg_id_ex.alu_op      <= id_alu_op;
            reg_id_ex.mul_op      <= id_mul_op;
            reg_id_ex.branch_type <= id_branch_type;
            reg_id_ex.alu_src_imm <= id_alu_src_imm;
            reg_id_ex.is_jump     <= id_is_jump;
            reg_id_ex.is_branch   <= id_is_branch;
            reg_id_ex.mem_read    <= id_mem_read;
            reg_id_ex.mem_write   <= id_mem_write;
            reg_id_ex.mem_size    <= funct3;
            reg_id_ex.reg_write   <= id_reg_write;
            reg_id_ex.pred_taken  <= reg_if_id.pred_taken;
            reg_id_ex.pred_target <= reg_if_id.pred_target;
            reg_id_ex.valid       <= reg_if_id.valid;
        end
    end

    //-------------------------------------------------------------------------
    // 3. EXECUTE STAGE (EX)
    //-------------------------------------------------------------------------
    logic [31:0] ex_op_a, ex_op_b;
    logic [31:0] ex_alu_b;
    logic [31:0] alu_raw_result;
    logic [31:0] mul_div_result;
    logic [31:0] ex_final_result;
    logic        ex_branch_cond_met;

    // RAW Forwarding Multiplexers
    always_comb begin
        case (forward_a)
            2'b10:   ex_op_a = reg_ex_mem.alu_result;
            2'b01:   ex_op_a = wb_commit_data;
            default: ex_op_a = reg_id_ex.rs1_data;
        endcase

        case (forward_b)
            2'b10:   ex_op_b = reg_ex_mem.alu_result;
            2'b01:   ex_op_b = wb_commit_data;
            default: ex_op_b = reg_id_ex.rs2_data;
        endcase
    end

    assign ex_alu_b = reg_id_ex.alu_src_imm ? reg_id_ex.imm : ex_op_b;

    // ALU
    alu u_alu (
        .op_a         (ex_op_a),
        .op_b         (ex_alu_b),
        .alu_op       (reg_id_ex.alu_op),
        .branch_type  (reg_id_ex.branch_type),
        .result       (alu_raw_result),
        .branch_taken (ex_branch_cond_met)
    );

    // RV32M Unit
    mul_div u_mul_div (
        .op_a   (ex_op_a),
        .op_b   (ex_op_b),
        .mul_op (reg_id_ex.mul_op),
        .result (mul_div_result)
    );

    // Result Multiplexer
    always_comb begin
        if (reg_id_ex.mul_op != M_NONE) begin
            ex_final_result = mul_div_result;
        end else if (reg_id_ex.is_jump) begin
            ex_final_result = reg_id_ex.pc + 32'd4; // Link address
        end else begin
            ex_final_result = alu_raw_result;
        end
    end

    // Branch & Jump Resolution Logic
    logic [31:0] branch_calc_target;
    assign branch_calc_target   = reg_id_ex.pc + reg_id_ex.imm;
    assign actual_branch_taken  = (reg_id_ex.is_branch && ex_branch_cond_met) || reg_id_ex.is_jump;
    assign actual_branch_target = reg_id_ex.is_jump && (reg_id_ex.alu_src_imm) ? (ex_op_a + reg_id_ex.imm) : branch_calc_target;
    assign update_predictor_en  = reg_id_ex.is_branch && reg_id_ex.valid;

    always_comb begin
        branch_mispredicted = 1'b0;
        resolved_target     = 32'd0;
        if (reg_id_ex.valid && (reg_id_ex.is_branch || reg_id_ex.is_jump)) begin
            if (actual_branch_taken != reg_id_ex.pred_taken || (actual_branch_taken && (actual_branch_target != reg_id_ex.pred_target))) begin
                branch_mispredicted = 1'b1;
                resolved_target     = actual_branch_taken ? actual_branch_target : (reg_id_ex.pc + 32'd4);
            end
        end
    end

    // EX/MEM Pipeline Barrier Register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_ex_mem <= '0;
        end else if (!stall_ex_mem) begin
            reg_ex_mem.pc         <= reg_id_ex.pc;
            reg_ex_mem.alu_result <= ex_final_result;
            reg_ex_mem.rs2_data   <= ex_op_b;
            reg_ex_mem.rd_addr    <= reg_id_ex.rd_addr;
            reg_ex_mem.mem_read   <= reg_id_ex.mem_read;
            reg_ex_mem.mem_write  <= reg_id_ex.mem_write;
            reg_ex_mem.mem_size   <= reg_id_ex.mem_size;
            reg_ex_mem.reg_write  <= reg_id_ex.reg_write;
            reg_ex_mem.valid      <= reg_id_ex.valid;
        end
    end

    //-------------------------------------------------------------------------
    // 4. MEMORY STAGE (MEM)
    //-------------------------------------------------------------------------
    logic [31:0] dmem_addr;
    logic [31:0] dmem_wdata;
    logic [3:0]  dmem_wstrb;
    logic [31:0] dmem_rdata_raw;
    logic [31:0] dmem_rdata_aligned;
    logic        dmem_req_valid;
    logic        dmem_resp_valid;

    assign dmem_addr      = reg_ex_mem.alu_result;
    assign dmem_req_valid = (reg_ex_mem.mem_read || reg_ex_mem.mem_write) && reg_ex_mem.valid;

    // Store Alignment & Byte Strobes (SB, SH, SW)
    always_comb begin
        dmem_wstrb = 4'b0000;
        dmem_wdata = reg_ex_mem.rs2_data;
        case (reg_ex_mem.mem_size[1:0])
            2'b00: begin // SB
                dmem_wstrb[dmem_addr[1:0]] = 1'b1;
                dmem_wdata = reg_ex_mem.rs2_data << (dmem_addr[1:0] * 8);
            end
            2'b01: begin // SH
                dmem_wstrb[dmem_addr[1]*2 +: 2] = 2'b11;
                dmem_wdata = reg_ex_mem.rs2_data << (dmem_addr[1] * 16);
            end
            2'b10: begin // SW
                dmem_wstrb = 4'b1111;
                dmem_wdata = reg_ex_mem.rs2_data;
            end
            default: ;
        endcase
    end

    // AXI4-Lite Master Data Bus
    axi_lite_master u_axi_dmem (
        .aclk          (clk),
        .aresetn       (rst_n),
        .req_valid     (dmem_req_valid),
        .req_ready     (),
        .req_addr      (dmem_addr),
        .req_wdata     (dmem_wdata),
        .req_wstrb     (dmem_wstrb),
        .req_write     (reg_ex_mem.mem_write),
        .resp_rdata    (dmem_rdata_raw),
        .resp_valid    (dmem_resp_valid),
        .m_axi_awaddr  (m_axi_dmem_awaddr),
        .m_axi_awprot  (m_axi_dmem_awprot),
        .m_axi_awvalid (m_axi_dmem_awvalid),
        .m_axi_awready (m_axi_dmem_awready),
        .m_axi_wdata   (m_axi_dmem_wdata),
        .m_axi_wstrb   (m_axi_dmem_wstrb),
        .m_axi_wvalid  (m_axi_dmem_wvalid),
        .m_axi_wready  (m_axi_dmem_wready),
        .m_axi_bresp   (m_axi_dmem_bresp),
        .m_axi_bvalid  (m_axi_dmem_bvalid),
        .m_axi_bready  (m_axi_dmem_bready),
        .m_axi_araddr  (m_axi_dmem_araddr),
        .m_axi_arprot  (m_axi_dmem_arprot),
        .m_axi_arvalid (m_axi_dmem_arvalid),
        .m_axi_arready (m_axi_dmem_arready),
        .m_axi_rdata   (m_axi_dmem_rdata),
        .m_axi_rresp   (m_axi_dmem_rresp),
        .m_axi_rvalid  (m_axi_dmem_rvalid),
        .m_axi_rready  (m_axi_dmem_rready)
    );

    assign dmem_stall = dmem_req_valid && !dmem_resp_valid;

    // Load Data Sign/Zero Extension Alignment (LB, LH, LW, LBU, LHU)
    logic [7:0]  loaded_byte;
    logic [15:0] loaded_half;

    assign loaded_byte = dmem_rdata_raw >> (dmem_addr[1:0] * 8);
    assign loaded_half = dmem_rdata_raw >> (dmem_addr[1] * 16);

    always_comb begin
        case (reg_ex_mem.mem_size)
            3'b000:  dmem_rdata_aligned = {{24{loaded_byte[7]}}, loaded_byte}; // LB
            3'b001:  dmem_rdata_aligned = {{16{loaded_half[15]}}, loaded_half}; // LH
            3'b010:  dmem_rdata_aligned = dmem_rdata_raw;                      // LW
            3'b100:  dmem_rdata_aligned = {24'h0, loaded_byte};                // LBU
            3'b101:  dmem_rdata_aligned = {16'h0, loaded_half};                // LHU
            default: dmem_rdata_aligned = dmem_rdata_raw;
        endcase
    end

    // MEM/WB Pipeline Barrier Register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_mem_wb <= '0;
        end else if (!stall_mem_wb) begin
            reg_mem_wb.alu_result <= reg_ex_mem.alu_result;
            reg_mem_wb.mem_rdata  <= dmem_rdata_aligned;
            reg_mem_wb.rd_addr    <= reg_ex_mem.rd_addr;
            reg_mem_wb.mem_to_reg <= reg_ex_mem.mem_read;
            reg_mem_wb.reg_write  <= reg_ex_mem.reg_write;
            reg_mem_wb.valid      <= reg_ex_mem.valid;
        end
    end

    //-------------------------------------------------------------------------
    // 5. WRITE-BACK STAGE (WB)
    //-------------------------------------------------------------------------
    assign wb_commit_data = reg_mem_wb.mem_to_reg ? reg_mem_wb.mem_rdata : reg_mem_wb.alu_result;

    //-------------------------------------------------------------------------
    // 6. HAZARD & FORWARDING UNITS
    //-------------------------------------------------------------------------
    hazard_unit u_hazard (
        .if_id_rs1           (rs1_addr),
        .if_id_rs2           (rs2_addr),
        .id_ex_rd            (reg_id_ex.rd_addr),
        .id_ex_mem_read      (reg_id_ex.mem_read),
        .branch_mispredicted (branch_mispredicted),
        .imem_stall          (imem_stall),
        .dmem_stall          (dmem_stall),
        .stall_pc            (stall_pc),
        .stall_if_id         (stall_if_id),
        .stall_id_ex         (stall_id_ex),
        .stall_ex_mem        (stall_ex_mem),
        .stall_mem_wb        (stall_mem_wb),
        .flush_if_id         (flush_if_id),
        .flush_id_ex         (flush_id_ex),
        .flush_ex_mem        (flush_ex_mem)
    );

    forwarding_unit u_fwd (
        .id_ex_rs1        (reg_id_ex.rs1_addr),
        .id_ex_rs2        (reg_id_ex.rs2_addr),
        .ex_mem_rd        (reg_ex_mem.rd_addr),
        .ex_mem_reg_write (reg_ex_mem.reg_write && reg_ex_mem.valid),
        .mem_wb_rd        (reg_mem_wb.rd_addr),
        .mem_wb_reg_write (reg_mem_wb.reg_write && reg_mem_wb.valid),
        .forward_a        (forward_a),
        .forward_b        (forward_b)
    );

endmodule
