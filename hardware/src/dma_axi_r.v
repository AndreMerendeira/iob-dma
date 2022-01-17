`timescale 1ns / 1ps

`include "axi.vh"

module dma_axi_r #(
                   parameter ADDR_W = `AXI_ADDR_W,
                   parameter DMA_DATA_W = 32
                   )
   (
    input                     clk,
    input                     rst,

    //
    // DMA configuration
    //
    input [`AXI_LEN_W-1:0]    dma_len,
    output reg                dma_ready,
    output                    error,

    //
    // Native Slave I/F
    //
    output reg                ready,
    input                     valid,
    input [ADDR_W-1:0]        addr,
    output [DMA_DATA_W-1:0]   rdata,

    //
    // AXI-4 Full Master Read I/F
    //

    // Read Address
    output [`AXI_ID_W-1:0]    m_axi_arid,
    output [ADDR_W-1:0]       m_axi_araddr,
    output [`AXI_LEN_W-1:0]   m_axi_arlen,
    output [`AXI_SIZE_W-1:0]  m_axi_arsize,
    output [`AXI_BURST_W-1:0] m_axi_arburst,
    output [`AXI_LOCK_W-1:0]  m_axi_arlock,
    output [`AXI_CACHE_W-1:0] m_axi_arcache,
    output [`AXI_PROT_W-1:0]  m_axi_arprot,
    output [`AXI_QOS_W-1:0]   m_axi_arqos,
    output reg                m_axi_arvalid,
    input                     m_axi_arready,

    // Read Data
    input [`AXI_ID_W-1:0]     m_axi_rid,
    input [DMA_DATA_W-1:0]    m_axi_rdata,
    input [`AXI_RESP_W-1:0]   m_axi_rresp,
    input                     m_axi_rlast,
    input                     m_axi_rvalid,
    output reg                m_axi_rready
    );

   localparam                 axi_arsize = $clog2(DMA_DATA_W/8);

   localparam ADDR_HS=1'h0, READ=1'h1;

   // State signals
   reg                        state, state_nxt;

   // Counter and error signals
   reg [`AXI_LEN_W-1:0]       counter_int, counter_int_nxt;
   reg                        error_int, error_nxt;

   // DMA ready
   reg                        dma_ready_nxt;

   reg                        m_axi_arvalid_int;

   // DMA register signals
   reg [ADDR_W-1:0]           addr_reg;
   reg [`AXI_LEN_W-1:0]       len_reg;

   assign error = error_int;

   // Read address
   assign m_axi_arid = `AXI_ID_W'b0;
   assign m_axi_araddr = addr_reg;
   assign m_axi_arlen = len_reg;
   assign m_axi_arsize = axi_arsize;
   assign m_axi_arburst = `AXI_BURST_W'd1;
   assign m_axi_arlock = `AXI_LOCK_W'b0;
   assign m_axi_arcache = `AXI_CACHE_W'd2;
   assign m_axi_arprot = `AXI_PROT_W'd2;
   assign m_axi_arqos = `AXI_QOS_W'd0;

   // Read
   assign rdata = m_axi_rdata;

   // Counter, error and addr valid registers
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         counter_int <= `AXI_LEN_W'd0;
         error_int <= 1'b0;
         dma_ready <= 1'b1;
         m_axi_arvalid <= 1'b0;
      end else begin
         counter_int <= counter_int_nxt;
         error_int <= error_nxt;
         dma_ready <= dma_ready_nxt;
         m_axi_arvalid <= m_axi_arvalid_int;
      end
   end

   // DMA registers
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         addr_reg <= {ADDR_W{1'b0}};
         len_reg <= `AXI_LEN_W'd0;
      end else if (state == ADDR_HS) begin
         addr_reg <= addr;
         len_reg <= dma_len;
      end
   end

   wire                       rst_valid_int = (state_nxt == ADDR_HS)? 1'b1: 1'b0;
   reg                        arvalid_int;
   always @(posedge clk) begin
      if (rst_valid_int) begin
         arvalid_int <= 1'b1;
      end else if (m_axi_arready) begin
         arvalid_int <= 1'b0;
      end
   end

   //
   // FSM
   //

   // State register
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         state <= ADDR_HS;
      end else begin
         state <= state_nxt;
      end
   end

   // State machine
   always @* begin
      state_nxt = state;

      error_nxt = error_int;
      dma_ready_nxt = 1'b0;
      counter_int_nxt = counter_int;

      ready = 1'b0;

      m_axi_arvalid_int = 1'b0;
      m_axi_rready = 1'b0;

      case (state)
        // Read address handshake
        ADDR_HS: begin
           counter_int_nxt = `AXI_LEN_W'd0;
           dma_ready_nxt = 1'b1;

           if (valid) begin
              state_nxt = READ;

              m_axi_arvalid_int = 1'b1;
              dma_ready_nxt = 1'b0;
           end
        end
        // Read data
        READ: begin
           ready = m_axi_rvalid;

           m_axi_arvalid_int = arvalid_int;
           m_axi_rready = valid;

           if (m_axi_rvalid) begin
              if (counter_int == len_reg) begin
                 error_nxt = ~m_axi_rlast;

                 state_nxt = ADDR_HS;
              end

              if (valid) begin
                 counter_int_nxt = counter_int + 1'b1;
              end
           end
        end
      endcase
   end

endmodule
