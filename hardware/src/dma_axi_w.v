`timescale 1ns / 1ps

`include "axi.vh"

// cLog2 number of states
`define W_STATES_W 2

// FSM States
`define W_ADDR_HS  `W_STATES_W'h0 //Write address handshake
`define W_DATA     `W_STATES_W'h1 //Write data
`define W_RESPONSE `W_STATES_W'h2 //Write response

module dma_axi_w #(
                   parameter ADDR_W = `AXI_ADDR_W,
                   parameter DMA_DATA_W = 32,
                   parameter USE_RAM = 1
                   )
   (
    // system inputs
    input                         clk,
    input                         rst,

    // Databus interface
    output                        ready,
    input                         valid,
    input [ADDR_W-1:0]            addr,
    input [DMA_DATA_W-1:0]        wdata,
    input [DMA_DATA_W/8-1:0]      wstrb,

    // DMA configuration
    input [`AXI_LEN_W-1:0]        dma_len,
    output reg                    dma_ready,
    output                        error,

    // Master Interface Write Address
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

    // Master Interface Write Data
    output [DMA_DATA_W-1:0]       m_axi_wdata,
    output reg [DMA_DATA_W/8-1:0] m_axi_wstrb,
    output reg                    m_axi_wlast,
    output reg                    m_axi_wvalid,
    input                         m_axi_wready,

    // Master Interface Write Response
    //input [`AXI_ID_W-1:0]         m_axi_bid,
    input [`AXI_RESP_W-1:0]       m_axi_bresp,
    input                         m_axi_bvalid,
    output reg                    m_axi_bready
    );

   // localparams
   localparam                     axi_awsize = $clog2(DMA_DATA_W/8);

   // counter, state and errorsregs
   reg [`AXI_LEN_W:0]             counter_int, counter_int_nxt;
   reg [`W_STATES_W-1:0]          state, state_nxt;
   reg                            error_int, error_nxt;

   // dma ready to receive run command
   reg                            dma_ready_nxt;

   // data write delay regs
   reg                            m_axi_wvalid_int;
   reg                            m_axi_wlast_int;
   reg                            ready_int, ready_r;
   assign ready = USE_RAM? ready_int: ready_r;

   // output error
   assign error = error_int;

   // Address write constants
   assign m_axi_awid = `AXI_ID_W'b0;
   assign m_axi_awaddr = addr;
   assign m_axi_awlen = dma_len; // number of trasfers per burst
   assign m_axi_awsize = axi_awsize; // INCR interval
   assign m_axi_awburst = `AXI_BURST_W'b01; // INCR
   assign m_axi_awlock = `AXI_LOCK_W'b0;
   assign m_axi_awcache = `AXI_CACHE_W'h2;
   assign m_axi_awprot = `AXI_PROT_W'b010;
   assign m_axi_awqos = `AXI_QOS_W'h0;

   // Data write constants
   assign m_axi_wdata = wdata;

   // delays
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         m_axi_wstrb <= {DMA_DATA_W/8{1'b0}};
      m_axi_wlast <= 0;
      m_axi_wvalid <= 0;
   end else begin
      m_axi_wstrb <= wstrb;
      m_axi_wlast <= m_axi_wlast_int;
      m_axi_wvalid <= m_axi_wvalid_int;
   end
   end

   // Counter, error, state and ready registers
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         state <= `W_ADDR_HS;
         counter_int <= `AXI_LEN_W'd0;
         error_int <= 1'b0;
         ready_r <= 1'b0;
         dma_ready <= 1'b1; 
      end else begin
         state <= state_nxt;
         counter_int <= counter_int_nxt;
         error_int <= error_nxt;
         ready_r <= ready_int;
         dma_ready <= dma_ready_nxt;
      end
   end

   // State machine
   always @* begin
      state_nxt = state;
      error_nxt = error_int;
      counter_int_nxt = counter_int;
      ready_int = 1'b0;
      dma_ready_nxt = 1'b0;
      m_axi_awvalid = 1'b0;
      m_axi_wvalid_int = 1'b0;
      m_axi_wlast_int = 1'b0;
      m_axi_bready = 1'b1;

      case (state)
        // addr handshake
        `W_ADDR_HS: begin
           counter_int_nxt = `AXI_LEN_W'd0;
           dma_ready_nxt = 1'b1;

           if (valid) begin
              if (m_axi_awready) begin
                 state_nxt = `W_DATA;
              end

              m_axi_awvalid = 1'b1;
              dma_ready_nxt = 1'b0;
           end
        end
        // data write
        `W_DATA: begin
           if (counter_int == dma_len) begin
              m_axi_wlast_int = 1'b1;
              state_nxt = `W_RESPONSE;
           end

           if (m_axi_wready) begin
              m_axi_wvalid_int = 1'b1;
              ready_int = 1'b1;
              counter_int_nxt = counter_int + 1'b1;
           end
        end
        // write response
        `W_RESPONSE: begin
           if (m_axi_bvalid) begin
              if (m_axi_bresp == `AXI_RESP_W'b00) begin
                 error_nxt = 1'b0;
              end else begin
                 error_nxt = 1'b1;
              end

              state_nxt = `W_ADDR_HS;
           end
        end
        default: state_nxt = `W_ADDR_HS;
      endcase
   end

endmodule
