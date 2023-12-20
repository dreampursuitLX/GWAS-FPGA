`timescale 1ns / 1ps
module Pab_calculator #(
  parameter DATA_WIDTH = 16,
  parameter RESULT_WIDTH = 32
)(
  input clk,
  input rst,
  input [18*DATA_WIDTH-1:0] joint_table_in,
  input [6*DATA_WIDTH-1:0] margin_table_in,
  input data_valid_in,
  output wire [9*RESULT_WIDTH-1:0] Pab_out,
  output wire data_valid_out
  );
  wire [8:0] result_valid;
  wire [RESULT_WIDTH-1:0] result_data[0:8];
  wire [DATA_WIDTH-1:0] divisor_data[0:8];
  wire [DATA_WIDTH-1:0] dividend_data[0:8];
  assign data_valid_out = (& result_valid) ? 1 : 0;
  genvar i,j;
  generate
  for (i = 0; i < 3; i = i+1) begin:first
      for (j = 0; j < 3; j = j+1) begin:second
          assign Pab_out[(3*i+j)*RESULT_WIDTH+:RESULT_WIDTH] = result_data[3*i+j];
          assign dividend_data[3*i+j] = joint_table_in[(3*j+i)*DATA_WIDTH+:DATA_WIDTH] + joint_table_in[(3*j+i+9)*DATA_WIDTH+:DATA_WIDTH];
          assign divisor_data[3*i+j] = margin_table_in[i*DATA_WIDTH+:DATA_WIDTH] + margin_table_in[(i+3)*DATA_WIDTH+:DATA_WIDTH];
          Divider #(
              .DATA_WIDTH (DATA_WIDTH),
              .RESULT_WIDTH (RESULT_WIDTH)
          ) divider (
              .clk (clk),
              .rst (rst),
              .divisor_data (divisor_data[3*i+j]),
              .dividend_data (dividend_data[3*i+j]),
			  .data_valid_in (data_valid_in),
              .result_valid (result_valid[3*i+j]),
              .result_data (result_data[3*i+j])
          ); 
      end
  end
  endgenerate
endmodule
