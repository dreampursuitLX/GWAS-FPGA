`timescale 1ns / 1ps
module FIFOWithCount #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH_WIDTH = 3
)(
    input clk,
    input rst,
    input wr_en,
    input rd_en,
    input [DATA_WIDTH-1:0] wr_data_in,
    output reg [DEPTH_WIDTH:0] count,
    output wire [DATA_WIDTH-1:0] rd_data_out,
    output wire full,
    output reg empty
    );
    reg [DEPTH_WIDTH:0] write_pointer;
    reg [DEPTH_WIDTH:0] read_pointer;
    wire empty_int;
    wire full_or_empty;
    wire full_wire;
    wire empty_wire;
    assign empty_int = (write_pointer[DEPTH_WIDTH] == read_pointer[DEPTH_WIDTH]); 
    assign full_or_empty = (write_pointer[DEPTH_WIDTH-1:0] == read_pointer[DEPTH_WIDTH-1:0]);
    assign full_wire = full_or_empty & !(empty_int);
    assign empty_wire = full_or_empty & (empty_int);
    assign full = full_wire;
    always @(posedge clk) begin
        if (rst) begin
            read_pointer <= 0;
            write_pointer <= 0;
            count <= 0;
        end 
        else begin
            if (wr_en && (full_wire == 1'b0)) begin
                write_pointer <= write_pointer + 1;
                count <= count + 1;
            end
            if (rd_en && (empty_wire == 1'b0)) begin
                read_pointer <= read_pointer + 1;
                count <= count - 1;
            end
            empty <= empty_wire;
        end
    end
    DP_BRAM #(
      .ADDR_WIDTH(DEPTH_WIDTH),
      .DATA_WIDTH(DATA_WIDTH)
    ) fifo_dp_bram (
      .clk(clk),
      .raddr(read_pointer[DEPTH_WIDTH-1:0]),
      .waddr(write_pointer[DEPTH_WIDTH-1:0]),
      .wr_en(wr_en),
      .data_out(rd_data_out),
      .data_in(wr_data_in)
    );
endmodule
