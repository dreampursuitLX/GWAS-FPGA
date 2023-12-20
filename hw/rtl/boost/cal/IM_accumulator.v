`timescale 1ns / 1ps
module IM_accumulator #(
    parameter DATA_WIDTH = 32
)(
    input clk,
    input rst,
    input [18*DATA_WIDTH-1:0] IM_in,
    input [18*DATA_WIDTH-1:0] tao_in,
    input valid_in,
    output wire [DATA_WIDTH-1:0] IM_out,
    output wire [DATA_WIDTH-1:0] tao_out,
    output wire valid_out,
    output reg busy
    );
    wire IM_valid_out;
    wire tao_valid_out;
    assign valid_out = IM_valid_out & tao_valid_out;
    AdderTree #(
        .DATA_WIDTH (DATA_WIDTH),
        .LENGTH (18)
    ) IM_adder (
        .clk (clk),
        .in_addends (IM_in),
        .valid_in (valid_in),
        .out_sum (IM_out),
        .valid_out (IM_valid_out)
    );
    AdderTree #(
        .DATA_WIDTH (DATA_WIDTH),
        .LENGTH (18)
    ) tao_adder (
        .clk (clk),
        .in_addends (tao_in),
        .valid_in (valid_in),
        .out_sum (tao_out),
        .valid_out (tao_valid_out)
    );
    always@ (posedge clk) begin
        if (rst) begin
            busy <= 0;
        end
        else if (valid_in) begin
            busy <= 1;
        end
        else if (valid_out) begin
            busy <= 0;
        end
    end
endmodule
