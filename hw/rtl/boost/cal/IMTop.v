`timescale 1ns / 1ps
module IMTop #(
    parameter DATA_WIDTH = 16
)(
    input clk,
    input rst,
    input [18*DATA_WIDTH-1:0] joint_table_in,
    input [6*DATA_WIDTH-1:0] first_margin_table_in,
    input [6*DATA_WIDTH-1:0] second_margin_table_in,
    input [2*DATA_WIDTH-1:0] n_in,
    input [DATA_WIDTH-1:0] threshold_in,
    input [2*DATA_WIDTH-1:0] snp_pair_in,
    input start,
    output wire ready,
    output wire empty,
    output wire [2*DATA_WIDTH-1:0] snp_pair_out,
    output wire result_out,
    output wire result_valid
    );
    localparam FLOAT_WIDTH = 32;
    wire busy_1;
    wire busy_2;
    wire busy_3;
    wire busy_4;
    wire valid_in_1;
    wire valid_in_2;
    wire valid_in_3;
    wire valid_in_4;
    wire valid_out_1;
    wire valid_out_2;
    wire valid_out_3;
    wire valid_out_4;
    reg pipe_mem_busy_1;
    reg pipe_mem_busy_2;
    reg pipe_mem_busy_3;
    reg pipe_mem_busy_4;
    wire mem_empty;
    wire cal_empty;
    assign mem_empty = ~pipe_mem_busy_1 & ~pipe_mem_busy_2 & ~pipe_mem_busy_3 & ~pipe_mem_busy_4;
    assign cal_empty = ~busy_1 & ~busy_2 & ~busy_3 & ~busy_4;
    assign ready = ~busy_1 & ~pipe_mem_busy_1;
    assign empty = mem_empty & cal_empty;
    assign result_valid = valid_out_4;
    assign valid_in_1 = ~busy_1 & pipe_mem_busy_1 & ~pipe_mem_busy_2;
    assign valid_in_2 = ~busy_2 & pipe_mem_busy_2 & ~pipe_mem_busy_3;
    assign valid_in_3 = ~busy_3 & pipe_mem_busy_3 & ~pipe_mem_busy_4;
    assign valid_in_4 = ~busy_4 & pipe_mem_busy_4;
    wire [9*FLOAT_WIDTH-1:0] Pab;
    wire [6*FLOAT_WIDTH-1:0] Pbc;
    wire [6*FLOAT_WIDTH-1:0] Pca;
    reg [6*DATA_WIDTH-1:0] reg_first_margin_table_1;
    reg [6*DATA_WIDTH-1:0] reg_second_margin_table_1;
    reg [18*DATA_WIDTH-1:0] reg_joint_table_1;
    reg [DATA_WIDTH-1:0] reg_threshold_1;
    reg [2*DATA_WIDTH-1:0] reg_n_1;
    reg [2*DATA_WIDTH-1:0] reg_snp_pair_1;
    always@ (posedge clk) begin
        if (rst) begin
            pipe_mem_busy_1 <= 0;
        end
        else if (start) begin
            reg_first_margin_table_1 <= first_margin_table_in;
            reg_second_margin_table_1 <= second_margin_table_in;
            reg_joint_table_1 <= joint_table_in;
            reg_threshold_1 <= threshold_in;
            reg_n_1 <= n_in;
            reg_snp_pair_1 <= snp_pair_in;
            pipe_mem_busy_1 <= 1;
        end 
        else if (valid_out_1) begin
            pipe_mem_busy_1 <= 0;
        end
    end
    P_calculator #(
        .DATA_WIDTH (DATA_WIDTH),
        .P_WIDTH (FLOAT_WIDTH)
    ) p_cal (
        .clk (clk),
        .rst (rst),
        .first_margin_table_data_in (reg_first_margin_table_1),
        .second_margin_table_data_in (reg_second_margin_table_1),
        .joint_table_data_in (reg_joint_table_1),
        .n_data_in (reg_n_1),
        .data_valid_in (valid_in_1),
        .Pab_out (Pab),
        .Pbc_out (Pbc),
        .Pca_out (Pca),
        .data_valid_out (valid_out_1),
        .busy (busy_1)
    );
    wire [18*FLOAT_WIDTH-1:0] IM;
    wire [18*FLOAT_WIDTH-1:0] tao;
    reg [9*FLOAT_WIDTH-1:0] reg_Pab_2;
    reg [6*FLOAT_WIDTH-1:0] reg_Pbc_2;
    reg [6*FLOAT_WIDTH-1:0] reg_Pca_2;
    reg [18*DATA_WIDTH-1:0] reg_joint_table_2;
    reg [DATA_WIDTH-1:0] reg_threshold_2;
    reg [DATA_WIDTH-1:0] reg_n_2;
    reg [2*DATA_WIDTH-1:0] reg_snp_pair_2;
    always@ (posedge clk) begin
        if (rst) begin
            pipe_mem_busy_2 <= 0;
        end
        else if (valid_out_1) begin
            reg_Pab_2 <= Pab;
            reg_Pbc_2 <= Pbc;
            reg_Pca_2 <= Pca;
            reg_joint_table_2 <= reg_joint_table_1;
            reg_threshold_2 <= reg_threshold_1;
            reg_n_2 <= reg_n_1[DATA_WIDTH-1:0] + reg_n_1[2*DATA_WIDTH-1:DATA_WIDTH];
            reg_snp_pair_2 <= reg_snp_pair_1;
            pipe_mem_busy_2 <= 1;
        end
        else if (valid_out_2) begin
            pipe_mem_busy_2 <= 0;
        end
    end
    IM_calculator #(
        .DATA_WIDTH (DATA_WIDTH),
        .FLOAT_WIDTH (FLOAT_WIDTH)
    ) IM_cal (
        .clk (clk),
        .rst (rst),
        .joint_table_in (reg_joint_table_2),
        .n_in (reg_n_2),
        .Pab_in (reg_Pab_2),
        .Pbc_in (reg_Pbc_2),
        .Pca_in (reg_Pca_2),
        .data_valid_in (valid_in_2),
        .IM_out (IM),
        .tao_out (tao),
        .data_valid_out (valid_out_2),   
        .busy (busy_2)  
    );
    reg [18*FLOAT_WIDTH-1:0] reg_IM_3;
    reg [18*FLOAT_WIDTH-1:0] reg_tao_3;
    reg [DATA_WIDTH-1:0] reg_threshold_3;
    reg [DATA_WIDTH-1:0] reg_n_3;
    reg [2*DATA_WIDTH-1:0] reg_snp_pair_3;
    wire [FLOAT_WIDTH-1:0] total_IM;
    wire [FLOAT_WIDTH-1:0] total_tao;
    always@ (posedge clk) begin
        if (rst) begin
            pipe_mem_busy_3 <= 0;
        end
        else if (valid_out_2) begin
            reg_IM_3 <= IM;
            reg_tao_3 <= tao;
            reg_threshold_3 <= reg_threshold_2;
            reg_n_3 <= reg_n_2;
            reg_snp_pair_3 <= reg_snp_pair_2;
            pipe_mem_busy_3 <= 1;
        end
        else if (valid_out_3) begin
            pipe_mem_busy_3 <= 0;
        end
    end
    IM_accumulator #(
        .DATA_WIDTH (FLOAT_WIDTH)
    ) IM_accu (
        .clk (clk),
        .rst (rst),
        .IM_in (reg_IM_3),
        .tao_in (reg_tao_3),
        .valid_in (valid_in_3),
        .IM_out (total_IM),
        .tao_out (total_tao),
        .valid_out (valid_out_3),
        .busy (busy_3)
    );
    reg [FLOAT_WIDTH-1:0] reg_IM_4;
    reg [FLOAT_WIDTH-1:0] reg_tao_4;
    reg [DATA_WIDTH-1:0] reg_threshold_4;
    reg [DATA_WIDTH-1:0] reg_n_4;
    reg [2*DATA_WIDTH-1:0] reg_snp_pair_4;
    assign snp_pair_out = reg_snp_pair_4;
    always@ (posedge clk) begin
        if (rst) begin
            pipe_mem_busy_4 <= 0;
        end
        else if (valid_out_3) begin
            reg_IM_4 <= total_IM;
            reg_tao_4 <= total_tao;
            reg_threshold_4 <= reg_threshold_3;
            reg_n_4 <= reg_n_3;
            reg_snp_pair_4 <= reg_snp_pair_3;
            pipe_mem_busy_4 <= 1;
        end
        else if (valid_out_4) begin
            pipe_mem_busy_4 <= 0;
        end
    end 
    IM_generator #(
        .DATA_WIDTH (DATA_WIDTH),
        .FLOAT_WIDTH (FLOAT_WIDTH)
    ) IM_gen (
        .clk (clk),
        .rst (rst),
        .IM_in (reg_IM_4),
        .tao_in (reg_tao_4),
        .threshold_in (reg_threshold_4),
        .n_in (reg_n_4),
        .valid_in (valid_in_4),
        .result_out (result_out),
        .result_valid_out (valid_out_4),
        .busy (busy_4)
    );
endmodule
