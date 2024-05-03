//--------------------------------------------------
//	CGRA architecture wrapper from verilog file
//--------------------------------------------------

// PyMTL BitStruct CGRAConfig_6_4_6_8__764c37c5066f1efc Definition
/* verilator lint_off UNDRIVEN */
/* verilator lint_off UNUSED */
typedef struct packed {
  logic [5:0] ctrl;
  logic [0:0] predicate;
  logic [3:0][2:0] fu_in;
  logic [7:0][2:0] outport;
  logic [5:0][0:0] predicate_in;
} CGRAConfig_6_4_6_8__764c37c5066f1efc;

// PyMTL BitStruct CGRAData_16_1_1__payload_16__predicate_1__bypass_1 Definition
typedef struct packed {
  logic [15:0] payload;
  logic [0:0] predicate;
  logic [0:0] bypass;
} CGRAData_16_1_1__payload_16__predicate_1__bypass_1;

// PyMTL BitStruct CGRAData_1_1__payload_1__predicate_1 Definition
typedef struct packed {
  logic [0:0] payload;
  logic [0:0] predicate;
} CGRAData_1_1__payload_1__predicate_1;

module CGRA_wrapper#(
	parameter int unsigned NarrowDataWidth = 64,
	parameter int unsigned WideDataWidth     = 512,
  	parameter int unsigned TCDMDepth = 64,
  	parameter int unsigned TCDMReqPorts = 12,
  	parameter int unsigned NrBanks = 32,
  	parameter int unsigned TCDMSize = NrBanks * TCDMDepth * (NarrowDataWidth/8),
  	parameter int unsigned TCDMAddrWidth = $clog2(TCDMSize),
	parameter int unsigned kernelSize = 4,
	parameter int unsigned CSR_RegAddrWidth = $clog2(kernelSize),
	parameter int unsigned CGRADim      = 16,
    parameter int unsigned KernelSize   = 4,
    parameter int unsigned RegCount     = kernelSize,
    parameter int unsigned RegDataWidth = 64,
    parameter int unsigned RegAddrWidth = $clog2(RegCount)
)(



	//--------------------------------------------------------------------
	
	input  logic                     clk_i,
    input  logic                     rst_ni,
    input  logic [RegAddrWidth-1:0] csr_addr_i,
    input  logic [RegDataWidth-1:0] csr_wr_data_i,
    input  logic                     csr_wr_en_i,
    input  logic                     csr_req_valid_i,
    output logic                    csr_req_ready_o,
    output logic [RegDataWidth-1:0] csr_rd_data_o,
    output logic                    csr_rsp_valid_o,
    input  logic                    csr_rsp_ready_i,

	//Data transfer
	//Assuming that the CGRA can output just 1 data at a time
	//It can be changed by connecting each tile to the output
	
	//write to memory
  	//-------------------------------------------------------------
	output logic data_mem_recv_waddr_en [0:3],
	// size of waddr = clog2(Population Data Size) In this case I had mem size = 100, 7 bits.
	output logic [6:0] data_mem_recv_waddr_msg [0:3],
	input logic data_mem_recv_waddr_rdy [0:3],
	output logic data_mem_recv_wdata_en [0:3],
	output logic data_mem_recv_wdata_msg_predicate [0:3],
	output logic [15:0] data_mem_recv_wdata_msg_payload [0:3],
	output logic data_mem_recv_wdata_msg_bypass [0:3],
	input logic data_mem_recv_wdata_rdy [0:3],
	//-------------------------------------------------------------
	
	//Reading from memory
  	//------------------------------------------
  	output logic data_mem_recv_raddr_en [0:3],
  	output logic [6:0] data_mem_recv_raddr_msg [0:3],
  	input logic data_mem_recv_raddr_rdy [0:3],
  	input logic data_mem_send_rdata_en [0:3],
  	input logic data_mem_send_rdata_msg_predicate [0:3],
  	input logic [15:0] data_mem_send_rdata_msg_payload [0:3],
  	input logic data_mem_send_rdata_msg_bypass [0:3],
  	output logic data_mem_send_rdata_rdy [0:3]
  	//------------------------------------------
);

initial begin
      if ($test$plusargs("trace") != 0) begin
         $display("[%0t] Tracing to logs/vlt_dump.vcd...\n", $time);
         $dumpfile("logs/vlt_dump.vcd");
         $dumpvars();
      end
      $display("[%0t] Model running...\n", $time);
   end
  
CGRAConfig_6_4_6_8__764c37c5066f1efc recv_wopt_internal [0:15];
CGRAData_16_1_1__payload_16__predicate_1__bypass_1 data_mem_recv_wdata_msg_internal [0:3];
CGRAData_16_1_1__payload_16__predicate_1__bypass_1 data_mem_send_rdata_msg_internal [0:3];
 
 
logic [1:0] csr_tile_addr [0:15];
CGRAConfig_6_4_6_8__764c37c5066f1efc csr_tile_data [0:15];
logic  csr_tile_wr_en [0:15];
logic  csr_tile_wr_valid [0:15];
logic recv_tile_rdy [0:15];

logic recv_wadr_rdy_o [0:15];
logic recv_wopt_rdy_o [0:15];
CGRA_csrs#(
  .CGRADim      (16),
  .KernelSize   (4),
  .RegDataWidth (64)
) csrs (
  .clk_i             (clk_i),
  .rst_ni            (rst_ni),
  .csr_addr_i        (csr_addr_i),
  .csr_wr_data_i     (csr_wr_data_i),
  .csr_wr_en_i       (csr_wr_en_i),
  .csr_req_valid_i   (csr_req_valid_i),
  .csr_req_ready_o   (csr_req_ready_o),
  .csr_rd_data_o     (csr_rd_data_o),
  .csr_rsp_valid_o   (csr_rsp_valid_o),
  .csr_rsp_ready_i   (csr_rsp_ready_i),
  // Fix this to 2 bits only
  // Let's do 4 ALU operations for simplicity
  .csr_tile_addr     (csr_tile_addr),
  .csr_tile_data     (csr_tile_data),
  .csr_tile_wr_en    (csr_tile_wr_en),
  .csr_tile_wr_valid (csr_tile_wr_valid),
  .csr_tile_ready    (recv_tile_rdy)
);



CGRARTL__e95cacd33b23104e CGRARtl(
    .clk(clk_i),
    .reset(rst_ni),

    // CSR operations
    //-------------------------------------------------------------
    .recv_waddr__en	    (csr_tile_wr_en),
    .recv_waddr__msg	(csr_tile_addr),
    .recv_waddr__rdy	(recv_wadr_rdy_o),
    .recv_wopt__en		(csr_tile_wr_valid),
    .recv_wopt__msg	(csr_tile_data),
    .recv_wopt__rdy	(recv_wopt_rdy_o),
    //-------------------------------------------------------------


    //memory data transfer
    //write to memory
    //-------------------------------------------------------------
    .data_mem__recv_waddr__en1	(data_mem_recv_waddr_en),
    .data_mem__recv_waddr__msg1	(data_mem_recv_waddr_msg),
    .data_mem__recv_waddr__rdy1	(data_mem_recv_waddr_rdy),
    .data_mem__recv_wdata__en1	(data_mem_recv_wdata_en),
    .data_mem__recv_wdata__msg1	(data_mem_recv_wdata_msg_internal),
    .data_mem__recv_wdata__rdy1	(data_mem_recv_wdata_rdy),
    //-------------------------------------------------------------

    //Reading from memory
    //-------------------------------------------------------------
    .data_mem__recv_raddr__en1	(data_mem_recv_raddr_en),
    .data_mem__recv_raddr__msg1	(data_mem_recv_raddr_msg),
    .data_mem__recv_raddr__rdy1	(data_mem_recv_raddr_rdy),
    .data_mem__send_rdata__en1	(data_mem_send_rdata_en),
    .data_mem__send_rdata__msg1	(data_mem_send_rdata_msg_internal),
    .data_mem__send_rdata__rdy1	(data_mem_send_rdata_rdy)
    //-------------------------------------------------------------
);

genvar i;

generate
	for( i = 0; i < 16; i++) begin:	for_loop_assignment_wopt
	    assign recv_tile_rdy [i] = recv_wopt_rdy_o[i] & recv_wadr_rdy_o[i];
		//assign recv_wopt_internal[i].ctrl = recv_wopt_ctrl[i];
		//assign recv_wopt_internal[i].predicate = recv_wopt_predicate[i];
		//assign recv_wopt_internal[i].fu_in = recv_wopt_fu_in[i];
		//assign recv_wopt_internal[i].outport = recv_wopt_outport[i];
		//assign recv_wopt_internal[i].predicate_in = recv_wopt_predicate_in[i];
	end
endgenerate
/*
generate
	for( i = 0; i < 4; i++) begin:	for_loop_assignment_send_rdata
		assign data_mem_send_rdata_msg_internal[i].predicate = data_mem_send_rdata_msg_predicate[i];
		assign data_mem_send_rdata_msg_internal[i].payload = data_mem_send_rdata_msg_payload[i];
		assign data_mem_send_rdata_msg_internal[i].bypass = data_mem_send_rdata_msg_bypass[i];
	end
endgenerate

generate
	for( i = 0; i < 4; i++) begin:	for_loop_assignment_recv_wdata
		assign data_mem_recv_wdata_msg_internal[i].predicate = data_mem_recv_wdata_msg_predicate[i];
		assign data_mem_recv_wdata_msg_internal[i].payload = data_mem_recv_wdata_msg_payload[i];
		assign data_mem_recv_wdata_msg_internal[i].bypass = data_mem_recv_wdata_msg_bypass[i];
	end
endgenerate
*/
endmodule
