`timescale 1ns / 1ps

`include "dma_axi.vh"

// Log2 number of states
`define R_STATES_W 1

// FSM States
`define R_ADDR_HS `R_STATES_W'h0 //Read address handshake
`define R_DATA    `R_STATES_W'h1 //Read data

module dma_axi_r #(
		   parameter DMA_DATA_WIDTH = 32,
		   parameter ADDR_W = `AXI_ADDR_W
		   ) (

		      // system inputs
		      input 			      clk,
		      input 			      rst,

    		      // Databus interface
    		      output reg 		      ready,
    		      input 			      valid,
    		      input [ADDR_W-1:0] 	      addr,
    		      output [DMA_DATA_WIDTH-1:0]     rdata,

		      // DMA configuration
		      input [`AXI_LEN_W-1:0] 	      dma_len,
		      output reg 		      dma_ready,
		      
		      // Master Interface Read Address
		      output wire [`AXI_ID_W-1:0]     m_axi_arid,
		      output wire [ADDR_W-1:0] 	      m_axi_araddr,
		      output wire [`AXI_LEN_W-1:0]    m_axi_arlen,
		      output wire [`AXI_SIZE_W-1:0]   m_axi_arsize,
		      output wire [`AXI_BURST_W-1:0]  m_axi_arburst,
		      output wire [`AXI_LOCK_W-1:0]   m_axi_arlock,
		      output wire [`AXI_CACHE_W-1:0]  m_axi_arcache,
		      output wire [`AXI_PROT_W-1:0]   m_axi_arprot,
		      output wire [`AXI_QOS_W-1:0]    m_axi_arqos,
		      output reg 		      m_axi_arvalid,
		      input wire 		      m_axi_arready,

		      // Master Interface Read Data
		      // input wire [`AXI_ID_W-1:0]     m_axi_rid,
		      input wire [DMA_DATA_WIDTH-1:0] m_axi_rdata,
		      input wire [`AXI_RESP_W-1:0]    m_axi_rresp,
		      input wire 		      m_axi_rlast,
		      input wire 		      m_axi_rvalid,
		      output reg 		      m_axi_rready
		      );
   
   // counter, state and error regs
   reg [`AXI_LEN_W-1:0] 			      counter_int, counter_int_nxt;
   reg [`R_STATES_W-1:0] 			      state, state_nxt;
   reg 						      error, error_nxt;

   // dma ready to receive run command
   reg 				       dma_ready_nxt;

   // register len and addr valid
   reg [`AXI_LEN_W-1:0]		       len_r;
   reg 				       m_axi_arvalid_int;

   // Address read constants
   assign m_axi_arid = `AXI_ID_W'b0;
   assign m_axi_araddr = addr;
   assign m_axi_arlen = len_r; //number of trasfers per burst
   assign m_axi_arsize = $clog2(DMA_DATA_WIDTH/8); //INCR interval
   assign m_axi_arburst = `AXI_BURST_W'b01; //INCR
   assign m_axi_arlock = `AXI_LOCK_W'b0;
   assign m_axi_arcache = `AXI_CACHE_W'h2;
   assign m_axi_arprot = `AXI_PROT_W'b010;
   assign m_axi_arqos = `AXI_QOS_W'h0;

   // Data read constant
   assign rdata = m_axi_rdata;

   // Counter, error, state and addr valid registers
   always @ (posedge clk, posedge rst)
     if (rst) begin
       state <= `R_ADDR_HS;
       counter_int <= {`AXI_LEN_W{1'b0}};
       error <= 1'b0;
       m_axi_arvalid <= 1'b0;
	dma_ready <= 1'b1;
     end else begin
       state <= state_nxt;
       counter_int <= counter_int_nxt;
       error <= error_nxt;
       m_axi_arvalid <= m_axi_arvalid_int;
	dma_ready <= dma_ready_nxt;
     end

   // register len
   always @ (posedge clk, posedge rst)
      if(rst)
         len_r <= {`AXI_LEN_W{1'b0}};
      else if(state == `R_ADDR_HS)
         len_r <= dma_len;
   
   // State machine
   always @ * begin
      state_nxt = state;
      error_nxt = error;
      counter_int_nxt = counter_int;
      ready = 1'b0;
      dma_ready_nxt = 1'b0;
      m_axi_arvalid_int = 1'b0;
      m_axi_rready = 1'b0;
      case (state)
	    //addr handshake
	    `R_ADDR_HS: begin
       	       counter_int_nxt <= {`AXI_LEN_W{1'b0}};
	       dma_ready_nxt = 1'b1;
	       if (valid) begin
	          if (m_axi_arready == 1'b1) begin
	             state_nxt = `R_DATA;
		  end
	          m_axi_arvalid_int = 1'b1;
		  dma_ready_nxt = 1'b0;
	       end
	    end
	    //data read
	    `R_DATA: begin
	       m_axi_rready = 1'b1;
	       if (m_axi_rvalid == 1'b1) begin
	          if (counter_int == len_r) begin
	             if (m_axi_rlast == 1'b1)
		        error_nxt = 1'b0;
	             else
		        error_nxt = 1'b1;
	             state_nxt = `R_ADDR_HS;
	          end
	          ready = 1'b1;
	          counter_int_nxt = counter_int + 1'b1;
	       end
	    end
      endcase
   end
   
endmodule
