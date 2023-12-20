`timescale 1ns / 1ps
module Counter (
    input clk,
    input rst,
	 input start,
	 input clear,
	 output wire [7:0] res
	 );
	 reg [7:0] y;
	 reg count_en;
	 assign res = y;
	 always@ (posedge clk) begin
	     if (rst || clear) begin
		      count_en <= 0;
		  end
		  else if (start) begin
		      count_en <= 1;
		  end
	 end
	 always@ (posedge clk) begin
	     if (rst) begin
		      y <= 0;
		  end
		  else if (count_en) begin
		      y <= y + 1;
		  end
		  else if (clear) begin
		      y <= 0;
		  end
	 end
endmodule