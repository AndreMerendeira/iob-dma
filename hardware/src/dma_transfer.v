`timescale 1ns / 1ps

`include "iob_lib.vh"
`include "axi.vh"

// DMA that implements byte alignment and multiple AXI burst transfers to support any transfer length
module dma_transfer #(
                 // AXI4 interface parameters
        parameter AXI_DATA_W = 32, // dma_transfer currently only supports 32 bit transfers
        parameter AXI_ADDR_W = 0,
        parameter LEN_W = 0
    )(
        // DMA configuration (must remain constant after asserting start)
        input [AXI_ADDR_W-1:0] addr,
        input [LEN_W-1:0] length,
        input readNotWrite, // 0 - write, 1 - read
        
        // Start transfer
        input start,

        // DMA status
        output wire ready,

        // Simple interface for data_in (valid_in assumed = 1, cannot pause transfer in progress)
        input [31:0] data_in,
        output ready_in,

        // Simple interface for data_out (ready_out assumed = 1, must be ready to accept new data every cycle)
        output [31:0] data_out,
        output valid_out,

        // DMA AXI connection
        `include "cpu_axi4_m_if.v"

        input clk,
        input rst
    );

    // State
    reg [AXI_ADDR_W-1:0] address;
    reg [`AXI_LEN_W-1:0] dma_len;
    reg [LEN_W-1:0] stored_len;
    reg [3:0] state;
    reg first_transfer;
    reg [AXI_DATA_W/8-1:0] wstrb;

    // Control
    reg [3:0] state_next;
    reg w_valid,r_valid;
    reg output_last;
    reg [AXI_DATA_W/8-1:0] wstrb_int;
    reg firstValid;
    reg incrementAddress;
    reg set_first_transfer,reset_first_transfer;

    // Auxiliary
    reg [LEN_W-1:0] last_transfer_len;
    reg [AXI_DATA_W/8-1:0] initial_strb,final_strb;

   // Auxiliary values
    wire [LEN_W-1:0] first_transfer_len = (32'd1020 + (32'd4 - address[1:0]));

    // Connect to modules
    wire dma_ready;
    wire n_ready;
    wire align_valid_out;
    wire split_ready_in;
    wire valid = w_valid | r_valid;
    wire [AXI_DATA_W-1:0] wdata;
    wire [AXI_DATA_W-1:0] rdata;

    // Output
    assign ready = (state == 8'h0);
    assign ready_in = (!readNotWrite & split_ready_in & (state == 8'h2 || state == 8'h4));
    assign valid_out = align_valid_out | output_last;

burst_align align( // Read
    .offset(addr[1:0]),
    .start(state == 8'h0),

    .last(output_last),

    .data_in(rdata),
    .valid_in(n_ready & readNotWrite),

    .data_out(data_out),
    .valid_out(align_valid_out),

    .clk(clk),
    .rst(rst)
    );

burst_split split( // Write
    .offset(addr[1:0]),
    .firstValid(firstValid),

    .data_in(data_in),
    .ready_in(split_ready_in),

    .data_out(wdata),
    .ready_out(m_axi_wvalid & m_axi_wready & !dma_ready),

    .clk(clk),
    .rst(rst)
    );

dma_axi #(
        .AXI_ADDR_W(AXI_ADDR_W)
    )
    dma
    (
    .valid(valid),
    .address({address[AXI_ADDR_W-1:2],2'b00}),
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

// Calculate inter transfer values
// All calculates done in bytes

reg [15:0] transfer_byte_size;
reg [15:0] boundary_transfer_len;
reg last_transfer;
reg [7:0] dma_transfer_size;

function [15:0] min(input [15:0] a,b);
    begin
        min = (a < b) ? a : b;
    end
endfunction

always @*
begin
    last_transfer_len = 0;
    boundary_transfer_len = 0;

    if(address[1:0] == 2'b00 & stored_len[1:0] == 2'b00)
        last_transfer_len = stored_len[9:2] - 8'h1;
    else if((address[1:0] == 2'b10 && stored_len[1:0] == 2'b11) ||
            (address[1:0] == 2'b11 && stored_len[1:0] >= 2'b10))
        last_transfer_len = stored_len[9:2] + 8'h1;
    else
        last_transfer_len = stored_len[9:2];

    boundary_transfer_len = 16'h1000 - address[11:0]; // Maximum bytes that can be transfer before crossing a border

    if(first_transfer)
        transfer_byte_size = min(boundary_transfer_len,min(stored_len,first_transfer_len));
    else
        transfer_byte_size = min(boundary_transfer_len,stored_len);

    last_transfer = (transfer_byte_size == stored_len);

    if(last_transfer)
        dma_transfer_size = last_transfer_len;
    else
        dma_transfer_size = (transfer_byte_size - 1) >> 2;

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

reg [10:0] counter;

// State 
always @(posedge clk,posedge rst)
begin
    if(rst) begin
        address <= 0;
        dma_len <= 0;
        stored_len <= 0;
        state <= 0;
        first_transfer <= 0;
        wstrb <= 0;
        counter <= 0;
    end else begin
        state <= state_next;
        wstrb <= wstrb_int;

        if(set_first_transfer)
            first_transfer <= 1'b1;

        if(reset_first_transfer)
            first_transfer <= 1'b0;

        if(m_axi_wready & m_axi_wvalid)
            counter <= counter - 1;

        if(incrementAddress) begin
            address <= address + transfer_byte_size;
            stored_len <= stored_len - transfer_byte_size;    
        end

        case(state)
        4'h0: begin
            if(start) begin
                address <= addr;
                stored_len <= length;
            end
        end
        4'h1: begin
            dma_len <= dma_transfer_size;
        end
        4'h2: begin
            counter <= dma_len;
        end
        default:;
        endcase
    end
end

// Control
always @*
begin
    state_next = state;
    wstrb_int = wstrb;
    r_valid = 0;
    output_last = 0;
    w_valid = 0;
    firstValid = 0;
    incrementAddress = 0;
    set_first_transfer = 0;
    reset_first_transfer = 0;

    case(state)
        4'h0: begin // Wait for start
            if(start) begin
                state_next = 4'h1;
                set_first_transfer = 1;
            end
        end
        4'h1: begin // Calculate auxiliary values and wait for dma
            if(dma_ready) begin
                state_next = 4'h2;
                if(readNotWrite)
                    wstrb_int = 0;
                else
                    wstrb_int = 4'hf; // Need to set wstrb to signal the DMA a write operation
            end
        end
        4'h2: begin // Program DMA
            if(readNotWrite) begin
                r_valid = 1'b1;
                if(m_axi_arready)
                    state_next = 4'h4;
            end else begin
                w_valid = 1'b1;

                if(m_axi_awready) begin
                    if(first_transfer)
                        firstValid = 1'b1;

                    // The correct first wstrb is set here
                    if(first_transfer)
                        wstrb_int = initial_strb;
                    else if(dma_len == 0)
                        wstrb_int = final_strb;
                    else 
                        wstrb_int = 4'hf;

                    state_next = 4'h4;
                end
            end
        end
        4'h4: begin // Wait for end of transfer
            if(readNotWrite) begin // Read
                if(m_axi_rvalid & m_axi_rready & m_axi_rlast)
                    state_next = 4'h8;
            end else begin // Write
                if(m_axi_wready & m_axi_wvalid) begin
                    if(counter == 1 & last_transfer)
                        wstrb_int = final_strb;
                    else
                        wstrb_int = 4'hf;
                end

                if(m_axi_wlast)
                    state_next = 4'h8;
            end
        end
        4'h8: begin
            if(readNotWrite) begin // Read
                if(last_transfer) begin
                    output_last = 1'b1; // Output the last bytes
                    state_next = 4'h0;
                end
                else
                    state_next = 4'h1;                        
            end else begin // Write
                if(!valid_out) begin
                    if(last_transfer) 
                        state_next = 4'h0;
                    else
                        state_next = 4'h1;
                end
            end

            if(state_next == 4'h1) begin
                incrementAddress = 1'b1;
                reset_first_transfer = 1'b1;
            end
        end
    endcase
end

endmodule

// Given the initial byte offset, this module aligns incoming data
// Start must be asserted once before the first valid data in a new burst transfer
module burst_align (
        input [1:0] offset,
        input start,

        input last,

        // Simple interface for data_in
        input [31:0] data_in,
        input valid_in,

        // Simple interface for data_out
        output reg [31:0] data_out,
        output reg valid_out,

        input clk,
        input rst
    );

reg valid;
reg [31:0] stored_data;

always @*
begin
    data_out = 0;
    valid_out = 1'b0;

    case(offset)
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
            case(offset)
            2'b00: stored_data <= data_in;
            2'b01: stored_data[23:0] <= data_in[31:8];
            2'b10: stored_data[15:0] <= data_in[31:16];
            2'b11: stored_data[7:0] <= data_in[31:24];
            endcase
        end
    end
end

endmodule // burst_align

// Given aligned data, splits the data in order to meet byte alignment in a burst transfer starting with offset byte
module burst_split (
        input [1:0] offset,
        input firstValid,

        // Simple interface for data_in
        input [31:0] data_in,
        output ready_in,

        // Simple interface for data_out
        output reg [31:0] data_out,
        input ready_out,

        input clk,
        input rst
    );

assign ready_in = firstValid | ready_out;

reg [23:0] stored_data;

always @(posedge clk,posedge rst)
begin
    if(rst) begin
        stored_data <= 0;
        data_out <= 0;
    end else begin
        if(firstValid | ready_out) begin
            case(offset)
            2'b00:;
            2'b01: stored_data[7:0] <= data_in[31:24];
            2'b10: stored_data[15:0] <= data_in[31:16];
            2'b11: stored_data <= data_in[31:8];
            endcase
            case(offset)
            2'b00: data_out <= data_in;
            2'b01: data_out <= {data_in[23:0],stored_data[7:0]};
            2'b10: data_out <= {data_in[15:0],stored_data[15:0]};
            2'b11: data_out <= {data_in[7:0],stored_data[23:0]};
            endcase
        end
    end
end

endmodule // burst_split
