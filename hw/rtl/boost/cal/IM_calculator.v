`timescale 1ns / 1ps
module IM_calculator #(
    parameter DATA_WIDTH = 16,
    parameter FLOAT_WIDTH = 32
)(
    input clk,
    input rst,
    input [18*DATA_WIDTH-1:0] joint_table_in,
    input [DATA_WIDTH-1:0] n_in,
    input [9*FLOAT_WIDTH-1:0] Pab_in,
    input [6*FLOAT_WIDTH-1:0] Pbc_in,
    input [6*FLOAT_WIDTH-1:0] Pca_in,
    input data_valid_in,
    output wire [18*FLOAT_WIDTH-1:0] IM_out,
    output wire [18*FLOAT_WIDTH-1:0] tao_out,
    output wire data_valid_out,
    output reg busy
    );
    wire data_valid[0:17];
    wire [FLOAT_WIDTH-1:0] Pab[0:17];
    wire [FLOAT_WIDTH-1:0] Pbc[0:17];
    wire [FLOAT_WIDTH-1:0] Pca[0:17];
    wire [DATA_WIDTH-1:0] joint_table[0:17];
    wire [FLOAT_WIDTH-1:0] IM[0:17];
    wire [FLOAT_WIDTH-1:0] tao[0:17];
    reg [17:0] result_valid;
    assign data_valid_out = (& result_valid) ? 1 : 0;
    genvar i,j,k;
    generate 
        for (i = 0; i < 3; i = i+1) begin:first
           for (j = 0; j < 3; j = j+1) begin:second
                for (k = 0; k < 2; k = k+1) begin:third
                    assign IM_out[(k*9+i*3+j)*FLOAT_WIDTH+:FLOAT_WIDTH] = IM[k*9+i*3+j];
                    assign tao_out[(k*9+i*3+j)*FLOAT_WIDTH+:FLOAT_WIDTH] = tao[k*9+i*3+j];
                    assign Pab[k*9+i*3+j] = Pab_in[(3*j+i)*FLOAT_WIDTH+:FLOAT_WIDTH];
                    assign Pbc[k*9+i*3+j] = Pbc_in[(3*k+j)*FLOAT_WIDTH+:FLOAT_WIDTH];
                    assign Pca[k*9+i*3+j] = Pca_in[(2*i+k)*FLOAT_WIDTH+:FLOAT_WIDTH];
                    assign joint_table[k*9+i*3+j] = joint_table_in[(k*9+i*3+j)*DATA_WIDTH+:DATA_WIDTH];
                    Ptmp_calculator #(
                        .DATA_WIDTH (DATA_WIDTH),
                        .FLOAT_WIDTH (FLOAT_WIDTH)
                    ) ptmp (
                        .clk (clk),
                        .rst (rst),
                        .Pab_in (Pab[k*9+i*3+j]),
                        .Pbc_in (Pbc[k*9+i*3+j]),
                        .Pca_in (Pca[k*9+i*3+j]),
                        .joint_table_in (joint_table[k*9+i*3+j]),
                        .n_in (n_in),
                        .data_valid_in (data_valid_in),
                        .IM_out (IM[k*9+i*3+j]),
                        .tao_out (tao[k*9+i*3+j]),
                        .data_valid_out (data_valid[k*9+i*3+j])
                    );
                end
            end
        end
    endgenerate
    genvar m; 
    generate
        for (m = 0; m < 18; m = m+1) begin:gen_valid
            always @(posedge clk) begin
                if (rst || data_valid_in || data_valid_out) begin
                    result_valid[m] <= 0;
                end
                if (data_valid[m]) begin
                    result_valid[m] <= 1;
                end
            end
        end
    endgenerate
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
