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
    .N(N_INPUTS)
  ) tdata_in_mux (
    .sel_i(INTERFACE_NUM),
    .data_i(tdata_i),
    .data_o(axis_in_data)
  );

  iob_mux #(
    .DATA_W(1),
    .N(N_INPUTS)
  ) tvalid_in_mux (
    .sel_i(INTERFACE_NUM),
    .data_i(tvalid_i),
    .data_o(axis_in_valid)
  );

  iob_demux #(
    .DATA_W(1),
    .N(N_INPUTS)
  ) tready_in_demux (
    .sel_i(INTERFACE_NUM),
    .data_i(axis_in_ready && receive_incomplete), // Stop ready feedback if receive is complete
    .data_o(tready_o)
  );

  // Demux between AXIS Outputs
  iob_demux #(
    .DATA_W(TDATA_W),
    .N(N_OUTPUTS)
  ) tdata_out_demux (
    .sel_i(INTERFACE_NUM),
    .data_i(axis_out_data),
    .data_o(tdata_o)
  );

  iob_demux #(
    .DATA_W(1),
    .N(N_OUTPUTS)
  ) tvalid_out_demux (
    .sel_i(INTERFACE_NUM),
    .data_i(axis_out_valid),
    .data_o(tvalid_o)
  );

  iob_mux #(
    .DATA_W(1),
    .N(N_OUTPUTS)
  ) tready_out_mux (
    .sel_i(INTERFACE_NUM),
    .data_i(tready_i),
    .data_o(axis_out_ready)
  );

  wire BASE_ADDR_wen = (iob_avalid_i) & ((|iob_wstrb_i) & iob_addr_i==`IOB_DMA_BASE_ADDR_ADDR);
  wire TRANSFER_SIZE_LOG2_wen = (iob_avalid_i) & ((|iob_wstrb_i) & iob_addr_i==`IOB_DMA_TRANSFER_SIZE_LOG2_ADDR);
  
  // Create a 1 clock pulse when new value is written to BASE_ADDR
  reg base_addr_wen_delay_1;
  reg base_addr_wen_delay_2;
  always @(posedge clk_i, posedge arst_i) begin
    if (arst_i) begin
       base_addr_wen_delay_1 <= 0;
       base_addr_wen_delay_2 <= 0;
    end else begin
       base_addr_wen_delay_1 <= BASE_ADDR_wen;
       base_addr_wen_delay_2 <= base_addr_wen_delay_1;
    end
  end
  wire base_addr_wen_pulse = base_addr_wen_delay_1 && ~base_addr_wen_delay_2;

  // Create counter for words received via AXIS In
  wire [32-1:0] axis_in_cnt_o;
  wire receive_incomplete;
  iob_counter #(
    .DATA_W(32),
    .RST_VAL(0)
  ) axis_in_cnt (
    `include "clk_en_rst_s_s_portmap.vs"
    .rst_i(TRANSFER_SIZE_LOG2_wen), // Reset when new transfer size is written (will start new transfer)
    .en_i(axis_in_valid && axis_in_ready && receive_incomplete),
    .data_o(axis_in_cnt_o)
  );
  assign receive_incomplete = (DIRECTION==1 ? 1'b1 : 1'b0) && axis_in_cnt_o < TRANSFER_SIZE_LOG2;

  // Create a 1 clock pulse when new value is written to TRANSFER_SIZE_LOG2
  reg transfer_size_wen_delay_1;
  reg transfer_size_wen_delay_2;
  always @(posedge clk_i, posedge arst_i) begin
    if (arst_i) begin
       transfer_size_wen_delay_1 <= 0;
       transfer_size_wen_delay_2 <= 0;
    end else begin
       transfer_size_wen_delay_1 <= TRANSFER_SIZE_LOG2_wen;
       transfer_size_wen_delay_2 <= transfer_size_wen_delay_1;
    end
  end
  wire transfer_size_wen_pulse = transfer_size_wen_delay_1 && ~transfer_size_wen_delay_2;

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
    .config_in_valid_i(base_addr_wen_pulse),
    .config_in_ready_o(READY_W),

    // Configuration (AXIS Out)
    .config_out_addr_i  (BASE_ADDR),
    .config_out_length_i(TRANSFER_SIZE_LOG2), // Will start new transfer when a new size is set
    .config_out_valid_i (transfer_size_wen_pulse && (DIRECTION==0 ? 1'b1 : 1'b0)),
    .config_out_ready_o (READY_R),

    // AXIS In
    .axis_in_data_i (axis_in_data),
    .axis_in_valid_i(axis_in_valid & receive_incomplete), // Stop new valid values if receive is complete
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
