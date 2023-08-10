`timescale 1ns/1ps

`include "iob_dma_conf.vh"
`include "iob_dma_swreg_def.vh"

module iob_dma # (
    `include "iob_dma_params.vs"
  ) (
    `include "iob_dma_io.vs"
  );

  //Dummy iob_ready_nxt_o and iob_rvalid_nxt_o to be used in swreg (unused ports)
  wire iob_ready_nxt_o;
  wire iob_rvalid_nxt_o;

  //BLOCK Register File & Configuration control and status register file.
  `include "iob_dma_swreg_inst.vs"

  wire [AXI_ADDR_W-1:0] internal_axi_awaddr_o;
  wire [AXI_ADDR_W-1:0] internal_axi_araddr_o;

  assign axi_awaddr_o = internal_axi_awaddr_o + MEM_ADDR_OFFSET;
  assign axi_araddr_o = internal_axi_araddr_o + MEM_ADDR_OFFSET;

  // External memory interfaces
  wire [         1-1:0] ext_mem_w_en;
  wire [AXI_DATA_W-1:0] ext_mem_w_data;
  wire [  BUFFER_W-1:0] ext_mem_w_addr;
  wire [         1-1:0] ext_mem_r_en;
  wire [  BUFFER_W-1:0] ext_mem_r_addr;
  wire [AXI_DATA_W-1:0] ext_mem_r_data;

  // AXIS In
  wire [AXI_DATA_W-1:0] axis_in_data;
  wire [         1-1:0] axis_in_valid;
  wire [         1-1:0] axis_in_ready;

  // AXIS Out
  wire [AXI_DATA_W-1:0] axis_out_data;
  wire [         1-1:0] axis_out_valid;
  wire [         1-1:0] axis_out_ready;

  // Mux between AXIS Inptus
  iob_mux #(
    .DATA_W(TDATA_W),
    .N(N_INPUTS),
  ) tdata_in_mux (
    .sel_i(INTERFACE_NUM),
    .data_i(tdata_i),
    .data_o(axis_in_data)
  );

  iob_mux #(
    .DATA_W(1),
    .N(N_INPUTS),
  ) tvalid_in_mux (
    .sel_i(INTERFACE_NUM),
    .data_i(tvalid_i),
    .data_o(axis_in_valid)
  );

  iob_demux #(
    .DATA_W(1),
    .N(N_INPUTS),
  ) tready_in_demux (
    .sel_i(INTERFACE_NUM),
    .data_i(axis_in_ready),
    .data_o(tready_o)
  );

  // Demux between AXIS Outputs
  iob_demux #(
    .DATA_W(TDATA_W),
    .N(N_OUTPUTS),
  ) tdata_out_demux (
    .sel_i(INTERFACE_NUM),
    .data_i(axis_out_data),
    .data_o(tdata_o)
  );

  iob_demux #(
    .DATA_W(1),
    .N(N_OUTPUTS),
  ) tvalid_out_demux (
    .sel_i(INTERFACE_NUM),
    .data_i(axis_out_valid),
    .data_o(tvalid_o)
  );

  iob_mux #(
    .DATA_W(1),
    .N(N_OUTPUTS),
  ) tready_out_mux (
    .sel_i(INTERFACE_NUM),
    .data_i(tready_i),
    .data_o(axis_out_ready)
  );

  axis2axi #(
    .AXI_ADDR_W(AXI_ADDR_W),
    .AXI_DATA_W(AXI_DATA_W),
    .AXI_LEN_W (AXI_LEN_W),
    .AXI_ID_W  (AXI_ID_W),
    .BURST_W   (BURST_W),
    .BUFFER_W  (BUFFER_W)
  ) axis2axi_inst (
    // Configuration (AXIS In)
    .config_in_addr_i (BASE_ADDR),
    .config_in_valid_i(DIRECTION==1 ? 1'b1 : 1'b0),
    .config_in_ready_o(READY_W),

    // Configuration (AXIS Out)
    .config_out_addr_i  (BASE_ADDR),
    .config_out_length_i(TRANSFER_SIZE_LOG2),
    .config_out_valid_i (DIRECTION==0 ? 1'b1 : 1'b0),
    .config_out_ready_o (READY_R),

    // AXIS In
    .axis_in_data_i (axis_in_data),
    .axis_in_valid_i(axis_in_valid),
    .axis_in_ready_o(axis_in_ready),
    
    // AXIS Out
    .axis_out_data_o (axis_out_data),
    .axis_out_valid_o(axis_out_valid),
    .axis_out_ready_i(axis_out_ready),

    // AXI master interface
    `include "axi_m_m_portmap.vs"

    // External memory interfaces
    .ext_mem_w_en_o  (ext_mem_w_en),
    .ext_mem_w_data_o(ext_mem_w_data),
    .ext_mem_w_addr_o(ext_mem_w_addr),
    .ext_mem_r_en_o  (ext_mem_r_en),
    .ext_mem_r_addr_o(ext_mem_r_addr),
    .ext_mem_r_data_i(ext_mem_r_data),

    // General signals interface
    .clk_i (clk_i),
    .cke_i (cke_i),
    .rst_i (1'b0),
    .arst_i(arst_i)
  );

  iob_ram_2p #(
    .DATA_W(AXI_DATA_W),
    .ADDR_W(BUFFER_W)
  ) axis2axi_memory (
    .clk_i   (clk_i),
    .w_en_i  (ext_mem_w_en),
    .w_data_i(ext_mem_w_data),
    .w_addr_i(ext_mem_w_addr),
    .r_en_i  (ext_mem_r_en),
    .r_data_o(ext_mem_r_data),
    .r_addr_i(ext_mem_r_addr)
  );

endmodule
