// (C) 2001-2018 Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License Subscription 
// Agreement, Intel FPGA IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Intel and sold by 
// Intel or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


/*

Custom pattern checker core

Author:  JCJB
Date:    04/14/2010

Version:  2.1

Description:  This component is programmed via a host or master through the pattern slave port to program the internal test memory.  When the host
              writes to the start bit of the CSR slave port the component will begin to send the contents from the internal memory to the data streaming
              port.  You should use the custom pattern generator component with this component.

Register map:

|-------------------------------------------------------------------------------------------------------------------------------------------------------|
|  Address   |   Access Type   |                                                            Bits                                                        |
|            |                 |------------------------------------------------------------------------------------------------------------------------|
|            |                 |            31..24            |            23..16            |            15..8            |            7..0            |
|-------------------------------------------------------------------------------------------------------------------------------------------------------|
|     0      |       r/w       |                                                       Payload Length                                                   |
|     4      |       r/w       |                        Pattern Position                                             Pattern Length                     |
|     8      |       r/w       |                                                          Control                                                       |
|     12     |      r/wclr     |                                                          Status                                                        |
|-------------------------------------------------------------------------------------------------------------------------------------------------------|


Address 0  --> Bits 31:0 are used store the payload length.  This field should only be written to while the checker is stopped.  This field is ignored if the
               infinite length test enable bit is set in the control register.
Address 4  --> Bits 15:0 is used to store pattern length, bits 31:16 used to store a new position in the pattern.  The position will update as the checker is
               operating.
               These fields should only be written to while the checker core is stopped.
Address 8  --> Bit 0 (infinite length test enable)is used to instruct the checker to ignore the payload length field and check the pattern until stopped.
               Bit 1 (checking complete IRQ mask) is the checking complete interrupt mask bit.
               Bit 2 (failure detected IRQ mask) is the checking failure interrupt mask bit.
               Bit 3 (accept only packet data enable) is used to instruct the checker to ignore any data received before SOP and after EOP.
               Bit 4 (stop on failure detection enable) is used to stop the checker when a failure is detected
               Bit 31 (checker enable) is used to start the checker core so that it begins receiving data.  This field must be set at the same time or after all the
                      other fields bits are programmed.  This field must be cleared before modifying other fields.  This field is cleared automatically when checking
                      completes.
Address 12 --> Bit 0 (checker operating) when set the checker is operational.
               Bit 1 (checker complete) is set when the checker completes the test.
               Bit 2 (error detected) is set when the checker detects an error during the test.
               Bit 3 (irq) is set when the IRQ fires, write a 1 to this bit to clear the interrupt
               Bit 4 (error count overflow) when the error counter overflows this bit is set.  This bit is cleared when the checker is started.
               Bits 31:16 (error count) each time an error is detected this counter is incremented.  This counter is cleared when the checker is started. 

               
Version History:

1.0  (04/14/2010)  Initial version used in the Qsys tutorial

2.0  (09/15/2015)  New version that adds interrupts, sop/eop, and a new CSR mapping (software is not compatible with versions 1.0 and 2.0) Almost a complete re-write
                   except the comparison pipeline. 

2.1  (04/10/2018)  Added snk_empty so that when snk_eop is high the checker will only perform the pattern checking across symbols (bytes) that are valid.                   
*/



module mtm_custom_pattern_checker (
  clk,
  reset,

  csr_address,
  csr_writedata,
  csr_write,
  csr_readdata,
  csr_read,
  csr_byteenable,
  
  irq,

  pattern_address,
  pattern_writedata,
  pattern_write,
  pattern_byteenable,

  snk_data,
  snk_valid,
  snk_ready,
  snk_empty,
  snk_sop,
  snk_eop
);


  parameter DATA_WIDTH = 128;           // must be an even multiple of 8 and is used to determine the width of the 2nd port of the on-chip RAM and streaming port
  parameter MAX_PATTERN_LENGTH = 64;    // used to determine the depth of the on-chip RAM and modulo counter width, set to a multiple of 2
  parameter ADDRESS_WIDTH = 6;          // log2(MAX_PATTERN_LENGTH) will be set by the .tcl file
  parameter EMPTY_WIDTH = 4;            // log2(DATA_WIDTH/8) set by the .tcl file
  
    localparam NUM_OF_SYMBOLS = DATA_WIDTH / 8;
  localparam BLOCK_WIDTH = $clog2(DATA_WIDTH / 8);
  localparam NUM_DIR_BLOCK = 32;
  localparam DIR_BRAM_ADDR_WIDTH = ADDRESS_WIDTH;
  localparam TILE_WIDTH = 12;
  localparam MAX_TILE_SIZE = 2**TILE_WIDTH;
  localparam PE_WIDTH = 16;
  
  


  input clk;
  input reset;

  input [1:0] csr_address;
  input [31:0] csr_writedata;
  input csr_write;
  output reg [31:0] csr_readdata;
  input csr_read;
  input [3:0] csr_byteenable;
  
  output reg irq;

  input [ADDRESS_WIDTH-1:0] pattern_address;
  input [63:0] pattern_writedata;
  input pattern_write;
  //output reg [63:0] pattern_readdata;
  //input pattern_read;
  input [7:0] pattern_byteenable;

  input [DATA_WIDTH-1:0] snk_data;
  input snk_valid;
  output wire snk_ready;
  input [EMPTY_WIDTH-1:0] snk_empty;
  input snk_sop;
  input snk_eop;
  

  reg running;
  wire set_running;
  wire clear_running;
  reg sop_seen;
  wire set_sop_seen;
  wire clear_sop_seen;
  wire packet_filter;
  wire valid_data;
  wire [DATA_WIDTH-1:0] data_in;
  
  
  reg [15:0] ref_length_in;
  reg [15:0] query_length_in;
  reg [15:0] ref_start_addr_in;
  reg [15:0] query_start_addr_in; 
  reg ref_wr_en;
  reg query_wr_en;
  reg [DATA_WIDTH-1:0] ref_in;
  reg [DATA_WIDTH-1:0] query_in;
  reg [TILE_WIDTH-BLOCK_WIDTH-1:0] ref_addr;
  reg [TILE_WIDTH-BLOCK_WIDTH-1:0] query_addr;
  wire query_or_ref; //0:query_data  1:ref_data
  wire set_addr_len;
  
  reg [TILE_WIDTH-1:0] reg_ref_len;
  reg [TILE_WIDTH-1:0] reg_query_len;
  
  reg [31:0] control;
  reg [7:0] reg_align_fields;
  
  wire [2*NUM_DIR_BLOCK-1:0]     dir_data_out;
  wire [DIR_BRAM_ADDR_WIDTH-1:0] dir_rd_addr;
  wire [DIR_BRAM_ADDR_WIDTH-1:0] dir_total_count;
  
  
  wire start;
  wire clear_done;
  wire set_params;
  wire done;
  wire ready;
  
  wire [PE_WIDTH-1:0]     max_tile_score;
  wire [TILE_WIDTH-1:0]   ref_max_pos;
  wire [TILE_WIDTH-1:0]   query_max_pos;
  wire [TILE_WIDTH-1:0]   num_ref_bases;
  wire [TILE_WIDTH-1:0]   num_query_bases;
  wire [2*TILE_WIDTH-1:0] num_tb_steps;
  

  reg [12*PE_WIDTH-1:0] in_params;
  reg [TILE_WIDTH-1:0]  max_tb_steps;
  reg [PE_WIDTH-1:0]    score_threshold;
  
  
  // write ref_addr,query_addr
  always @ (posedge clk)
  begin
    if (reset == 1)
    begin
      ref_start_addr_in <= 16'h0000;
      query_start_addr_in <= 16'h0000;
    end
    else
    begin
      if ((csr_address == 2'b00) & (csr_write == 1) & (csr_byteenable[0] == 1))
        ref_start_addr_in[7:0] <= csr_writedata[7:0];
      if ((csr_address == 2'b00) & (csr_write == 1) & (csr_byteenable[1] == 1))
        ref_start_addr_in[15:8] <= csr_writedata[15:8];
      if ((csr_address == 2'b00) & (csr_write == 1) & (csr_byteenable[2] == 1))
        query_start_addr_in[7:0] <= csr_writedata[23:16];
      if ((csr_address == 2'b00) & (csr_write == 1) & (csr_byteenable[3] == 1))
        query_start_addr_in[15:8] <= csr_writedata[31:24];
    end
  end

  //write ref_length,query_length
  always @ (posedge clk)
  begin
    if (reset == 1)
    begin
      ref_length_in <= 16'h0000;
      query_length_in <= 16'h0000;
    end
    else
    begin
      if ((csr_address == 2'b01) & (csr_write == 1) & (csr_byteenable[0] == 1))
        ref_length_in[7:0] <= csr_writedata[7:0];
      if ((csr_address == 2'b01) & (csr_write == 1) & (csr_byteenable[1] == 1))
        ref_length_in[15:8] <= csr_writedata[15:8];
      if ((csr_address == 2'b01) & (csr_write == 1) & (csr_byteenable[2] == 1))
        query_length_in[7:0] <= csr_writedata[23:16];
      if ((csr_address == 2'b01) & (csr_write == 1) & (csr_byteenable[3] == 1))
        query_length_in[15:8] <= csr_writedata[31:24];          
    end
  end   
  
    always @ (posedge clk)
  begin
    if (reset == 1)
    begin
      control <= 32'h00000000;
    end
    else
    begin
      if ((csr_address == 2'b10) & (csr_write == 1) & (csr_byteenable[0] == 1))
        control[7:0] <= csr_writedata[7:0];
      if ((csr_address == 2'b10) & (csr_write == 1) & (csr_byteenable[1] == 1))
	  begin
        control[15:8] <= csr_writedata[15:8];
		if (set_addr_len)
		  reg_align_fields <= csr_writedata[15:8];
	  end
      if ((csr_address == 2'b10) & (csr_write == 1) & (csr_byteenable[2] == 1))
        control[23:16] <= csr_writedata[23:16];
      if ((csr_address == 2'b10) & (csr_write == 1) & (csr_byteenable[3] == 1))
        control[30:24] <= csr_writedata[30:24];    // control bit 31 is handled separate since it's self clearing and will be represented by the 'running' register
    end
  end

  //read result or status
  always @ (posedge clk)
  begin
    if (reset == 1)
    begin
      csr_readdata <= 32'h00000000;
    end
    else if (csr_read == 1)
    begin
      case (csr_address)
        2'b00:  csr_readdata <= {4'h0, query_max_pos, 4'h0, ref_max_pos};   
        2'b01:  csr_readdata <= {16'h0000, max_tile_score}; 
        2'b10:  csr_readdata <= {8'h00, num_tb_steps};  
        2'b11:  csr_readdata <= {28'h0000000, 1'b0, ready, done, running};
        default:  csr_readdata <= {28'h0000000, 1'b0, ready, done, running};
      endcase
    end
  end

  //send data to GACTTop
  always @ (posedge clk)
  begin
    if (reset == 1)
    begin
      query_in <= 0;
      ref_in <= 0;
      query_wr_en <= 0;
      ref_wr_en <= 0;
      query_addr <= 0;
      ref_addr <= 0;
    end
	else if (set_addr_len == 1) 
	begin
	  reg_ref_len <= ref_length_in[TILE_WIDTH-1:0];
	  reg_query_len <= query_length_in[TILE_WIDTH-1:0];
	  ref_addr <= ref_start_addr_in[TILE_WIDTH-BLOCK_WIDTH-1:0];
      query_addr <= query_start_addr_in[TILE_WIDTH-BLOCK_WIDTH-1:0];
	end
    else if (valid_data == 1)
    begin
      if (query_or_ref == 0)
      begin
        query_in <= data_in;
        query_wr_en <= 1;
        query_addr <= query_addr + 1;
      end
      else if (query_or_ref == 1)
      begin
        ref_in <= data_in;
        ref_wr_en <= 1;
        ref_addr <= ref_addr + 1;
      end
    end
    else 
    begin
      query_wr_en <= 0;
      ref_wr_en <= 0;
    end
  end
  

  always @ (posedge clk)
  begin
    if (reset == 1)
    begin
      running <= 0;
    end
    else
    begin
      if (set_running == 1)
	  begin
        running <= 1;
		irq <= 0;
	  end
      else if (clear_running == 1)
	  begin
        running <= 0;
	  end
    end
  end
  
  
  always @ (posedge clk)
  begin
    if (reset == 1)
    begin
      sop_seen <= 0;
    end
    else
    begin
      if (set_sop_seen == 1)
        sop_seen <= 1;
      else if (clear_sop_seen == 1)  // can't support packets that start and end on a single beat
        sop_seen <= 0;
    end
  end
  
// Avalon-ST is network ordered (usually) so putting most significant symbol in lowest bits
genvar i;
generate
  for (i = 0; i < NUM_OF_SYMBOLS; i = i + 1)
  begin : byte_reversal
    assign data_in[((8*(i+1))-1):(8*i)] = snk_data[((8*((NUM_OF_SYMBOLS-1-i)+1))-1):(8*(NUM_OF_SYMBOLS-1-i))];
  end
endgenerate
  
  assign set_running = (csr_address == 2'b10) & (csr_write == 1) & (csr_byteenable[0] == 1) & (csr_writedata[31] == 1);
  assign clear_running = 0;  
  
  assign set_sop_seen = (snk_ready == 1) & (snk_valid == 1) & (snk_sop == 1);
  assign clear_sop_seen = (snk_ready == 1) & (snk_valid == 1) & (snk_eop == 1);
  assign packet_filter = (control[5] == 0) |  // let any traffic through
                         (control[5] == 1) & (sop_seen == 1) | (set_sop_seen == 1);  // need to use set_sop_seen since it sets before sop_seen is set so we don't want to filter out the SOP beat
                         
  assign valid_data = (packet_filter == 1) & (snk_valid == 1) & (snk_ready == 1);
  assign snk_ready = (running == 1);  // checker is always ready when enabled
  
  
  assign set_params = (csr_address == 2'b10) & (csr_write == 1) & (csr_byteenable[0] == 1) & (csr_writedata[0] == 1);
  assign set_addr_len = (csr_address == 2'b10) & (csr_write == 1) & (csr_byteenable[0] == 1) & (csr_writedata[1] == 1);
  assign query_or_ref = control[2];
  assign start = (csr_address == 2'b10) & (csr_write == 1) & (csr_byteenable[0] == 1) & (csr_writedata[3] == 1);
  assign clear_done = (csr_address == 2'b10) & (csr_write == 1) & (csr_byteenable[0] == 1) & (csr_writedata[4] == 1);
  
  
GACTTop # (
    .PE_WIDTH(PE_WIDTH),
    .BLOCK_WIDTH(BLOCK_WIDTH),
    .MAX_TILE_SIZE(MAX_TILE_SIZE),
    .NUM_PE(64),
    .DIR_BRAM_ADDR_WIDTH(DIR_BRAM_ADDR_WIDTH),
	.NUM_DIR_BLOCK(NUM_DIR_BLOCK)
  ) dut (
    .clk(clk),
    .rst(reset),
    .align_fields (reg_align_fields),

    .in_params (in_params),
    .max_tb_steps (max_tb_steps),
    .query_addr_in (query_addr),
    .query_in (query_in),
    .query_len (reg_query_len),
    .query_wr_en (query_wr_en),
    .ref_addr_in (ref_addr),
    .ref_in (ref_in),
    .ref_len (reg_ref_len),
    .ref_wr_en (ref_wr_en),
    .score_threshold (score_threshold),
	
    .set_params (set_params),
    .start (start),
    .clear_done (clear_done),
	
    .done (done),
    .ready (ready),

    .query_max_pos (query_max_pos),
    .ref_max_pos (ref_max_pos),
	.num_ref_bases(num_ref_bases),
	.num_query_bases(num_query_bases),
	.num_tb_steps(num_tb_steps),
    .tile_score (max_tile_score)
  );
  
endmodule
