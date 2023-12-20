`timescale 1ns / 1ps
module BoostTop #(
    parameter DATA_WIDTH = 64,
    parameter BLOCK_WIDTH = 16,
    parameter BRAM_ADDR_WIDTH = 32,
    parameter PE_WIDTH = 16,
    parameter PE_NUM = 4
)(
    input clk,
    input rst,
    input [8*DATA_WIDTH-1:0] case_in,
    input [8*DATA_WIDTH-1:0] ctrl_in,
    input [BRAM_ADDR_WIDTH-1:0] case_wr_addr,
    input [BRAM_ADDR_WIDTH-1:0] ctrl_wr_addr,
    input case_wr_en,
    input ctrl_wr_en,
    input start,
    input clear_done,
    input [2*PE_WIDTH-1:0] n_in,
    input [PE_WIDTH-1:0] threshold_in,
    input [PE_WIDTH-1:0] snp_num_in,       
    input [BLOCK_WIDTH-1:0] case_length_in,
    input [BLOCK_WIDTH-1:0] ctrl_length_in, 
    //input [PE_WIDTH-1:0] snp_pair_addr,
    input wire snp_pair_rd_en,
    output wire [2*PE_WIDTH-1:0] snp_pair_out,
    output wire [PE_WIDTH-1:0] snp_pair_num,
    output wire table_done,
    output wire ready,
    output wire done
    );
    localparam FIFO_DEPTH_WIDTH = 16;
    localparam READY=0, GEN_TABLE_START=1, GEN_TABLE=2, READ_TABLE_START=3, READ_TABLE=4, CALCULATE_START=5, CALCULATE=6, DONE=7;
    reg [3:0] state;
    reg [3:0] next_state; 
    reg [2*PE_WIDTH-1:0] reg_n;
    reg [PE_WIDTH-1:0] reg_threshold;
    reg [PE_WIDTH-1:0] reg_snp_num;
    reg [BLOCK_WIDTH-1:0] reg_case_length;
    reg [BLOCK_WIDTH-1:0] reg_ctrl_length;
    reg [2*PE_WIDTH-1:0] reg_snp_pair;
    reg [18*PE_WIDTH-1:0] reg_joint_table;
    reg [6*PE_WIDTH-1:0] reg_first_margin_table;
    reg [6*PE_WIDTH-1:0] reg_second_margin_table;
    wire jd_start;
    wire jd_ready;
    wire jd_done;
    wire table_ready;
    reg table_rd_en;
    wire table_valid;
    wire [2*PE_WIDTH-1:0] snp_pair_data;
    wire [18*PE_WIDTH-1:0] joint_table_data;
    wire [6*PE_WIDTH-1:0] first_margin_table_data;
    wire [6*PE_WIDTH-1:0] second_margin_table_data;
    wire im_start;
    wire im_ready;
    wire im_empty;
    wire im_result;
    wire im_result_valid;
    wire [2*PE_WIDTH-1:0] snp_pair;
    reg fifo_wr_en;
    reg [2*PE_WIDTH-1:0] fifo_data_in;
    reg [PE_WIDTH-1:0] snp_pair_count;
    wire fifo_empty;
    wire fifo_full;
    assign ready = (state == READY);
    assign done = (state == DONE);
    assign snp_pair_num = snp_pair_count;
	 assign table_done = jd_done;
    assign jd_start = (state == GEN_TABLE_START);
    assign im_start = (state == CALCULATE_START);
    JDTop # (
        .DATA_WIDTH (DATA_WIDTH),
        .BLOCK_WIDTH (BLOCK_WIDTH),
        .PE_WIDTH (PE_WIDTH),
        .BRAM_ADDR_WIDTH (BRAM_ADDR_WIDTH),
        .PE_NUM (PE_NUM),
        .CASE_FILENAME (""),
        .CTRL_FILENAME ("")
    ) jdtop (
        .clk (clk),
        .rst (rst),
        .start (jd_start),
        .clear_done (clear_done),
        .ready (jd_ready),
        .done (jd_done),
        .table_ready (table_ready),
        .case_in (case_in),
        .ctrl_in (ctrl_in),
        .case_wr_addr (case_wr_addr),
        .ctrl_wr_addr (ctrl_wr_addr),
        .case_wr_en (case_wr_en),
        .ctrl_wr_en (ctrl_wr_en),
        .snp_num_in (reg_snp_num),
        .case_length_in (reg_case_length),
        .ctrl_length_in (reg_ctrl_length),
        .table_rd_en (table_rd_en),
        .snp_pair_out (snp_pair_data),
        .joint_table_data_out (joint_table_data),
        .first_margin_table_data_out (first_margin_table_data),
        .second_margin_table_data_out (second_margin_table_data),
        .table_valid_out (table_valid)
    );
    IMTop # (
        .DATA_WIDTH (PE_WIDTH)
    ) imtop (
        .clk (clk),
        .rst (rst),
        .joint_table_in (reg_joint_table),
        .first_margin_table_in (reg_first_margin_table),
        .second_margin_table_in (reg_second_margin_table),
        .n_in (reg_n),
        .threshold_in (reg_threshold),
        .snp_pair_in (reg_snp_pair),
        .start (im_start),
        .ready (im_ready),
        .empty (im_empty),
        .snp_pair_out (snp_pair),
        .result_out (im_result),
        .result_valid (im_result_valid)
    );
    FIFOWithCount #(
      .DATA_WIDTH(2*PE_WIDTH),
      .DEPTH_WIDTH(FIFO_DEPTH_WIDTH)
    ) snp_pair_fifo (
      .clk(clk),
      .rst(rst),
      .wr_en(fifo_wr_en),
      .rd_en(snp_pair_rd_en),
      .wr_data_in(fifo_data_in),
      .rd_data_out(snp_pair_out),
      .full(fifo_full),
      .empty(fifo_empty)
    );
    always @(posedge clk) begin
        if (rst | clear_done) begin
            fifo_wr_en <= 0;
            snp_pair_count <= 0;
        end
        else begin
            if (table_valid) begin
                reg_joint_table <= joint_table_data;
                reg_snp_pair <= snp_pair_data;
                reg_first_margin_table <= first_margin_table_data;
                reg_second_margin_table <= second_margin_table_data;
            end
            if (im_result_valid) begin
                if (im_result == 1) begin
                    fifo_data_in <= snp_pair;
                    fifo_wr_en <= 1;
                    snp_pair_count <= snp_pair_count + 1;
                end
                else begin
                    fifo_wr_en <= 0;
                end
            end
            else begin
                fifo_wr_en <= 0;
            end
        end
    end
    always @(posedge clk) begin
        if (rst) begin
            state <= READY;
            table_rd_en <= 0;
        end
        else begin
            state <= next_state;
            if (state == READY) begin
                if (start) begin
                    reg_n <= n_in;
                    reg_threshold <= threshold_in;
                    reg_snp_num <= snp_num_in;
                    reg_case_length <= case_length_in;
                    reg_ctrl_length <= ctrl_length_in;
                end
            end 
            if (state == GEN_TABLE_START) begin
            end
            if (state == GEN_TABLE) begin
            end
            if (state == READ_TABLE_START) begin
                 table_rd_en <= 1;
            end
            if (state == READ_TABLE) begin
                table_rd_en <= 0;
            end
            if (state == CALCULATE_START) begin
            end
            if (state == CALCULATE) begin
            end
            if (state == DONE) begin
            end
        end
    end
    always @(*) begin
        next_state = state;
        case (state)
            READY: begin
                if (start) begin
                    next_state = GEN_TABLE_START;
                end
            end
            GEN_TABLE_START: begin
                next_state = GEN_TABLE;
            end
            GEN_TABLE: begin
                if (table_ready && im_ready) begin
                    next_state = READ_TABLE_START;
                end
            end
            READ_TABLE_START: begin
                next_state = READ_TABLE;
            end
            READ_TABLE: begin
                if (table_valid) begin
                    next_state = CALCULATE_START;
                end
            end
            CALCULATE_START:begin
                next_state = CALCULATE;
            end
            CALCULATE: begin
                if (table_ready) begin
                    if (im_ready) begin
                        next_state = READ_TABLE_START;
                    end
                end
                else begin
                    if (im_empty) begin
                        next_state = DONE;
                    end
                end
            end
            DONE: begin
                if (clear_done) begin
                    next_state = READY;
                end
            end
      endcase
    end 
endmodule
