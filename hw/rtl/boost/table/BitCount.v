`timescale 1ns / 1ps
module BitCount #(
    parameter DATA_WIDTH = 64,
    parameter WIDTH = 8 
)(
    input clk,
    input [DATA_WIDTH-1:0] data_in,
    output wire [WIDTH-1:0] data_out
    );
    reg [WIDTH-1:0] num;
    assign data_out = num;
    integer i;
    always @(*) begin
        num = 0;
        for (i = 0; i < DATA_WIDTH; i = i+1) 
        begin: get_i_num
            if (data_in[i]) begin
                num = num + 1;
            end
        end
    end
endmodule
