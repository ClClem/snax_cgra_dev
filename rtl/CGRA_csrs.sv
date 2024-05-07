//--------------------------------------------------
//	CGRA architecture wrapper from verilog file
//--------------------------------------------------

/* verilator lint_off UNUSED */
/* verilator lint_off WIDTH */
module CGRA_csrs#(
  parameter int unsigned CGRADim      = 16,
  parameter int unsigned KernelSize   = 4,
  parameter int unsigned RegCount     = CGRADim,
  parameter int unsigned RegDataWidth = 64,
  parameter int unsigned RegAddrWidth = $clog2(RegCount) + 1 //Needed for the Start command
)(
  input  logic                     clk_i,
  input  logic                     rst_ni,
  input  logic [RegAddrWidth-1:0] csr_addr_i,
  input  logic [RegDataWidth-1:0] csr_wr_data_i,
  input  logic                    csr_wr_en_i,
  input  logic                     csr_req_valid_i,
  output logic                    csr_req_ready_o,
  output logic [RegDataWidth-1:0] csr_rd_data_o,
  output logic                    csr_rsp_valid_o,
  input  logic                    csr_rsp_ready_i,
  // Fix this to 2 bits only
  // Let's do 4 ALU operations for simplicity
  output logic [$clog2(KernelSize)-1:0]       csr_tile_addr     [0:CGRADim-1],
  output CGRAConfig_6_4_6_8__764c37c5066f1efc csr_tile_data     [0:CGRADim-1],
  output logic                    	      csr_tile_wr_en    [0:CGRADim-1],
  output logic                                csr_tile_wr_valid [0:CGRADim-1],
  input  logic                                csr_tile_ready    [0:CGRADim-1]
 
);

  CGRAConfig_6_4_6_8__764c37c5066f1efc csr_reg_set [RegCount][KernelSize];
  CGRAConfig_6_4_6_8__764c37c5066f1efc zero_const = 0;
  logic [RegDataWidth-1:0] input_buffer;
  logic req_success;

  assign csr_req_ready_o = 1;
  assign req_success = csr_req_valid_i && csr_req_ready_o;
  

  logic [RegCount-1:0][$clog2(KernelSize)-1:0] csr_addr_j;
  logic reg_start;

  //-------------------------------
  // Updating CSR registers
  //-------------------------------
  always_ff @ (posedge clk_i or negedge rst_ni) begin
    if(!rst_ni) begin
        reg_start <= 0;
        input_buffer <= 0;
        for( int i = 0; i < RegCount; i++) begin
      	    for( int j = 0; j < KernelSize; j++) begin
        	    csr_reg_set[i][j] <= zero_const;
            end
	        for( int j = 0; j < $clog2(KernelSize); j++) begin
		        csr_addr_j[i][j] <= 0;	
	        end
      end
    end else begin
	if(csr_addr_i == CGRADim + 1) begin
		reg_start <= csr_wr_data_i[0];
	end else begin
        if(req_success && csr_wr_en_i) begin
		csr_reg_set[csr_addr_i][csr_addr_j[csr_addr_i]].ctrl <= csr_wr_data_i[48:43];
		csr_reg_set[csr_addr_i][csr_addr_j[csr_addr_i]].predicate <= csr_wr_data_i[42];
		csr_reg_set[csr_addr_i][csr_addr_j[csr_addr_i]].fu_in <= csr_wr_data_i[41:30];
		csr_reg_set[csr_addr_i][csr_addr_j[csr_addr_i]].outport <= csr_wr_data_i[29:6];
		csr_reg_set[csr_addr_i][csr_addr_j[csr_addr_i]].predicate_in <= csr_wr_data_i[5:0];
		csr_addr_j[csr_addr_i] <= csr_addr_j[csr_addr_i] + 1;
                input_buffer <= csr_wr_data_i;
	    end else begin
		csr_reg_set[csr_addr_i] <= csr_reg_set[csr_addr_i];
		csr_addr_j[csr_addr_i] <= csr_addr_j[csr_addr_i];

	    end
	  end
    end
  end
  
  
  logic rsp_success;
  assign rsp_success = csr_rsp_valid_o && csr_rsp_ready_i;

  always_ff @ (posedge clk_i or negedge rst_ni) begin
    if(!rst_ni) begin
      csr_rd_data_o   <= {RegDataWidth{1'b0}};
      csr_rsp_valid_o <= 1'b0;
    end else begin
      if(req_success) begin
        //assignment not possible from package to arr.
        //csr_rd_data_o   <= csr_reg_set[csr_addr_i][csr_addr_j[csr_addr_i]];
        csr_rd_data_o   <= input_buffer;
        csr_rsp_valid_o <= 1;
      end else if (rsp_success) begin
        csr_rd_data_o   <= {RegDataWidth{1'b0}};
        csr_rsp_valid_o <= 1'b0;
      end else begin
        csr_rd_data_o   <= csr_rd_data_o;
        csr_rsp_valid_o <= csr_rsp_valid_o;
      end
    end
  end

 bit cgra_loaded;
 int tile_num = 0;
 logic [$clog2(KernelSize)-1:0]cycle_i;
 
 always_ff @ (posedge clk_i or negedge rst_ni) begin
    if(!rst_ni) begin
        cgra_loaded <= 0;
        cycle_i <= 0;
      for( int i = 0; i < CGRADim; i++) begin
        csr_tile_data[i] <= zero_const;
        csr_tile_wr_en[i] <= 0;
        csr_tile_wr_valid[i] <= 0;
        csr_tile_addr[i] <= 0;
      end
    end else begin
      if(reg_start) begin
                for( tile_num = 0; tile_num < CGRADim; tile_num++) begin
                        csr_tile_addr[tile_num] <= cycle_i;
                        csr_tile_wr_en[tile_num] <= 1;
                        csr_tile_wr_valid[tile_num] <= 1;
                        csr_tile_data[tile_num] <= csr_reg_set[tile_num][cycle_i];
                end
        cycle_i++;
        if(cycle_i == 3) begin
            cgra_loaded <= 1;
            reg_start <= 0;
        end else begin
            reg_start <= 1;
            cgra_loaded <= 0;
        end
      end else begin
        for( tile_num = 0; tile_num < CGRADim; tile_num++) begin
            csr_tile_addr[tile_num] <= 0;
            csr_tile_wr_en[tile_num] <= 0;
            csr_tile_wr_valid[tile_num] <= 0;
            csr_tile_data[tile_num] <= 0;
        end
      end
    end
  end
/* verilator lint_on WIDTH */
endmodule
