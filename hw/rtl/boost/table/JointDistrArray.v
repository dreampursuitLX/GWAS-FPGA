`timescale 1ns / 1ps

module JointDistrArray #(
    parameter DATA_WIDTH = 64,//SNP data
    parameter PE_WIDTH = 16, //SNP num
    parameter BLOCK_WIDTH = 16, //longint num
    parameter ADDR_WIDTH = 32,
    parameter PE_NUM = 8
)(
    input clk,
    input rst,
    input start,
    
    input [PE_WIDTH-1:0] SNP_num_in,
    input [BLOCK_WIDTH-1:0] SNP_length_in,
    input [4*DATA_WIDTH-1:0] bram_data_in,
    output reg [ADDR_WIDTH-1:0] bram_rd_addr,
    
    output reg table_valid_out,
    output reg [11*PE_WIDTH-1:0] joint_table_data_out,
    output reg [6*PE_WIDTH-1:0] margin_table_data_out,
    
    output wire done
    );
    
    localparam LOG_PE_NUM = $clog2(PE_NUM);
    localparam WAIT=0, STREAM_SNP_START=1, STREAM_SNP_INIT=2, STREAM_SNP=3, STREAM_SNP_STOP=4, STREAM_SNP_DONE=5, DONE=6;
    
    reg [3:0] state;
    reg [3:0] next_state;
    
    reg [PE_WIDTH-1:0] SNP_num;
    reg [BLOCK_WIDTH-1:0] SNP_length;
    reg [BLOCK_WIDTH-1:0] SNP_block_pos; //当前SNP中的第几段 0~SNP_length-1
    reg [PE_WIDTH-1:0] SNP_curr_pos;    //当前SNP编号  0~SNP_num-1
    reg [PE_WIDTH-1:0] SNP_start_pos;
    reg [ADDR_WIDTH-1:0] bram_start_rd_addr;
    
    reg rst_pe[0:PE_NUM-1];
    
    wire init_in [0:PE_NUM-1];
    wire init_out [0:PE_NUM-1];
    wire flush_in [0:PE_NUM-1];
    wire flush_out [0:PE_NUM-1];
    wire first_block_in [0:PE_NUM-1];
    wire first_block_out [0:PE_NUM-1];
    wire last_block_in [0:PE_NUM-1];
    wire last_block_out [0:PE_NUM-1];
    wire [3*DATA_WIDTH-1:0] SNP_in [0:PE_NUM-1];
    wire [3*DATA_WIDTH-1:0] SNP_out [0:PE_NUM-1];
    wire [PE_WIDTH-1:0] SNP_id_in [0:PE_NUM-1];
    wire [PE_WIDTH-1:0] SNP_id_out [0:PE_NUM-1];
    wire table_valid [0:PE_NUM-1];
    wire [11*PE_WIDTH-1:0] joint_table_data [0:PE_NUM-1];
    wire [6*PE_WIDTH-1:0] margin_table_data [0:PE_NUM-1];
    
    reg init_in_0;
    reg delay_init_in_0;
    reg flush_in_0;
    reg first_block_in_0;
    reg last_block_in_0;
    wire [3*DATA_WIDTH-1:0] SNP_in_0;
    
    reg select_table_valid;
    reg [11*PE_WIDTH-1:0] select_joint_table_data;
    reg [6*PE_WIDTH-1:0] select_margin_table_data;
    
    assign done = (state == DONE);
    
    always @(posedge clk) begin
        if (rst) begin
            state <= WAIT;
            SNP_block_pos <= 0;
            SNP_curr_pos <= 0;
            bram_start_rd_addr <= 0;
            SNP_start_pos <= 0;
            init_in_0 <= 0;
            table_valid_out <= 0;
            table_valid_out <= 0;
        end
        else begin
            state <= next_state;
            table_valid_out <= select_table_valid;
            joint_table_data_out <= select_joint_table_data;
            margin_table_data_out <= select_margin_table_data;
            if (state == WAIT) begin
                SNP_block_pos <= 0;
                SNP_curr_pos <= 0;
                SNP_start_pos <= 0;
                bram_start_rd_addr <= 0;
                init_in_0 <= 0;
                SNP_length <= SNP_length_in;
                SNP_num <= SNP_num_in;
            end
            if (state == STREAM_SNP_START) begin
                bram_rd_addr <= bram_start_rd_addr;
                SNP_curr_pos <= SNP_start_pos;
                init_in_0 <= 1;
            end
            if (state == STREAM_SNP_INIT) begin
                bram_rd_addr <= bram_rd_addr + 1;
                bram_start_rd_addr <= bram_start_rd_addr + 1;
                if (SNP_block_pos == SNP_length - 1) begin
                    SNP_block_pos <= 0;
                    SNP_curr_pos <= SNP_curr_pos + 1;
                    SNP_start_pos <= SNP_start_pos + 1;
                    init_in_0 <= 0;
                end
                else begin
                    SNP_block_pos <= SNP_block_pos + 1;
                end
            end
            if (state == STREAM_SNP) begin
                bram_rd_addr <= bram_rd_addr + 1;
                if (SNP_block_pos == SNP_length - 1) begin
                    SNP_block_pos <= 0;
                    SNP_curr_pos <= SNP_curr_pos + 1;
                end
                else begin
                    SNP_block_pos <= SNP_block_pos + 1;
                end
            end
            if (state == STREAM_SNP_STOP) begin
                SNP_block_pos <= 0;
            end
        end
    end
    
    genvar i,k;
    
    assign init_in[0] = delay_init_in_0;
    assign flush_in[0] = flush_in_0;
    assign first_block_in[0] = first_block_in_0;
    assign last_block_in[0] = last_block_in_0;
    assign SNP_in[0] = SNP_in_0;
    assign SNP_id_in[0] = (state >= STREAM_SNP_INIT) ? bram_data_in[4*DATA_WIDTH-1:3*DATA_WIDTH] : 0;
    assign SNP_in_0 = (state >= STREAM_SNP_INIT) ? bram_data_in[3*DATA_WIDTH-1:0] : 0;
    
    always @(posedge clk) begin
        if (rst) begin
            flush_in_0 <= 0;
            first_block_in_0 <= 0;
            last_block_in_0 <= 0;
            delay_init_in_0 <= 0;
        end
        else begin
            flush_in_0 <= (next_state == STREAM_SNP_STOP) ? 1 : 0;
            first_block_in_0 <= (SNP_block_pos == 0) ? 1 : 0;
            last_block_in_0 <= (SNP_block_pos == SNP_length - 1) ? 1 : 0;
            delay_init_in_0 <= init_in_0;
        end
    end
      
    generate
    for (i = 0; i < PE_NUM; i = i+1) 
    begin: rst_pe_gen
        always @(posedge clk) begin
            if (rst) begin
                rst_pe[i] <= 1;
            end
            else begin
                rst_pe[i] <= 0;
            end
        end
    end
    endgenerate
    
    generate
    for (i = 1; i < PE_NUM; i = i+1)
    begin: systolic_connections
        assign init_in[i] = init_out[i-1];
        assign flush_in[i] = flush_out[i-1];
        assign first_block_in[i] = first_block_out[i-1];
        assign last_block_in[i] = last_block_out[i-1];
        assign SNP_in[i] = SNP_out[i-1];
        assign SNP_id_in[i] = SNP_id_out[i-1];
    end
    endgenerate
    
    integer j;
    always @(*) begin
        select_table_valid = 0;
        for (j = 0; j < PE_NUM; j = j+1)
        begin:table_data_select
            if (table_valid[j]) begin
                select_table_valid = 1;
                select_joint_table_data = joint_table_data[j];
                select_margin_table_data = margin_table_data[j];
            end
        end
    end
    
    generate 
    for (k = 0; k < PE_NUM; k = k+1) 
    begin:jdpe_gen
    JointDistrPE #(
        .DATA_WIDTH (DATA_WIDTH),
        .BLOCK_WIDTH (BLOCK_WIDTH),
        .PE_WIDTH (PE_WIDTH)
    ) jdpe (
        .clk (clk),
        .rst (rst_pe[k]),
        
        .SNP_in (SNP_in[k]),
        .SNP_out (SNP_out[k]),
        .SNP_id_in (SNP_id_in[k]),
        .SNP_id_out (SNP_id_out[k]),
        .SNP_length (SNP_length),
        
        .init_in (init_in[k]),
        .init_out (init_out[k]),
        .flush_in (flush_in[k]),
        .flush_out (flush_out[k]),
        .first_block_in (first_block_in[k]),
        .first_block_out (first_block_out[k]),
        .last_block_in (last_block_in[k]),
        .last_block_out (last_block_out[k]),
        
        .table_valid (table_valid[k]),
        .joint_table (joint_table_data[k]),
        .margin_table (margin_table_data[k])
    );
    end
    endgenerate
    
    always @(*) begin
        next_state = state;
        case (state)
            WAIT:
                if (start) begin
                    next_state = STREAM_SNP_START;
                end
            STREAM_SNP_START:
                next_state = STREAM_SNP_INIT;
            STREAM_SNP_INIT:
                if (SNP_block_pos == SNP_length - 1) begin
                    if (SNP_start_pos[LOG_PE_NUM-1:0] == PE_NUM-1) begin
                        next_state = STREAM_SNP;
                    end 
                    else if (SNP_curr_pos >= SNP_num-1) begin
                        next_state = STREAM_SNP_STOP;
                    end
                end
            STREAM_SNP:
                if ((SNP_block_pos == SNP_length - 1 && SNP_curr_pos == SNP_num - 1) || (SNP_curr_pos > SNP_num - 1)) begin
                    next_state = STREAM_SNP_STOP;
                end
            STREAM_SNP_STOP: 
                if (SNP_start_pos >= SNP_num) begin
                    next_state = STREAM_SNP_DONE;
                end
                else begin
                    next_state = STREAM_SNP_START;
                end
            STREAM_SNP_DONE:
                if (flush_out[PE_NUM-1]) begin
                    next_state = DONE;
                end 
            DONE:
                next_state = WAIT;
        endcase
    end
endmodule
