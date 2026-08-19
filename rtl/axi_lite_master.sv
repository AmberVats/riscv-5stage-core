//=============================================================================
// Module: axi_lite_master
// Description: AXI4-Lite Master Interface for RISC-V Memory Operations.
//              Provides synchronous read and write transaction handling.
//=============================================================================

`timescale 1ns / 1ps

module axi_lite_master #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
) (
    input  logic                  aclk,
    input  logic                  aresetn,

    // Core Memory Request Port
    input  logic                  req_valid,
    output logic                  req_ready,
    input  logic [ADDR_WIDTH-1:0] req_addr,
    input  logic [DATA_WIDTH-1:0] req_wdata,
    input  logic [3:0]            req_wstrb,
    input  logic                  req_write,
    output logic [DATA_WIDTH-1:0] resp_rdata,
    output logic                  resp_valid,

    // AXI4-Lite Write Address Channel
    output logic [ADDR_WIDTH-1:0] m_axi_awaddr,
    output logic [2:0]            m_axi_awprot,
    output logic                  m_axi_awvalid,
    input  logic                  m_axi_awready,

    // AXI4-Lite Write Data Channel
    output logic [DATA_WIDTH-1:0] m_axi_wdata,
    output logic [3:0]            m_axi_wstrb,
    output logic                  m_axi_wvalid,
    input  logic                  m_axi_wready,

    // AXI4-Lite Write Response Channel
    input  logic [1:0]            m_axi_bresp,
    input  logic                  m_axi_bvalid,
    output logic                  m_axi_bready,

    // AXI4-Lite Read Address Channel
    output logic [ADDR_WIDTH-1:0] m_axi_araddr,
    output logic [2:0]            m_axi_arprot,
    output logic                  m_axi_arvalid,
    input  logic                  m_axi_arready,

    // AXI4-Lite Read Data Channel
    input  logic [DATA_WIDTH-1:0] m_axi_rdata,
    input  logic [1:0]            m_axi_rresp,
    input  logic                  m_axi_rvalid,
    output logic                  m_axi_rready
);

    typedef enum logic [2:0] {
        IDLE        = 3'b000,
        SEND_AR     = 3'b001,
        RECV_R      = 3'b010,
        SEND_AW_W   = 3'b011,
        RECV_B      = 3'b100,
        DONE        = 3'b101
    } state_t;

    state_t state;

    logic [ADDR_WIDTH-1:0] latched_addr;
    logic [DATA_WIDTH-1:0] latched_wdata;
    logic [3:0]            latched_wstrb;
    logic [DATA_WIDTH-1:0] latched_rdata;
    logic                  aw_done, w_done;

    assign m_axi_awprot = 3'b000;
    assign m_axi_arprot = 3'b000;

    assign m_axi_araddr  = latched_addr;
    assign m_axi_arvalid = (state == SEND_AR);
    assign m_axi_rready  = (state == RECV_R);

    assign m_axi_awaddr  = latched_addr;
    assign m_axi_awvalid = (state == SEND_AW_W) && !aw_done;
    assign m_axi_wdata   = latched_wdata;
    assign m_axi_wstrb   = latched_wstrb;
    assign m_axi_wvalid  = (state == SEND_AW_W) && !w_done;
    assign m_axi_bready  = (state == RECV_B);

    assign req_ready     = (state == IDLE);
    assign resp_valid    = (state == DONE);
    assign resp_rdata    = latched_rdata;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            state         <= IDLE;
            latched_addr  <= '0;
            latched_wdata <= '0;
            latched_wstrb <= '0;
            latched_rdata <= '0;
            aw_done       <= 1'b0;
            w_done        <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    aw_done <= 1'b0;
                    w_done  <= 1'b0;
                    if (req_valid) begin
                        latched_addr  <= req_addr;
                        latched_wdata <= req_wdata;
                        latched_wstrb <= req_wstrb;
                        state         <= req_write ? SEND_AW_W : SEND_AR;
                    end
                end

                SEND_AR: begin
                    if (m_axi_arvalid && m_axi_arready) begin
                        state <= RECV_R;
                    end
                end

                RECV_R: begin
                    if (m_axi_rvalid && m_axi_rready) begin
                        latched_rdata <= m_axi_rdata;
                        state         <= DONE;
                    end
                end

                SEND_AW_W: begin
                    if (m_axi_awvalid && m_axi_awready) aw_done <= 1'b1;
                    if (m_axi_wvalid && m_axi_wready)   w_done  <= 1'b1;

                    if ((aw_done || (m_axi_awvalid && m_axi_awready)) &&
                        (w_done  || (m_axi_wvalid  && m_axi_wready))) begin
                        state <= RECV_B;
                    end
                end

                RECV_B: begin
                    if (m_axi_bvalid && m_axi_bready) begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
