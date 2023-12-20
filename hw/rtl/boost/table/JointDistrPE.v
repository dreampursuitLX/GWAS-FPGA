`timescale 1ns / 1ps
module JointDistrPE #(
    parameter DATA_WIDTH = 64,
    parameter PE_WIDTH = 32,
    parameter BLOCK_WIDTH = 10
)(
    input clk,
    input rst,
    input [BLOCK_WIDTH-1:0] SNP_length,
    input [3*DATA_WIDTH-1:0] SNP_in,
    output wire [3*DATA_WIDTH-1:0] SNP_out,
    input [PE_WIDTH-1:0] SNP_id_in,
    output [PE_WIDTH-1:0] SNP_id_out,
    input init_in,
    output wire init_out,
    input flush_in,
    output wire flush_out,
    input first_block_in,
    output wire first_block_out,
    input last_block_in,
    output wire last_block_out,
    output reg table_valid,
    output wire [11*PE_WIDTH-1:0] joint_table,
    output wire [6*PE_WIDTH-1:0] margin_table
    );
    reg [BLOCK_WIDTH-1:0] bram_wr_addr;
    reg [BLOCK_WIDTH-1:0] bram_rd_addr;
    wire bram_wr_en;
    wire [3*DATA_WIDTH-1:0] bram_data_out;
    wire [3*DATA_WIDTH-1:0] left_SNP;
    wire [3*DATA_WIDTH-1:0] right_SNP;
    wire [DATA_WIDTH-1:0] SNP_pair[0:8];
    wire [PE_WIDTH-1:0] new_joint_count[0:8];
    wire [PE_WIDTH-1:0] new_first_margin_count[0:2];
    wire [PE_WIDTH-1:0] new_second_margin_count[0:2];
    wire [9*PE_WIDTH-1:0] new_joint_table;
    wire [3*PE_WIDTH-1:0] new_first_margin_table;
    wire [3*PE_WIDTH-1:0] new_second_margin_table;
    reg [PE_WIDTH-1:0] joint_counter[0:8];
    reg [PE_WIDTH-1:0] first_margin_counter[0:2];
    reg [PE_WIDTH-1:0] second_margin_counter[0:2];
    reg [3*DATA_WIDTH-1:0] reg_SNP;
    reg [PE_WIDTH-1:0] SNP_id;
    reg [PE_WIDTH-1:0] curr_SNP_id;
    reg first_block;
    reg last_block;
    reg flush;
    reg init;
    reg delay_init;
    assign SNP_out = reg_SNP;
    assign SNP_id_out = SNP_id;
    assign first_block_out = first_block;
    assign last_block_out = last_block;
    assign flush_out = flush;
    assign init_out = delay_init;
    assign joint_table =  {curr_SNP_id, SNP_id, new_joint_table};
    assign margin_table = {new_first_margin_table, new_second_margin_table};
    assign bram_wr_en = init_in;
    DP_BRAM #(
        .ADDR_WIDTH (BLOCK_WIDTH),
        .DATA_WIDTH (3*DATA_WIDTH)
    ) bram (
        .clk (clk),
        .waddr (bram_wr_addr),
        .raddr (bram_rd_addr),
        .wr_en (bram_wr_en),
        .data_in (SNP_in),
        .data_out (bram_data_out)
    );
    assign left_SNP = (init_in == 1) ? {3*DATA_WIDTH{1'b1}} : bram_data_out;
    assign right_SNP = SNP_in;
    genvar i,j;
    generate
    for (i = 0; i < 3; i = i+1)
    begin:first
        for (j = 0; j < 3; j = j+1) 
        begin:second
            assign SNP_pair[3*i+j] = left_SNP[i*DATA_WIDTH+:DATA_WIDTH] & right_SNP[j*DATA_WIDTH+:DATA_WIDTH];
            assign new_joint_table[(3*i+j)*PE_WIDTH+:PE_WIDTH] = joint_counter[3*i+j];
            BitCount #(
                .DATA_WIDTH (DATA_WIDTH),
                .WIDTH (PE_WIDTH)
            ) joint_count (
                .clk (clk),
                .data_in (SNP_pair[3*i+j]),
                .data_out (new_joint_count[3*i+j])
            ); 
        end
    end
    endgenerate
    generate
    for (i = 0; i < 3; i = i+1) 
    begin:first_margin_gen
        assign new_first_margin_table[i*PE_WIDTH+:PE_WIDTH] = first_margin_counter[i];
        BitCount #(
            .DATA_WIDTH (DATA_WIDTH),
            .WIDTH (PE_WIDTH)
        ) first_margin_count (
            .clk (clk),
            .data_in (left_SNP[i*DATA_WIDTH+:DATA_WIDTH]),
            .data_out (new_first_margin_count[i])
        ); 
       end
    endgenerate
    generate
    for (i = 0; i < 3; i = i+1) 
    begin:second_margin_gen
        assign new_second_margin_table[i*PE_WIDTH+:PE_WIDTH] = second_margin_counter[i];
        BitCount #(
            .DATA_WIDTH (DATA_WIDTH),
            .WIDTH (PE_WIDTH)
        ) second_margin_count (
            .clk (clk),
            .data_in (right_SNP[i*DATA_WIDTH+:DATA_WIDTH]),
            .data_out (new_second_margin_count[i])
        ); 
       end
    endgenerate
    always @(posedge clk) begin
        delay_init <= init;
    end
    always @(posedge clk) begin
        if (rst | flush_in) begin
            bram_wr_addr <= 0;
            bram_rd_addr <= 0;
        end 
        else begin
            if (init_in) begin
                bram_wr_addr <= bram_wr_addr + 1;
                if (last_block_in) begin
                    bram_rd_addr <= bram_rd_addr + 1;
                end
                else begin
                    bram_rd_addr <= 0;    
                end        
            end
            else if (init_in == 0 && bram_wr_addr >= SNP_length) begin
                if (bram_rd_addr == SNP_length - 1) begin
                    bram_rd_addr <= 0;
                end
                else begin
                    bram_rd_addr <= bram_rd_addr + 1;
                end
            end
        end 
    end
    always @(posedge clk) begin
        if (rst) begin
            reg_SNP <= 0;
            first_block <= 0;
            last_block <= 0;
            table_valid <= 0;
            flush <= 0;
            init <= 0;
            curr_SNP_id <= 0;
        end
        else begin
            flush <= flush_in;
            reg_SNP <= SNP_in;
            SNP_id <= SNP_id_in;
            if (init_in) begin
                first_block <= 0;
                last_block <= 0;
                table_valid <= 0;
                curr_SNP_id <= SNP_id_in;
                if (last_block_in) begin
                    init <= 1;
                    //table_valid <= 1;
                end
                else begin
                    init <= 0;
                   // table_valid <= 0;
                end
            end
            else begin
                first_block <= first_block_in;
                last_block <= last_block_in;
                if (init == 1 && last_block_in == 1) begin
                    init <= 0;
                end
                if (last_block_in) begin
                    table_valid <= 1;
                end
                else begin
                    table_valid <= 0;
                end
            end
        end
    end
    integer k;
    always @(posedge clk) begin
        for (k = 0; k < 9; k = k+1) begin
            if (rst | flush) begin
                joint_counter[k] <= 0;
                first_margin_counter[k/3] <= 0;
                second_margin_counter[k/3] <= 0;
            end
            else begin
                if (init_in) begin
                    joint_counter[k] <= 0;
                    first_margin_counter[k/3] <= 0;
                    second_margin_counter[k/3] <= 0;
                end
                else begin
                    if (first_block_in) begin
                        joint_counter[k] <= new_joint_count[k];
                        first_margin_counter[k/3] <= new_first_margin_count[k/3];
                        second_margin_counter[k/3] <= new_second_margin_count[k/3];
                    end
                    else begin
                        joint_counter[k] <= joint_counter[k] + new_joint_count[k];
                        first_margin_counter[k/3] <= first_margin_counter[k/3] + new_first_margin_count[k/3];
                        second_margin_counter[k/3] <= second_margin_counter[k/3] + new_second_margin_count[k/3];
                    end
                end
            end
        end
    end  
endmodule
