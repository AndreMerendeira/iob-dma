`timescale 1ns / 1ps

`include "axi.vh"

module dma_axi_w #(
                   parameter ADDR_W = `AXI_ADDR_W,
                   parameter DMA_DATA_W = 32,
                   parameter USE_RAM = 1
                   )
   (
    input                         clk,
    input                         rst,

    //
    // DMA configuration
    //
    input [`AXI_LEN_W-1:0]        dma_len,
    output reg                    dma_ready,
    output                        error,

    //
    // Native Slave I/F
    //
    output                        ready,
    input                         valid,
    input [ADDR_W-1:0]            addr,
    input [DMA_DATA_W-1:0]        wdata,
    input [DMA_DATA_W/8-1:0]      wstrb,

    //
    // AXI-4 Full Master Write I/F
    //

    // Write Address
    output [`AXI_ID_W-1:0]        m_axi_awid,
    output [ADDR_W-1:0]           m_axi_awaddr,
    output [`AXI_LEN_W-1:0]       m_axi_awlen,
    output [`AXI_SIZE_W-1:0]      m_axi_awsize,
    output [`AXI_BURST_W-1:0]     m_axi_awburst,
    output [`AXI_LOCK_W-1:0]      m_axi_awlock,
    output [`AXI_CACHE_W-1:0]     m_axi_awcache,
    output [`AXI_PROT_W-1:0]      m_axi_awprot,
    output [`AXI_QOS_W-1:0]       m_axi_awqos,
    output reg                    m_axi_awvalid,
    input                         m_axi_awready,

    // Write Data
    output [`AXI_ID_W-1:0]        m_axi_wid,
    output [DMA_DATA_W-1:0]       m_axi_wdata,
    output reg [DMA_DATA_W/8-1:0] m_axi_wstrb,
    output reg                    m_axi_wlast,
    output reg                    m_axi_wvalid,
    input                         m_axi_wready,

    // Write Response
    input [`AXI_ID_W-1:0]         m_axi_bid,
    input [`AXI_RESP_W-1:0]       m_axi_bresp,
    input                         m_axi_bvalid,
    output reg                    m_axi_bready
    );

   localparam axi_awsize = $clog2(DMA_DATA_W/8);

   localparam ADDR_HS=2'h0, WRITE=2'h1, W_RESPONSE=2'h2;

   // State signals
   reg [1:0]                      state, state_nxt;

   // Counter and error signals
   reg [`AXI_LEN_W:0]             counter_int, counter_int_nxt;
   reg                            error_int, error_nxt;

   // DMA ready
   reg                            dma_ready_nxt;

   reg                            m_axi_awvalid_int;
   reg                            m_axi_wvalid_int;
   reg                            m_axi_wlast_int;

   // DMA register signals
   reg [ADDR_W-1:0]               addr_reg;
   reg [`AXI_LEN_W-1:0]           len_reg;

   // Delay signals
   reg                            ready_int, ready_reg;

   assign ready = USE_RAM? ready_int: ready_reg;
   assign error = error_int;

   // Write address
   assign m_axi_awid = `AXI_ID_W'd0;
   assign m_axi_awaddr = addr_reg;
   assign m_axi_awlen = len_reg;
   assign m_axi_awsize = axi_awsize;
   assign m_axi_awburst = `AXI_BURST_W'd1;
   assign m_axi_awlock = `AXI_LOCK_W'd0;
   assign m_axi_awcache = `AXI_CACHE_W'd2;
   assign m_axi_awprot = `AXI_PROT_W'd2;
   assign m_axi_awqos = `AXI_QOS_W'd0;

   // Write
   assign m_axi_wid = `AXI_ID_W'd0;
   assign m_axi_wdata = wdata;

   // Delays
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         m_axi_wstrb <= 0;
         m_axi_wlast <= 0;
         m_axi_wvalid <= 0;
      end else begin
         m_axi_wstrb <= wstrb;
         m_axi_wlast <= m_axi_wlast_int;
         m_axi_wvalid <= m_axi_wvalid_int;
      end
   end

   // Counter, error and ready registers
   always @(posedge clk) begin
      if (rst) begin
         counter_int <= `AXI_LEN_W'd0;
         error_int <= 1'b0;
         dma_ready <= 1'b1;
         ready_reg <= 1'b0;
         m_axi_awvalid <= 1'b0;
      end else begin
         counter_int <= counter_int_nxt;
         error_int <= error_nxt;
         dma_ready <= dma_ready_nxt;
         ready_reg <= ready_int;
         m_axi_awvalid <= m_axi_awvalid_int;
      end
   end

   // DMA registers
   always @(posedge clk) begin
      if (rst) begin
         addr_reg <= {ADDR_W{1'b0}};
         len_reg <= `AXI_LEN_W'd0;
      end else if (state == ADDR_HS) begin
         addr_reg <= addr;
         len_reg <= dma_len;
      end
   end

   wire                           rst_valid_int = (state_nxt == ADDR_HS)? 1'b1: 1'b0;
   reg                            awvalid_int;
   always @(posedge clk) begin
      if (rst_valid_int) begin
         awvalid_int <= 1'b1;
      end else if (m_axi_awready) begin
         awvalid_int <= 1'b0;
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

      ready_int = 1'b0;

      m_axi_awvalid_int = 1'b0;
      m_axi_wvalid_int = 1'b0;
      m_axi_wlast_int = 1'b0;
      m_axi_bready = 1'b1;

      case (state)
        // Write address handshake
        ADDR_HS: begin
           counter_int_nxt = `AXI_LEN_W'd0;
           dma_ready_nxt = 1'b1;

           if (valid) begin
              state_nxt = WRITE;

              m_axi_awvalid_int = 1'b1;
              dma_ready_nxt = 1'b0;
           end
        end
        // Write data
        WRITE: begin
           ready_int = m_axi_wready;

           m_axi_awvalid_int = awvalid_int;
           m_axi_wvalid_int = valid;

           if (m_axi_wready & valid) begin
              if (counter_int == len_reg) begin
                 m_axi_wlast_int = 1'b1;
                 state_nxt = W_RESPONSE;
              end

              counter_int_nxt = counter_int + 1'b1;
           end
        end
        // Write response
        W_RESPONSE: begin
           if (m_axi_bvalid) begin
              error_nxt = |m_axi_bresp;

              state_nxt = ADDR_HS;
           end
        end
        default: state_nxt = ADDR_HS;
      endcase
   end

endmodule
