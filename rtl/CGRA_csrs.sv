//--------------------------------------------------
//	CGRA architecture wrapper from verilog file
//--------------------------------------------------

// PyMTL BitStruct CGRAConfig_6_4_6_8__764c37c5066f1efc Definition


/*
typedef struct packed {
  logic [5:0] ctrl;
  logic [0:0] predicate;
  logic [3:0][2:0] fu_in;
  logic [7:0][2:0] outport;
  logic [5:0][0:0] predicate_in;
} CGRAConfig;
*/
/* verilator lint_off UNUSED */
/* verilator lint_off WIDTH */
module CGRA_csrs#(
  parameter int unsigned CGRADim      = 16,
  parameter int unsigned KernelSize   = 4,
  parameter int unsigned RegCount     = KernelSize,
  parameter int unsigned RegDataWidth = 64,
  parameter int unsigned RegAddrWidth = $clog2(RegCount)
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
  output logic [1:0]              csr_tile_addr [0:CGRADim-1],
  output CGRAConfig_6_4_6_8__764c37c5066f1efc csr_tile_data [0:CGRADim-1],
  output logic                    csr_tile_wr_en [0:CGRADim-1],
  output logic                   csr_tile_wr_valid [0:CGRADim-1],
  input  logic                     csr_tile_ready [0:CGRADim-1]
 
);

  CGRAConfig_6_4_6_8__764c37c5066f1efc csr_reg_set [RegCount];
  CGRAConfig_6_4_6_8__764c37c5066f1efc zero_const = 0;
  
  logic req_success;
  logic tile_wr_en;
  logic [$clog2(RegCount)-1:0] addr;
  assign csr_req_ready_o = 1'b1;
  assign req_success = csr_req_valid_i && csr_req_ready_o;
  
  logic [RegAddrWidth-1:0] csr_addr_i_buffer;
  logic tile_upload;
  logic [3:0] tile_number;


  //-------------------------------
  // Updating CSR registers
  //
  //-------------------------------
  always_ff @ (posedge clk_i or negedge rst_ni) begin
    if(!rst_ni) begin
      for( int i = 0; i < RegCount; i++) begin
        csr_reg_set[i] <= zero_const;
        csr_addr_i_buffer <= 0;
        tile_upload <= 0;
        tile_number <= 0;
      end
    end else begin
      if(req_success && csr_wr_en_i) begin
        tile_number <= csr_wr_data_i[52:49];
        csr_reg_set[csr_addr_i].ctrl <= csr_wr_data_i[48:43];
        csr_reg_set[csr_addr_i].predicate <= csr_wr_data_i[42];
        csr_reg_set[csr_addr_i].fu_in <= csr_wr_data_i[41:30];
        csr_reg_set[csr_addr_i].outport <= csr_wr_data_i[29:6];
        csr_reg_set[csr_addr_i].predicate_in <= csr_wr_data_i[5:0];
        csr_addr_i_buffer <= csr_addr_i;
        tile_upload <= 1;
      end else begin
        csr_reg_set[csr_addr_i] <= csr_reg_set[csr_addr_i];
        tile_upload <= 0;
      end
    end
  end
  
  
  logic rsp_success = csr_rsp_valid_o && csr_rsp_ready_i;

  always_ff @ (posedge clk_i or negedge rst_ni) begin
    if(!rst_ni) begin
      csr_rd_data_o   <= {RegDataWidth{1'b0}};
      csr_rsp_valid_o <= 1'b0;
    end else begin
      if(req_success) begin
        csr_rd_data_o   <= csr_reg_set[csr_addr_i];
        csr_rsp_valid_o <= 1'b1;
      end else if (rsp_success) begin
        csr_rd_data_o   <= {RegDataWidth{1'b0}};
        csr_rsp_valid_o <= 1'b0;
      end else begin
        csr_rd_data_o   <= csr_rd_data_o;
        csr_rsp_valid_o <= csr_rsp_valid_o;
      end
    end
  end

 
 assign tile_wr_en = tile_upload & csr_tile_ready[tile_number];

 always_ff @ (posedge clk_i or negedge rst_ni) begin
    if(!rst_ni) begin
        addr <= 0;
      for( int i = 0; i < CGRADim; i++) begin
        csr_tile_data[i] <= zero_const;
        csr_tile_wr_en[i] <= 0;
        csr_tile_wr_valid[i] <= 0;

        csr_tile_addr[i] <= 0;
      end
    end else begin
      if(tile_wr_en) begin
        addr <= (addr + 1'd1) % KernelSize;
        csr_tile_addr[tile_number-1] <= addr;
        csr_tile_data[tile_number-1] <= csr_reg_set[csr_addr_i_buffer];
        csr_tile_wr_en[tile_number-1] <= 1;
        csr_tile_wr_valid[tile_number-1] <= 1;
        $write("*-* All Finished *-*\n");
        $finish;
      end else begin
        csr_tile_data[tile_number-1] <= csr_tile_data[tile_number-1];
        addr <= addr;
      end
    end
  end
/* verilator lint_on WIDTH */

endmodule
