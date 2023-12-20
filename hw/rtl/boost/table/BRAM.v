`timescale 1ns / 1ps
module BRAM #(
    parameter ADDR_WIDTH = 4,
    parameter DATA_WIDTH = 8,
    parameter MEM_INIT_FILE = ""
)(
    input clk,
    input [ADDR_WIDTH-1:0] addr,
    input write_en,
    input [DATA_WIDTH-1:0] data_in,
    output reg [DATA_WIDTH-1:0] data_out);
    reg [DATA_WIDTH-1:0] mem [0:2**ADDR_WIDTH-1];
    integer i;
    initial begin
        if (MEM_INIT_FILE != "") begin
            $readmemh(MEM_INIT_FILE, mem);
        end
    end
    always @(posedge clk) begin
        if (write_en == 1)
            mem[addr] <= data_in;
        data_out <= mem[addr];
    end
endmodule