`timescale 1ns / 1ps

module JDTop #(
    parameter DATA_WIDTH = 64,
    parameter BLOCK_WIDTH = 16,
    parameter PE_WIDTH = 16,
    parameter BRAM_ADDR_WIDTH = 32,
    parameter PE_NUM = 4,
    parameter CASE_FILENAME = "",
    parameter CTRL_FILENAME = ""
)(
    input clk,
    input rst,
    input start,
    input clear_done,
    
    input [8*DATA_WIDTH-1:0] case_in,  //(snp, x=1, x=2, x=3)
    input [8*DATA_WIDTH-1:0] ctrl_in,
    input [BRAM_ADDR_WIDTH-1:0] case_wr_addr,
    input [BRAM_ADDR_WIDTH-1:0] ctrl_wr_addr,
    input case_wr_en,
    input ctrl_wr_en,
    
    input [PE_WIDTH-1:0] snp_num_in,        // snp的数量
    input [BLOCK_WIDTH-1:0] case_length_in, //case组的长度=case样本数/sizeof(uint)
    input [BLOCK_WIDTH-1:0] ctrl_length_in, //ctrl组的长度=ctrl样本数/sizeof(uint)
    
    input table_rd_en,
    output wire [2*PE_WIDTH-1:0] snp_pair_out,  //(snpx,snpy)
    output wire [18*PE_WIDTH-1:0] joint_table_data_out, //联合分布表 2*3*3 case+ctrl
    output wire [6*PE_WIDTH-1:0] first_margin_table_data_out, //snpx 边缘分布表 2*3 case+ctrl
    output wire [6*PE_WIDTH-1:0] second_margin_table_data_out,//snpy 边缘分布表 2*3 case+ctrl
    output reg table_valid_out,
    
    output wire table_ready,
    output wire ready,
    output wire done
    );
    
    localparam FIFO_DEPTH_WIDTH = 16;
    localparam READY=1, ARRAY_START=2, ARRAY_PROCESSING=3, BLOCK=4, DONE=5;
    
    wire array_start;
    wire case_array_done;
    wire ctrl_array_done;
    
    wire [BRAM_ADDR_WIDTH-1:0] case_bram_rd_addr;
    wire [BRAM_ADDR_WIDTH-1:0] ctrl_bram_rd_addr;
    wire [BRAM_ADDR_WIDTH-1:0] case_bram_addr;
    wire [BRAM_ADDR_WIDTH-1:0] ctrl_bram_addr;
    wire [8*DATA_WIDTH-1:0] case_bram_data_out;
    wire [8*DATA_WIDTH-1:0] ctrl_bram_data_out;
    
    wire [11*PE_WIDTH-1:0] case_joint_table_data;
    wire [11*PE_WIDTH-1:0] ctrl_joint_table_data;
    wire [6*PE_WIDTH-1:0] case_margin_table_data;
    wire [6*PE_WIDTH-1:0] ctrl_margin_table_data;
    wire case_table_valid;
    wire ctrl_table_valid;
    
    wire case_table_fifo_wr_en;
    wire ctrl_table_fifo_wr_en;
    wire [17*PE_WIDTH-1:0] case_table_fifo_wr_data_in;
    wire [17*PE_WIDTH-1:0] ctrl_table_fifo_wr_data_in;
    wire [17*PE_WIDTH-1:0] case_table_fifo_rd_data_out;
    wire [17*PE_WIDTH-1:0] ctrl_table_fifo_rd_data_out;
    wire case_table_fifo_full;
    wire ctrl_table_fifo_full;
    wire case_table_fifo_empty;
    wire ctrl_table_fifo_empty;
    wire [FIFO_DEPTH_WIDTH:0] case_table_fifo_count;
    wire [FIFO_DEPTH_WIDTH:0] ctrl_table_fifo_count;
    wire table_fifo_rd_en;

    reg [PE_WIDTH-1:0] snp_num;
    reg [BLOCK_WIDTH-1:0] case_length;
    reg [BLOCK_WIDTH-1:0] ctrl_length;
    
    wire [4*DATA_WIDTH-1:0] case_array_in;
    wire [4*DATA_WIDTH-1:0] ctrl_array_in;
    
    reg [2:0] state;
    reg [2:0] next_state;
    reg rst_array;
    
    assign snp_pair_out = ctrl_table_fifo_rd_data_out[17*PE_WIDTH-1:15*PE_WIDTH];
    assign joint_table_data_out = {ctrl_table_fifo_rd_data_out[15*PE_WIDTH-1:6*PE_WIDTH], case_table_fifo_rd_data_out[15*PE_WIDTH-1:6*PE_WIDTH]};
    assign first_margin_table_data_out = {ctrl_table_fifo_rd_data_out[6*PE_WIDTH-1:3*PE_WIDTH], case_table_fifo_rd_data_out[6*PE_WIDTH-1:3*PE_WIDTH]};
    assign second_margin_table_data_out = {ctrl_table_fifo_rd_data_out[3*PE_WIDTH-1:0], case_table_fifo_rd_data_out[3*PE_WIDTH-1:0]};
    assign table_fifo_rd_en = table_rd_en;
    
    assign table_ready = ~case_table_fifo_empty & ~ctrl_table_fifo_empty;
    assign array_start = (state == ARRAY_START);
    assign ready = (state == READY) && (~start);
    assign done = (state == BLOCK);
    
    assign case_bram_addr = (case_wr_en) ? case_wr_addr : (case_bram_rd_addr >> 1);
    assign ctrl_bram_addr = (ctrl_wr_en) ? ctrl_wr_addr : (ctrl_bram_rd_addr >> 1);
       
    BRAM #(
      .ADDR_WIDTH(BRAM_ADDR_WIDTH),
      .DATA_WIDTH(8*DATA_WIDTH),
      .MEM_INIT_FILE(CASE_FILENAME)
    ) case_bram (
      .clk(clk),
      .addr(case_bram_addr),
      .write_en(case_wr_en),
      .data_in(case_in),
      .data_out(case_bram_data_out)
    );
    
    BRAM #(
      .ADDR_WIDTH(BRAM_ADDR_WIDTH),
      .DATA_WIDTH(8*DATA_WIDTH),
      .MEM_INIT_FILE(CTRL_FILENAME)
    ) ctrl_bram (
      .clk(clk),
      .addr (ctrl_bram_addr),
      .write_en (ctrl_wr_en),
      .data_in (ctrl_in),
      .data_out (ctrl_bram_data_out)
    );
    
    assign case_table_fifo_wr_en = case_table_valid;
    assign case_table_fifo_wr_data_in = {case_joint_table_data, case_margin_table_data};
    
    FIFOWithCount #(
      .DATA_WIDTH(17*PE_WIDTH),
      .DEPTH_WIDTH(FIFO_DEPTH_WIDTH)
    ) case_table_fifo (
      .clk(clk),
      .rst(rst),

      .wr_en(case_table_fifo_wr_en),
      .rd_en(table_fifo_rd_en),
      .wr_data_in(case_table_fifo_wr_data_in),
      .rd_data_out(case_table_fifo_rd_data_out),
      .count(case_table_fifo_count),
      .full(case_table_fifo_full),
      .empty(case_table_fifo_empty)
    );
    
    assign ctrl_table_fifo_wr_en = ctrl_table_valid;
    assign ctrl_table_fifo_wr_data_in = {ctrl_joint_table_data, ctrl_margin_table_data};
    
    FIFOWithCount #(
      .DATA_WIDTH(17*PE_WIDTH),
      .DEPTH_WIDTH(FIFO_DEPTH_WIDTH)
    ) ctrl_table_fifo (
      .clk(clk),
      .rst(rst),

      .wr_en(ctrl_table_fifo_wr_en),
      .rd_en(table_fifo_rd_en),
      .wr_data_in(ctrl_table_fifo_wr_data_in),
      .rd_data_out(ctrl_table_fifo_rd_data_out),
      .count(ctrl_table_fifo_count),
      .full(ctrl_table_fifo_full),
      .empty(ctrl_table_fifo_empty)
    );
    
    reg case_bram_block_addr;
    reg ctrl_bram_block_addr;
    
    assign case_array_in = (case_bram_block_addr == 0) ? case_bram_data_out[4*DATA_WIDTH-1:0] : case_bram_data_out[8*DATA_WIDTH-1:4*DATA_WIDTH];
    assign ctrl_array_in = (ctrl_bram_block_addr == 0) ? ctrl_bram_data_out[4*DATA_WIDTH-1:0] : ctrl_bram_data_out[8*DATA_WIDTH-1:4*DATA_WIDTH];
    
    always@ (posedge clk) begin
        case_bram_block_addr <= case_bram_rd_addr[0];
        ctrl_bram_block_addr <= ctrl_bram_rd_addr[0];
    end
 
    JointDistrArray # (
        .DATA_WIDTH (DATA_WIDTH),
        .PE_WIDTH (PE_WIDTH),
        .BLOCK_WIDTH (BLOCK_WIDTH),
        .ADDR_WIDTH (BRAM_ADDR_WIDTH),
        .PE_NUM (PE_NUM)
    ) case_array (
        .clk (clk),
        .rst (rst_array),
        .start (array_start),
        .done (case_array_done),
        
        .SNP_num_in (snp_num),
        .SNP_length_in (case_length),
        .bram_data_in (case_array_in),
        .bram_rd_addr (case_bram_rd_addr),
        
        .table_valid_out (case_table_valid),
        .joint_table_data_out (case_joint_table_data),
        .margin_table_data_out (case_margin_table_data)
    );
    
    JointDistrArray # (
        .DATA_WIDTH (DATA_WIDTH),
        .PE_WIDTH (PE_WIDTH),
        .BLOCK_WIDTH (BLOCK_WIDTH),
        .ADDR_WIDTH (BRAM_ADDR_WIDTH),
        .PE_NUM (PE_NUM)
    ) ctrl_array (
        .clk (clk),
        .rst (rst_array),
        .start (array_start),
        .done (ctrl_array_done),
        
        .SNP_num_in (snp_num),
        .SNP_length_in (ctrl_length),
        .bram_data_in (ctrl_array_in),
        .bram_rd_addr (ctrl_bram_rd_addr),
        
        .table_valid_out (ctrl_table_valid),
        .joint_table_data_out (ctrl_joint_table_data),
        .margin_table_data_out (ctrl_margin_table_data)
    );
    
    always @(posedge clk) begin
        if (rst) begin
            table_valid_out <= 0;
        end
        else begin
            if (table_rd_en) begin
                table_valid_out <= 1;
            end
            else begin
                table_valid_out <= 0;
            end
        end
    end
    
    always @(posedge clk) begin
        if (rst) begin
            rst_array <= 1;
            state <= READY;
        end
        else begin
            state <= next_state;
            if (state == READY) begin
                rst_array <= 0;
                if (start) begin
                    snp_num <= snp_num_in;
                    case_length <= case_length_in;
                    ctrl_length <= ctrl_length_in;
                end
            end
            if (state == ARRAY_PROCESSING) begin
            end
            if (state == BLOCK) begin
            end
            if (state == DONE) begin
                rst_array <= 1;
            end
        end
    end
    
    always @(*) begin
        next_state = state;
        case (state)
            READY: begin
                if (start) begin
                    next_state = ARRAY_START;
                end
            end
            ARRAY_START: begin
                next_state = ARRAY_PROCESSING;
            end
            ARRAY_PROCESSING: begin
                if (case_array_done == 1 && ctrl_array_done == 1) begin
                    next_state = BLOCK;
                end
            end
            BLOCK: begin
                if (case_table_fifo_empty == 1 && ctrl_table_fifo_empty == 1) begin
                    next_state = DONE;
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
