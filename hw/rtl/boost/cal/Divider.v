`timescale 1ns / 1ps
module Divider #(
    parameter DATA_WIDTH = 16,
    parameter RESULT_WIDTH = 32
)(
    input clk,
    input rst,
    input [DATA_WIDTH-1:0] dividend_data,
    input [DATA_WIDTH-1:0] divisor_data,
    input data_valid_in,
    output [RESULT_WIDTH-1:0] result_data,
    output result_valid
    );
    wire [RESULT_WIDTH-1:0] float_dividend;
    wire [RESULT_WIDTH-1:0] float_divisor;
	reg [DATA_WIDTH-1:0] reg_dividend;
	reg [DATA_WIDTH-1:0] reg_divisor;
    wire [7:0] clk_state;
    reg counter_start;
	reg counter_clear;
	assign result_valid = (clk_state == 32) ? 1 :0;
	always@ (posedge clk) begin
		if (rst) begin
			counter_start <= 0;
			counter_clear <= 0;
		end
	    else if (data_valid_in) begin
		    reg_dividend <= dividend_data;
			reg_divisor <= divisor_data;
			counter_start <= 1;
		end
		else if (result_valid) begin
			counter_clear <= 1;
		end
		else begin
			counter_start <= 0;
			counter_clear <= 0;
		end
	end
	Counter clk_counter (
		.clk (clk),
		.rst (rst),
		.start (counter_start),
		.clear (counter_clear),
		.res (clk_state)
	);
    fixed2float dividend2float (
        .clk (clk),
		.areset (rst),
        .a ({16'h0000,reg_dividend}),
        .q (float_dividend)
    );
    fixed2float divisorfloat (
        .clk (clk),
		.areset (rst),
        .a ({16'h0000,reg_divisor}),
        .q (float_divisor)
    );
    floating_div result_div(
        .clk (clk),
		.areset (rst),
        .a (float_dividend),
        .b (float_divisor),
        .q (result_data)
    );
endmodule
