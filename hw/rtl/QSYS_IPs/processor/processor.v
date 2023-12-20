module processor (
    clk,
    reset,

    csr_address,
    csr_writedata,
    csr_write,
    csr_readdata,
    csr_read,
    csr_byteenable,
  
    irq,
  
    q_data,
    q_valid,
    q_ready,
    q_empty,
    q_sop,
    q_eop,
  
    r_data,
    r_valid,
    r_ready,
    r_empty,
    r_sop,
    r_eop,
  
    src_data,
    src_valid,
    src_ready,
    src_empty,
    src_sop,
    src_eop
    );
    
    parameter DATA_WIDTH = 512;           // must be an even multiple of 8 and is used to determine the width of the 2nd port of the on-chip RAM and streaming port
    //parameter MAX_RESULT_LENGTH = 64;    // used to determine the depth of the on-chip RAM and modulo counter width, set to a multiple of 2
    //parameter ADDRESS_WIDTH = 6;          // log2(MAX_RESULT_LENGTH) will be set by the .tcl file
    parameter EMPTY_WIDTH = 6;            // log2(DATA_WIDTH/8) set by the .tcl file
  
    localparam NUM_OF_SYMBOLS = DATA_WIDTH / 8;
    localparam BRAM_ADDR_WIDTH = 16;
    localparam NUM_DIR_BLOCK = 32;
    localparam PE_WIDTH = 16;
    localparam BLOCK_WIDTH = 6;

    input clk;
    input reset;

    input [1:0] csr_address;
    input [31:0] csr_writedata;
    input csr_write;
    output reg [31:0] csr_readdata;
    input csr_read;
    input [3:0] csr_byteenable;
  
    output reg irq;

    input [DATA_WIDTH-1:0] q_data;
    input q_valid;
    output wire q_ready;
    input [EMPTY_WIDTH-1:0] q_empty;
    input q_sop;
    input q_eop;
  
    input [DATA_WIDTH-1:0] r_data;
    input r_valid;
    output wire r_ready;
    input [EMPTY_WIDTH-1:0] r_empty;
    input r_sop;
    input r_eop;
  
    output wire [DATA_WIDTH-1:0] src_data;
    output wire src_valid;
    input src_ready;
    output wire [EMPTY_WIDTH-1:0] src_empty;
    output wire src_sop;
    output wire src_eop;
  
    reg running;
    wire set_running;
    wire clear_running;

    wire case_data_valid;
    wire ctrl_data_valid;
    wire [DATA_WIDTH-1:0] case_data;
    wire [DATA_WIDTH-1:0] ctrl_data;
    
    wire [BRAM_ADDR_WIDTH-1:0] case_wr_addr_in;
    wire [BRAM_ADDR_WIDTH-1:0] ctrl_wr_addr_in;
  
    reg case_wr_en;
    reg ctrl_wr_en;
    reg [DATA_WIDTH-1:0] case_in;
    reg [DATA_WIDTH-1:0] ctrl_in;
    reg [BRAM_ADDR_WIDTH-1:0] case_wr_addr;
    reg [BRAM_ADDR_WIDTH-1:0] ctrl_wr_addr;
  
    reg [PE_WIDTH-1:0] reg_case_length;
    reg [PE_WIDTH-1:0] reg_ctrl_length;
    reg [PE_WIDTH-1:0] reg_snp_num;
    reg [PE_WIDTH-1:0] reg_threshold;
    reg [2*PE_WIDTH-1:0] reg_n;
  
    reg [31:0] control;
  
    wire start;
    wire clear_done;
    wire done;
    wire ready;
	 wire table_done;
  
    wire [PE_WIDTH-1:0] snp_pair_num;
    wire [2*PE_WIDTH-1:0] snp_pair;
    reg snp_pair_rd_en;

    // get param and control
    always @ (posedge clk) begin
        if (reset == 1) begin
            reg_case_length <= 0;
            reg_ctrl_length <= 0;
            reg_n <= 0;
            reg_snp_num <= 0;
            reg_threshold <= 0;
        end
        else if (csr_write) begin
            case (csr_address)
            2'b00: begin
	            reg_case_length <= csr_writedata[15:0];
		        reg_ctrl_length <= csr_writedata[31:16];
	       end
	       2'b01: begin
	           reg_n <= csr_writedata;
	       end
	       2'b10: begin
	           reg_snp_num <= csr_writedata[15:0];
	           reg_threshold <= csr_writedata[31:16];
	       end
		   2'b11: begin
		      control <= csr_writedata;
		   end
	       endcase
        end
    end
  
  //read result or status
    always @ (posedge clk) begin
        if (reset == 1) begin
            csr_readdata <= 32'h00000000;
        end
        else if (csr_read == 1) begin
            case (csr_address)
            2'b00:   csr_readdata <= {16'h0000,snp_pair_num};   
            2'b01:   csr_readdata <= snp_pair; 
            //2'b10:   csr_readdata <= (do_traceback == 1) ? {12'h000, num_tb_steps} : {split_col, start_point};  
            2'b11:   csr_readdata <= {28'h0000000, table_done, ready, done, running};
            default: csr_readdata <= {28'h0000000, table_done, ready, done, running};
            endcase
        end
    end
    
    always @ (posedge clk) begin
        if (reset) begin
            snp_pair_rd_en <= 0;
        end
        else begin
            if (csr_read == 1 && csr_address == 2'b01) begin
                snp_pair_rd_en <= 1;
            end
            else begin
                snp_pair_rd_en <= 0;
            end
        end
    end

    //send data to BoostTop
    always @ (posedge clk) begin
        if (reset == 1) begin
            case_wr_en <= 0;
            ctrl_wr_en <= 0;
            case_wr_addr <= 0;
            ctrl_wr_addr <= 0;
        end
        else begin
            if (case_data_valid == 1) begin
	            case_in <= case_data;
                case_wr_en <= 1;
                case_wr_addr <= case_wr_addr + 1;
	            ctrl_wr_en <= 0;
            end
	        else if (ctrl_data_valid == 1) begin
                ctrl_in <= ctrl_data;
                ctrl_wr_en <= 1;
                ctrl_wr_addr <= ctrl_wr_addr + 1;
	            case_wr_en <= 0;
            end
	        else begin
	            case_wr_en <= 0;
                ctrl_wr_en <= 0;
	        end
        end
    end
    
    //status control
    always @ (posedge clk) begin
        if (reset == 1) begin
            running <= 0;
        end
        else begin
            if (set_running == 1) begin
                running <= 1;
	        end
            else if (clear_running == 1) begin
                running <= 0;
	        end
        end
    end
  
   // Avalon-ST is network ordered (usually) so putting most significant symbol in lowest bits
    genvar i;
    generate
        for (i = 0; i < NUM_OF_SYMBOLS; i = i + 1) 
        begin : q_byte_reversal
            assign case_data[((8*(i+1))-1):(8*i)] = q_data[((8*((NUM_OF_SYMBOLS-1-i)+1))-1):(8*(NUM_OF_SYMBOLS-1-i))];
        end
    endgenerate
  
    genvar j;
    generate
        for (j = 0; j < NUM_OF_SYMBOLS; j = j + 1)
        begin : r_byte_reversal
            assign ctrl_data[((8*(j+1))-1):(8*j)] = r_data[((8*((NUM_OF_SYMBOLS-1-j)+1))-1):(8*(NUM_OF_SYMBOLS-1-j))];
        end
    endgenerate
                           				 
    assign case_data_valid = (q_valid == 1) & (q_ready == 1);
    assign ctrl_data_valid = (r_valid == 1) & (r_ready == 1);
  
    assign q_ready = (running == 1);
    assign r_ready = (running == 1);
  
    assign start =         (csr_address == 2'b11) & (csr_write == 1) & (csr_byteenable[0] == 1) & (csr_writedata[0] == 1);
    assign clear_done =    (csr_address == 2'b11) & (csr_write == 1) & (csr_byteenable[0] == 1) & (csr_writedata[1] == 1);
    assign clear_running = (csr_address == 2'b11) & (csr_write == 1) & (csr_byteenable[0] == 1) & (csr_writedata[30] == 1);
    assign set_running =   (csr_address == 2'b11) & (csr_write == 1) & (csr_byteenable[0] == 1) & (csr_writedata[31] == 1);
  
    assign src_valid = 1'b0;
    assign src_data = 0;
    assign src_sop = 1'b0;
    assign src_eop = 1'b0;
    assign src_empty = 0;
    
    assign case_wr_addr_in = (case_wr_addr > 0) ? case_wr_addr -1 : 0;
    assign ctrl_wr_addr_in = (ctrl_wr_addr > 0) ? ctrl_wr_addr -1 : 0;
    
    BoostTop # (
        .DATA_WIDTH (64),
        .BLOCK_WIDTH (BLOCK_WIDTH),
        .PE_WIDTH (PE_WIDTH),
        .BRAM_ADDR_WIDTH (BRAM_ADDR_WIDTH),
        .PE_NUM (4)
    ) dut (
        .clk (clk),
        .rst (reset),
        .start (start),
        .clear_done (clear_done),
        
        .case_in (case_in),
        .ctrl_in (ctrl_in),
        .case_wr_addr (case_wr_addr_in),
        .ctrl_wr_addr (ctrl_wr_addr_in),
        .case_wr_en (case_wr_en),
        .ctrl_wr_en (ctrl_wr_en),
        
        .snp_num_in (reg_snp_num),
        .n_in (reg_n),
        .threshold_in (reg_threshold),
        .case_length_in (reg_case_length[BLOCK_WIDTH-1:0]),
        .ctrl_length_in (reg_ctrl_length[BLOCK_WIDTH-1:0]),
        
        .snp_pair_rd_en (snp_pair_rd_en),
        .snp_pair_out (snp_pair),
        .snp_pair_num (snp_pair_num),
        
		  .table_done (table_done),
        .ready (ready),
        .done (done)
    );
    
    /*JDTop # (
        .DATA_WIDTH (64),
        .BLOCK_WIDTH (BLOCK_WIDTH),
        .PE_WIDTH (PE_WIDTH),
        .BRAM_ADDR_WIDTH (BRAM_ADDR_WIDTH),
        .PE_NUM (4)
    ) dut (
        .clk (clk),
        .rst (reset),
        .start (start),
        .clear_done (clear_done),
        
        .case_in (case_in),
        .ctrl_in (ctrl_in),
        .case_wr_addr (case_wr_addr_in),
        .ctrl_wr_addr (ctrl_wr_addr_in),
        .case_wr_en (case_wr_en),
        .ctrl_wr_en (ctrl_wr_en),
        
        .snp_num_in (reg_snp_num),
        .case_length_in (reg_case_length),
        .ctrl_length_in (reg_ctrl_length),
        
        .ready (ready),
        .done (done)
    );*/
endmodule
