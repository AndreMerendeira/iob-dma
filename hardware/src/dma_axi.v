`timescale 1ns / 1ps

`include "dma_axi.vh"

module dma_axi #(
		 parameter DMA_DATA_W = 32,
		 // AXI4 interface parameters
		 parameter ADDR_W = `AXI_ADDR_W,
		 parameter DATA_W = DMA_DATA_W

		 ) (

		    // system inputs
		    input 			 clk,
		    input 			 rst,

		    // AXI4 Master i/f
                    `include "cpu_axi4_m_if.v"

		    // Native i/f - can't include from INTERCON because address_w = 6
		    input 			 valid,
		    input [ADDR_W-1:0] 		 address,
		    input [DMA_DATA_W-1:0] 	 wdata,
		    input [DMA_DATA_W/8-1:0] wstrb,
		    output [DMA_DATA_W-1:0]  rdata,
		    output 			 ready,
		    
		    // DMA signals
		    input [`AXI_LEN_W-1:0] 	 dma_len,
		    output 			 dma_ready
						 
		    );

   // internal wires
   wire 				   ready_r, ready_w;
   wire 				   dma_ready_r, dma_ready_w;
   
   // assign outputs
   assign ready = (|wstrb) ? ready_w : ready_r;
   assign dma_ready = dma_ready_r && dma_ready_w;
   
   // AXI_DMA READ
   dma_axi_r 
     #(
       .DMA_DATA_W(DMA_DATA_W),
       .ADDR_W(ADDR_W)
       )dma_r (
	       .clk(clk),
	       .rst(rst),
	       
	       // Native interface
	       .valid    (valid && ~(|wstrb)),
	       .addr     (address),
	       .rdata    (rdata),
	       .ready    (ready_r),
	       // DMA configuration
	       .dma_len  (dma_len),
	       .dma_ready(dma_ready_r),
	       //address read
	       .m_axi_arid(m_axi_arid), 
	       .m_axi_araddr(m_axi_araddr), 
	       .m_axi_arlen(m_axi_arlen), 
	       .m_axi_arsize(m_axi_arsize), 
	       .m_axi_arburst(m_axi_arburst), 
	       .m_axi_arlock(m_axi_arlock), 
	       .m_axi_arcache(m_axi_arcache), 
	       .m_axi_arprot(m_axi_arprot), 
	       .m_axi_arqos(m_axi_arqos), 
	       .m_axi_arvalid(m_axi_arvalid), 
	       .m_axi_arready(m_axi_arready), 
	       //read 
	       // .m_axi_rid(m_axi_rid), 
	       .m_axi_rdata(m_axi_rdata), 
	       .m_axi_rresp(m_axi_rresp), 
	       .m_axi_rlast(m_axi_rlast), 
	       .m_axi_rvalid(m_axi_rvalid),  
	       .m_axi_rready(m_axi_rready)
	       );

   

   
   // AXI_DMA WRITE
   dma_axi_w 
     # (
	.USE_RAM(1),
	.DMA_DATA_W(DMA_DATA_W),
	.ADDR_W(ADDR_W)
	) dma_w (
		 .clk(clk),
		 .rst(rst),
		 // Native interface
		 .valid    (valid && (|wstrb)),
		 .addr     (address),
		 .wdata    (wdata),
		 .wstrb    (wstrb),
		 .ready    (ready_w),
		 // DMA configurations
		 .dma_len  (dma_len),
		 .dma_ready(dma_ready_w),
		 // Address write
		 .m_axi_awid(m_axi_awid), 
		 .m_axi_awaddr(m_axi_awaddr), 
		 .m_axi_awlen(m_axi_awlen), 
		 .m_axi_awsize(m_axi_awsize), 
		 .m_axi_awburst(m_axi_awburst), 
		 .m_axi_awlock(m_axi_awlock), 
		 .m_axi_awcache(m_axi_awcache), 
		 .m_axi_awprot(m_axi_awprot),
		 .m_axi_awqos(m_axi_awqos), 
		 .m_axi_awvalid(m_axi_awvalid), 
		 .m_axi_awready(m_axi_awready),
		 //write
		 .m_axi_wdata(m_axi_wdata), 
		 .m_axi_wstrb(m_axi_wstrb), 
		 .m_axi_wlast(m_axi_wlast), 
		 .m_axi_wvalid(m_axi_wvalid), 
		 .m_axi_wready(m_axi_wready), 
		 //write response
		 // .m_axi_bid(m_axi_bid), 
		 .m_axi_bresp(m_axi_bresp), 
		 .m_axi_bvalid(m_axi_bvalid), 
		 .m_axi_bready(m_axi_bready)
		 );
   
endmodule
