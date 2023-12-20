`timescale 1ns / 1ps
module AdderTree #(
    parameter DATA_WIDTH = 32,
    parameter LENGTH = 18
)(
    input clk,
	input rst,
    input [DATA_WIDTH*LENGTH-1:0] in_addends,
    input valid_in,
    output wire [DATA_WIDTH-1:0] out_sum,
    output wire valid_out
    );
    genvar i,j,k;
    wire [DATA_WIDTH-1:0] first_a[0:8];
    wire [DATA_WIDTH-1:0] first_b[0:8];
    wire [DATA_WIDTH-1:0] first_sum[0:8];
	wire [DATA_WIDTH-1:0] second_a[0:3];
    wire [DATA_WIDTH-1:0] second_b[0:3];
    wire [DATA_WIDTH-1:0] second_sum[0:3];
	wire [DATA_WIDTH-1:0] third_a[0:1];
    wire [DATA_WIDTH-1:0] third_b[0:1];
    wire [DATA_WIDTH-1:0] third_sum[0:1];
	wire [DATA_WIDTH-1:0] fourth_a;
    wire [DATA_WIDTH-1:0] fourth_b;
    wire [DATA_WIDTH-1:0] fourth_sum;
	reg [DATA_WIDTH*LENGTH-1:0] reg_addends;
	wire [7:0] clk_state;
	reg counter_start;
	reg counter_clear;
	assign valid_out = (clk_state == 20) ? 1 : 0;
	always@ (posedge clk) begin
		if (rst) begin
			counter_start <= 0;
			counter_clear <= 0;
		end
	    else if (valid_in) begin
		    reg_addends <= in_addends;
			counter_start <= 1;
		end
		else if (valid_out) begin
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
    generate
    for (i = 0; i < 9; i = i+1) begin:first_add
        assign first_a[i] = reg_addends[2*i*DATA_WIDTH+:DATA_WIDTH];
        assign first_b[i] = reg_addends[(2*i+1)*DATA_WIDTH+:DATA_WIDTH];
        floating_add first_adder (
            .clk (clk),
			.areset (rst),
            .a (first_a[i]),
            .b (first_b[i]),
            .q (first_sum[i])
        );
    end
    endgenerate
    generate
    for (j = 0; j < 4; j = j+1) begin:second_add
        assign second_a[j] = first_sum[2*j];
        assign second_b[j] = first_sum[2*j+1];
        floating_add second_adder (
            .clk (clk),
			.areset (rst),
            .a (second_a[j]),
            .b (second_b[j]),
            .q (second_sum[j])
        );
    end
    endgenerate  
    for (k = 0; k < 2; k = k+1) begin:third_add
        assign third_a[k] = second_sum[2*k];
        assign third_b[k] = second_sum[2*k+1];
        floating_add third_adder (
            .clk (clk),
			.areset (rst),
            .a (third_a[k]),
            .b (third_b[k]),
            .q (third_sum[k])
        );
    end
    assign fourth_a = third_sum[0];
    assign fourth_b = third_sum[1];
    floating_add fourth_adder (
        .clk (clk),
		.areset (rst),
        .a (fourth_a),
        .b (fourth_b),
        .q (fourth_sum)
    );
    wire [DATA_WIDTH-1:0] last_sum;
	assign last_sum = first_sum[8];
    floating_add last_add (
        .clk (clk),
		.areset (rst),
        .a (last_sum),
        .b (fourth_sum),
        .q (out_sum)
    );
endmodule
