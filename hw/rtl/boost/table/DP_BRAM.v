`timescale 1ns / 1ps
module DP_BRAM #( 
  parameter ADDR_WIDTH = 4,
  parameter DATA_WIDTH = 8
)(
  input clk,
  input [ADDR_WIDTH-1:0] raddr,
  input [ADDR_WIDTH-1:0] waddr,
  input wr_en,
  input [DATA_WIDTH-1:0] data_in,
  output reg [DATA_WIDTH-1:0] data_out);
  reg [DATA_WIDTH-1:0] mem [2**ADDR_WIDTH-1:0];
  integer i;
  always @(posedge clk) begin
      if (wr_en == 1)
          mem[waddr] <= data_in;
      data_out <= mem[raddr];
  end
endmodule