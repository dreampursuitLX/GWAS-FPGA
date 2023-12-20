`timescale 1ns / 1ps
module IM_generator #(
    parameter DATA_WIDTH = 16,
    parameter FLOAT_WIDTH = 32
)(
    input clk,
    input rst,
    input [FLOAT_WIDTH-1:0] IM_in,
    input [FLOAT_WIDTH-1:0] tao_in,
    input [DATA_WIDTH-1:0] threshold_in,
    input [DATA_WIDTH-1:0] n_in,
    input valid_in,
    output wire result_out,
    output wire result_valid_out,
    output reg busy
    );
    wire [FLOAT_WIDTH-1:0] log_tao;
    wire log_tao_valid;
    wire [FLOAT_WIDTH-1:0] IM_sum;
    wire IM_sum_valid;
    wire [DATA_WIDTH-1:0] _2n;
    wire [FLOAT_WIDTH-1:0] float_2n;
    wire [FLOAT_WIDTH-1:0] float_threshold;
    wire float_valid;
    wire [FLOAT_WIDTH-1:0] IM_product;
    wire IM_product_valid;
	reg [FLOAT_WIDTH-1:0] reg_IM;
	reg [FLOAT_WIDTH-1:0] reg_tao;
	reg [DATA_WIDTH-1:0] reg_threshold;
	reg [DATA_WIDTH-1:0] reg_n;
	wire [7:0] clk_state;
    reg counter_start;
	reg counter_clear;
	assign result_valid_out = (clk_state == 31) ? 1 : 0;
	always@ (posedge clk) begin
		if (rst) begin
			counter_start <= 0;
			counter_clear <= 0;
		end
	    else if (valid_in) begin
		    reg_IM <= IM_in;
			reg_tao <= tao_in;
			reg_threshold <= threshold_in;
			reg_n <= n_in;
			counter_start <= 1;
		end
		else if (result_valid_out) begin
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
    floating_log tao_log (
		.clk (clk),
		.areset (rst),
        .a (reg_tao),
        .q (log_tao)
    );
    floating_add IM_add (
        .clk (clk),
		.areset (rst),
        .a (log_tao),
        .b (reg_IM),
        .q (IM_sum)
    );
    assign _2n = reg_n << 1;
    fixed2float _2n2float (
        .clk (clk),
		.areset (rst),
        .a ({16'h0000,_2n}),
        .q (float_2n)
    );
    floating_mul IM_mul (
        .clk (clk),
		.areset (rst),
        .a (IM_sum),
        .b (float_2n),
        .q (IM_product)
    );
    fixed2float threshold2float (
        .clk (clk),
		.areset (rst),
        .a ({16'h0000,reg_threshold}),
        .q (float_threshold)
    );
    floating_cmp threshold_cmp (
        .clk (clk),
		.areset (rst),
        .a (IM_product),
        .b (float_threshold),
        .q (result_out)
    );
    always@ (posedge clk) begin
        if (rst) begin
            busy <= 0;
        end
        else if (valid_in) begin
            busy <= 1;
        end
        else if (result_valid_out) begin
            busy <= 0;
        end
    end
endmodule
