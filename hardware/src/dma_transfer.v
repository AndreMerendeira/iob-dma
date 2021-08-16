`timescale 1ns / 1ps

`include "iob_lib.vh"
`include "axi.vh"

// Hardcoded for 32 bit transfers (in order to match SDRAM width)
// Different bit transfers require a change in strobe logic which is not currently implemented
`define AXI_DATA_W 32
`define DMA_DATA_W 32
`define WSTRB_W     4

// DMA that implements byte alignment and multiple AXI burst transfers
module dma_transfer #(
                 // AXI4 interface parameters
        parameter AXI_ADDR_W = `AXI_ADDR_W,
        parameter AXI_DATA_W = `AXI_DATA_W, // Do not change this value. Required by cpu_axi4_m_if.v, but dma_transfer logic not currently capable of handling different values
        parameter LEN_W = 32
    )(
        // DMA configuration 
        input [AXI_ADDR_W-1:0] addr,
        input [LEN_W-1:0] length,
        input readNotWrite, // 0 - write, 1 - read
        input start,

        // DMA status
        output wire ready,

        // Simple interface for data_in
        input [`DMA_DATA_W-1:0] data_in,
        input valid_in,
        output ready_in,

        // Simple interface for data_out
        output [`DMA_DATA_W-1:0] data_out,
        output valid_out,
        input ready_out,

        // DMA AXI connection
        `include "cpu_axi4_m_if.v"

        input clk,
        input rst
    );

    reg [LEN_W-1:0] stored_len;

    reg [AXI_ADDR_W-1:0] address;
    wire [`AXI_DATA_W-1:0] wdata;
    reg [`WSTRB_W-1:0] wstrb;
    wire [`AXI_DATA_W-1:0] rdata;

    reg [`AXI_LEN_W-1:0] dma_len;
    wire dma_ready;
    wire n_ready;

    wire align_valid_out;

    reg [LEN_W-1:0] last_transfer_len;
    reg [7:0] state,state_next;

    reg incrementAddress;

    reg output_last;
    assign valid_out = align_valid_out | output_last;

    reg [`WSTRB_W:0] initial_strb,final_strb;
    wire split_valid;

    assign ready_in = (split_ready_in & (state == 8'h2 || state == 8'h4)); 

    wire split_ready_in;

    reg w_valid,r_valid;

    wire valid = w_valid | r_valid;

    wire [1:0] offset = address[1:0];

    reg first_transfer;
    reg set_first_transfer,reset_first_transfer;

    wire [LEN_W-1:0] first_transfer_len = (32'd1020 + (32'd4 - address[1:0]));

    assign ready = (state == 8'h0);

    wire last_transfer = !((first_transfer && stored_len > first_transfer_len) || (!first_transfer && stored_len > 1024));

eth_burst_align #(.LEN_W(32)) align( // Read
    .offset(addr[1:0]),
    .start(state == 8'h0),

    .last(output_last),

    .data_in(rdata),
    .valid_in(n_ready & readNotWrite),
    .ready_in(), // Not used since the DMA module assumes always ready

    .data_out(data_out),
    .valid_out(align_valid_out),
    .ready_out(ready_out),

    .clk(clk),
    .rst(rst)
    );

eth_burst_split #(.LEN_W(32)) split( // Write
    .offset(addr[1:0]),

    .data_in(data_in),
    .valid_in(valid_in),
    .ready_in(split_ready_in),

    .data_out(wdata),
    .valid_out(split_valid),
    .ready_out(n_ready & !dma_ready),

    .clk(clk),
    .rst(rst)
    );

dma_axi #(
        .AXI_ADDR_W(AXI_ADDR_W)
    )
    dma
    (
    .valid(valid),
    .address(address),
    .wdata(wdata),
    .wstrb(wstrb),
    .rdata(rdata),
    .ready(n_ready),

    // DMA signals
    .dma_len(dma_len),
    .dma_ready(dma_ready),
    .error(),

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
    .m_axi_bid(m_axi_bid),
    .m_axi_bresp(m_axi_bresp), 
    .m_axi_bvalid(m_axi_bvalid), 
    .m_axi_bready(m_axi_bready),

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
    .m_axi_rid(m_axi_rid),
    .m_axi_rdata(m_axi_rdata),
    .m_axi_rresp(m_axi_rresp),
    .m_axi_rlast(m_axi_rlast),
    .m_axi_rvalid(m_axi_rvalid),
    .m_axi_rready(m_axi_rready),

    .clk(clk),
    .rst(rst)
    );

// Calculates auxiliary values
always @*
begin
    last_transfer_len = 0;

    if(offset[1:0] == 2'b00 & stored_len[1:0] == 2'b00)
        last_transfer_len = stored_len[9:2] - 8'h1;
    else if((offset[1:0] == 2'b10 && stored_len[1:0] == 2'b11) ||
            (offset[1:0] == 2'b11 && stored_len[1:0] >= 2'b10))
        last_transfer_len = stored_len[9:2] + 8'h1;
    else
        last_transfer_len = stored_len[9:2];

    case(address[1:0])
        2'b00: initial_strb = 4'b1111;
        2'b01: initial_strb = 4'b1110;
        2'b10: initial_strb = 4'b1100;
        2'b11: initial_strb = 4'b1000;
    endcase
    
    case(address[1:0])
        2'b00: case(stored_len[1:0])
            2'b00: final_strb = 4'b1111; 
            2'b01: final_strb = 4'b0001;
            2'b10: final_strb = 4'b0011;
            2'b11: final_strb = 4'b0111;
        endcase
        2'b01: case(stored_len[1:0])
            2'b00: final_strb = 4'b0001; 
            2'b01: final_strb = 4'b0011;
            2'b10: final_strb = 4'b0111;
            2'b11: final_strb = 4'b1111;
        endcase
        2'b10: case(stored_len[1:0])
            2'b00: final_strb = 4'b0011; 
            2'b01: final_strb = 4'b0111;
            2'b10: final_strb = 4'b1111;
            2'b11: final_strb = 4'b0001;
        endcase
        2'b11: case(stored_len[1:0])
            2'b00: final_strb = 4'b0111; 
            2'b01: final_strb = 4'b1111;
            2'b10: final_strb = 4'b0001;
            2'b11: final_strb = 4'b0011;
        endcase
    endcase
end

always @(posedge clk,posedge rst)
begin
    if(rst) begin
        address <= 0;
        dma_len <= 0;
        stored_len <= 0;
        state <= 0;
        first_transfer <= 0;
    end else begin
        state <= state_next;

        if(set_first_transfer)
            first_transfer <= 1'b1;

        if(reset_first_transfer)
            first_transfer <= 1'b0;

        // Start by sampling addr and length
        if(start && state == 8'h0)
        begin
            address <= addr;
            stored_len <= length;
        end

        if(incrementAddress) begin
            if(first_transfer) begin
                address <= address + first_transfer_len;
                stored_len <= stored_len - first_transfer_len;    
            end else begin
                address <= address + 1024;
                if(stored_len >= 1024)
                    stored_len <= stored_len - 1024;
                else
                    stored_len <= 0;
            end
        end

        if(state == 8'h1)
        begin
            if(stored_len > first_transfer_len) begin
                dma_len <= 8'hff;
            end else begin
                dma_len <= last_transfer_len;
            end
        end
    end
end

always @*
begin
    state_next = state;
    r_valid = 0;
    output_last = 0;
    w_valid = 0;
    wstrb = 0;
    incrementAddress = 0;
    set_first_transfer = 0;
    reset_first_transfer = 0;

    case(state)
        8'h0: begin // Wait for start
            if(start) begin
                state_next = 8'h1;
                set_first_transfer = 1;
            end
        end
        8'h1: begin // Calculate auxiliary values, wait for dma, start a transfer
            if(dma_ready)
                state_next = 8'h2;
        end
        8'h2: begin // Program DMA
            if(readNotWrite) begin
                r_valid = 1'b1;
                if(m_axi_rready & m_axi_rvalid)
                    state_next = 8'h4;
            end else begin
                if(dma_len == 0)
                    wstrb = final_strb;
                else if(first_transfer)
                    wstrb = initial_strb;
                else 
                    wstrb = 4'hf;

                w_valid = split_valid;
                
                if(m_axi_wready & m_axi_wvalid) begin
                    if(dma_len == 0)
                        state_next = 8'h0;
                    else
                        state_next = 8'h4;
                end
            end
        end
        8'h4: begin // Wait for end of transfer
            if(readNotWrite) begin // Read
                r_valid = 1'b1;

                if(m_axi_rlast)
                    state_next = 8'h8;
            end else begin // Write
                w_valid = split_valid;
                wstrb = 4'hf;

                if(m_axi_wlast)
                    state_next = 8'h8;

                if(m_axi_wlast & last_transfer)
                    wstrb = final_strb;
            end
        end
        8'h8: begin
            if(readNotWrite) begin // Read
                if(last_transfer) begin
                    output_last = 1'b1; // Output the last bytes
                    state_next = 8'h0;
                end
                else
                    state_next = 8'h1;                        
            end else begin // Write
                if(!valid_out)
                    if(last_transfer) 
                        state_next = 8'h0;
                    else
                        state_next = 8'h1;
            end

            if(state_next == 8'h1) begin
                incrementAddress = 1'b1;
                reset_first_transfer = 1'b1;
            end
        end
    endcase
end

endmodule

// Given the initial byte offset, this module aligns incoming data
// Start must be asserted once before the first valid data in a new burst transfer
// Last is asserted at the end to output the last remaining bytes
// Data_out is not registered - careful with time requirements
module eth_burst_align #(
        parameter ADDR_W = `AXI_ADDR_W,
        parameter DATA_W = 32,
        parameter LEN_W = 16
        )(
        input [1:0] offset,
        input start,

        input last,

        // Simple interface for data_in (transfer occurs when valid_in == ready_in == 1)
        input [31:0] data_in,
        input valid_in,
        output ready_in,

        // Simple interface for data_out (transfer occurs when valid_out == ready_out == 1)
        output reg [31:0] data_out,
        output reg valid_out,
        input ready_out,

        input clk,
        input rst
    );

assign ready_in = ready_out;

reg valid;
reg [31:0] stored_data;

always @*
begin
    data_out = 0;
    valid_out = 1'b0;

    case(offset[1:0])
    2'b00: data_out = stored_data; 
    2'b01: data_out = {data_in[7:0],stored_data[23:0]};
    2'b10: data_out = {data_in[15:0],stored_data[15:0]};
    2'b11: data_out = {data_in[23:0],stored_data[7:0]};
    endcase

    if(valid & valid_in) // A transfer occured
        valid_out = 1'b1;

    if(last)
        valid_out = 1'b1;
end

always @(posedge clk,posedge rst)
begin
    if(rst) begin
        stored_data <= 0;
        valid <= 0;
    end else begin
        if(start)
            valid <= 1'b0;

        if(valid_in)
            valid <= 1'b1;

        if(valid_in | last) begin
            case(offset[1:0])
            2'b00: stored_data <= data_in;
            2'b01: stored_data[23:0] <= data_in[31:8];
            2'b10: stored_data[15:0] <= data_in[31:16];
            2'b11: stored_data[7:0] <= data_in[31:24];
            endcase
        end
    end
end

endmodule // eth_burst_align

// Given aligned data, splits the data in order to meet byte alignment in a burst transfer starting with offset byte, 
// 
module eth_burst_split #(
        parameter ADDR_W = `AXI_ADDR_W,
        parameter DATA_W = 32,
        parameter LEN_W = 16
    ) 
    (
        input [1:0] offset,

        // Simple interface for data_in
        input [DATA_W-1:0] data_in,
        input valid_in,
        output ready_in,

        // Simple interface for data_out
        output reg [DATA_W-1:0] data_out,
        output wire valid_out,
        input ready_out,

        input clk,
        input rst
    );

assign ready_in = ready_out;
assign valid_out = valid_in;

reg [23:0] stored_data;

always @(posedge clk,posedge rst)
begin
    if(rst) begin
        stored_data <= 32'h0;
        data_out <= 0;
    end else begin
        if(valid_out & ready_out) begin
            case(offset[1:0])
            2'b00:;
            2'b01: stored_data[7:0] <= data_in[31:24];
            2'b10: stored_data[15:0] <= data_in[31:16];
            2'b11: stored_data <= data_in[31:8];
            endcase
            case(offset[1:0])
            2'b00: data_out <= data_in;
            2'b01: data_out <= {data_in[23:0],stored_data[7:0]};
            2'b10: data_out <= {data_in[15:0],stored_data[15:0]};
            2'b11: data_out <= {data_in[7:0],stored_data[23:0]};
            endcase
        end
    end
end

endmodule // eth_burst_split