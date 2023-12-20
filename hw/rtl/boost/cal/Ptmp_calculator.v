`timescale 1ns / 1ps
module Ptmp_calculator #(
    parameter DATA_WIDTH = 16,
    parameter FLOAT_WIDTH = 32
)(
    input clk,
    input rst,
    input [FLOAT_WIDTH-1:0] Pab_in,
    input [FLOAT_WIDTH-1:0] Pbc_in,
    input [FLOAT_WIDTH-1:0] Pca_in,
    input [DATA_WIDTH-1:0] joint_table_in,
    input [DATA_WIDTH-1:0] n_in,
    input data_valid_in,
    output wire [FLOAT_WIDTH-1:0] IM_out,
    output wire [FLOAT_WIDTH-1:0] tao_out,
    output wire data_valid_out
    );
    reg [FLOAT_WIDTH-1:0] first_IM;
    reg [FLOAT_WIDTH-1:0] second_IM;
	reg [FLOAT_WIDTH-1:0] reg_Pab;
	reg [FLOAT_WIDTH-1:0] reg_Pbc;
	reg [FLOAT_WIDTH-1:0] reg_Pca;
	reg [DATA_WIDTH-1:0] reg_joint_table;
	reg [DATA_WIDTH-1:0] reg_n;
    wire first_valid;
    wire second_valid;
    wire first_en;
    wire second_en;
    wire [FLOAT_WIDTH-1:0] float_joint_table;
    wire [FLOAT_WIDTH-1:0] float_n;
    wire [FLOAT_WIDTH-1:0] ptmp1;
    wire [FLOAT_WIDTH-1:0] log_ptmp1;
    wire [FLOAT_WIDTH-1:0] mul_ptmp1;
	wire [FLOAT_WIDTH-1:0] mul_p;
	wire [FLOAT_WIDTH-1:0] ptmp2;
    wire [FLOAT_WIDTH-1:0] log_ptmp2;
    wire [FLOAT_WIDTH-1:0] mul_ptmp2;
    wire [7:0] clk_state;
	reg counter_start;
	reg counter_clear;
    assign data_valid_out = (clk_state == 62) ? 1 :0;
	assign tao_out = ptmp2;
	always@ (posedge clk) begin
		if (rst) begin
			counter_start <= 0;
			counter_clear <= 0;
		end
	    else if (data_valid_in) begin
		    reg_Pab <= Pab_in;
			reg_Pbc <= Pbc_in;
			reg_Pca <= Pca_in;
			reg_joint_table <= joint_table_in;
			reg_n <= n_in;
			counter_start <= 1;
		end
		else if (data_valid_out) begin
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
	fixed2float joint_table2float (
        .clk (clk),
		.areset (rst),
        .a ({16'h0000,reg_joint_table}),
        .q (float_joint_table)
    );
    fixed2float n2float (
        .clk (clk),
		.areset (rst),
        .a ({16'h0000,reg_n}),
        .q (float_n)
    );
    floating_div ptmp1_div(
        .clk (clk),
		.areset (rst),
        .a (float_joint_table),
        .b (float_n),
        .q (ptmp1)
    );
    floating_log ptmp1_log (
        .clk (clk),
		.areset (rst),
        .a (ptmp1),
        .q (log_ptmp1)
    );
    floating_mul ptmp1_mul (
        .clk (clk),
		.areset (rst),
        .a (ptmp1),
        .b (log_ptmp1),
        .q (mul_ptmp1)
    );	
    floating_mul p1_mul (
        .clk (clk),
		.areset (rst),
        .a (reg_Pab),
        .b (reg_Pbc),
        .q (mul_p)
    );
    floating_mul p2_mul (
        .clk (clk),
		.areset (rst),
        .a (mul_p),
        .b (reg_Pca),
        .q (ptmp2)
    );
    floating_log ptmp2_log (
        .clk (clk),
		.areset (rst),
        .a (ptmp2),
        .q (log_ptmp2)
    );
    floating_mul ptmp2_mul (
        .clk (clk),
		.areset (rst),
        .a (ptmp1),
        .b (log_ptmp2),
        .q (mul_ptmp2)
    );
    assign first_en = (reg_joint_table == 0) ? 0 : 1;
    assign second_en = ((reg_Pab == 0) || (reg_Pbc == 0) || (reg_Pca == 0)) ? 0 : 1;
    always @(posedge clk) begin
		if (first_en) begin
			first_IM <= mul_ptmp1;
		end
		else begin
			first_IM <= 32'h00000000;
		end
		if (second_en) begin
			second_IM <= mul_ptmp2;
		end
		else begin
			second_IM <= 32'h00000000;
		end
    end
    floating_sub IM_sub (
        .clk (clk),
		.areset (rst),
        .a (first_IM),
        .b (second_IM),
        .q (IM_out)
    );
endmodule