`timescale 1ns / 1ps
module P_calculator #(
    parameter DATA_WIDTH = 16,
    parameter P_WIDTH = 32
)(
    input clk,
    input rst,
    input [6*DATA_WIDTH-1:0] first_margin_table_data_in,
    input [6*DATA_WIDTH-1:0] second_margin_table_data_in,
    input [18*DATA_WIDTH-1:0] joint_table_data_in,
    input [2*DATA_WIDTH-1:0] n_data_in,
    input data_valid_in,
    output wire [9*P_WIDTH-1:0] Pab_out,
    output wire [6*P_WIDTH-1:0] Pbc_out,
    output wire [6*P_WIDTH-1:0] Pca_out,
    output wire data_valid_out,
    output reg busy
    );
    wire Pab_valid;
    wire Pbc_valid;
    wire Pca_valid;
    assign data_valid_out = Pab_valid & Pbc_valid & Pca_valid;
    Pab_calculator #(
        .DATA_WIDTH (DATA_WIDTH),
        .RESULT_WIDTH (P_WIDTH)
    ) Pab_cal (
        .clk (clk),
        .rst (rst),
        .joint_table_in (joint_table_data_in),
        .margin_table_in (second_margin_table_data_in),
        .data_valid_in (data_valid_in),
        .Pab_out (Pab_out),
        .data_valid_out (Pab_valid)
    );
    Pbc_calculator #(
        .DATA_WIDTH(DATA_WIDTH),
        .RESULT_WIDTH(P_WIDTH)
    ) Pbc_cal (
        .clk (clk),
        .rst (rst),
        .margin_table_in (second_margin_table_data_in),
        .n_in (n_data_in),
        .data_valid_in (data_valid_in),
        .Pbc_out (Pbc_out),
        .data_valid_out (Pbc_valid)
    );
    Pca_calculator #(
        .DATA_WIDTH(DATA_WIDTH),
        .RESULT_WIDTH(P_WIDTH)
    ) Pca_cal (
        .clk (clk),
        .rst (rst),
        .margin_table_in (first_margin_table_data_in),
        .data_valid_in (data_valid_in),
        .Pca_out (Pca_out),
        .data_valid_out (Pca_valid)
    );
    always@ (posedge clk) begin
        if (rst) begin
            busy <= 0;
        end
        else if (data_valid_in) begin
            busy <= 1;
        end
        else if (data_valid_out) begin
            busy <= 0;
        end
    end
endmodule
