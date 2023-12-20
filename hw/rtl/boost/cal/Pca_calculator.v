`timescale 1ns / 1ps
module Pca_calculator #(
  parameter DATA_WIDTH = 16,
  parameter RESULT_WIDTH = 32
)(
  input clk,
  input rst,
  input [6*DATA_WIDTH-1:0] margin_table_in,
  input data_valid_in,
  output wire [6*RESULT_WIDTH-1:0] Pca_out,
  output wire data_valid_out
  );
  wire [5:0] result_valid;
  wire [RESULT_WIDTH-1:0] result_data[0:5];
  wire [DATA_WIDTH-1:0] divisor_data[0:5];
  wire [DATA_WIDTH-1:0] dividend_data[0:5];
  assign data_valid_out = (& result_valid) ? 1 : 0;
  genvar i,j;
  generate
  for (i = 0; i < 3; i = i+1) begin:first
      for (j = 0; j < 2; j = j+1) begin:second
          assign Pca_out[(2*i+j)*RESULT_WIDTH+:RESULT_WIDTH] = result_data[2*i+j];
          assign dividend_data[2*i+j] = margin_table_in[(i+3*j)*DATA_WIDTH+:DATA_WIDTH];
          assign divisor_data[2*i+j] = margin_table_in[i*DATA_WIDTH+:DATA_WIDTH] + margin_table_in[(i+3)*DATA_WIDTH+:DATA_WIDTH];
          Divider #(
              .DATA_WIDTH (DATA_WIDTH),
              .RESULT_WIDTH (RESULT_WIDTH)
          ) divider (
              .clk (clk),
              .rst (rst),
              .divisor_data (divisor_data[2*i+j]),
              .dividend_data (dividend_data[2*i+j]),
			  .data_valid_in (data_valid_in),
              .result_valid (result_valid[2*i+j]),
              .result_data (result_data[2*i+j])
          ); 
      end
  end
  endgenerate
endmodule