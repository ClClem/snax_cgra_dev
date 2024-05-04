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
  	parameter int unsigned TCDMReqPorts = 4,    //equal #tiles that can access memory
  	parameter int unsigned NrBanks = 32,
  	parameter int unsigned TCDMSize = NrBanks * TCDMDepth * (NarrowDataWidth/8),
  	parameter int unsigned TCDMAddrWidth = $clog2(TCDMSize),

	parameter int unsigned CGRADim      = 16,
	parameter int unsigned KernelSize   = 4,
	parameter int unsigned RegCount     = CGRADim,
	parameter int unsigned RegDataWidth = 64,
	parameter int unsigned RegAddrWidth = $clog2(RegCount) + 1
)(



	//--------------------------------------------------------------------
	
	input  logic                    clk_i,
	input  logic                    rst_ni,
    input  logic [RegAddrWidth-1:0] csr_addr_i,
    input  logic [RegDataWidth-1:0] csr_wr_data_i,
    input  logic                    csr_wr_en_i,
    input  logic                    csr_req_valid_i,
    output logic                    csr_req_ready_o,
    output logic [RegDataWidth-1:0] csr_rd_data_o,
    output logic                    csr_rsp_valid_o,
    input  logic                    csr_rsp_ready_i,

	//Data transfer
	//Assuming that the CGRA can output just 1 data at a time
	//It can be changed by connecting each tile to the output
    
    //-----------------------------
  	// Narrow TCDM ports
	//-----------------------------

	output  logic [TCDMReqPorts-1:0]                      tcdm_req_write,
	output  logic [TCDMReqPorts-1:0][TCDMAddrWidth-1:0]   tcdm_req_addr,
	output  logic [TCDMReqPorts-1:0][WideDataWidth-1:0]   tcdm_req_data,
    output  logic [TCDMReqPorts-1:0]                      tcdm_req_amo,
	output  logic [TCDMReqPorts-1:0][WideDataWidth/8-1:0] tcdm_req_strb,
	output  logic [TCDMReqPorts-1:0]                      tcdm_req_user_core_id_i,
	output  logic [TCDMReqPorts-1:0]                      tcdm_req_user_is_core_i,
	output  logic [TCDMReqPorts-1:0]                      tcdm_req_q_valid,
	
	input logic [TCDMReqPorts-1:0]                      tcdm_rsp_q_ready,
    input logic [TCDMReqPorts-1:0]                      tcdm_rsp_p_valid,
	input logic [TCDMReqPorts-1:0][  WideDataWidth-1:0] tcdm_rsp_data
);

CGRAData_16_1_1__payload_16__predicate_1__bypass_1 data_mem_recv_wdata_msg_internal [0:3];
CGRAData_16_1_1__payload_16__predicate_1__bypass_1 data_mem_send_rdata_msg_internal [0:3];

 //write to memory
  	//-------------------------------------------------------------
	 logic data_mem_recv_waddr_en [0:3];
	// size of waddr = clog2(Population Data Size) In this case I had mem size = 100, 7 bits.
	 logic [TCDMAddrWidth-1:0] data_mem_recv_waddr_msg [0:3];
	 logic data_mem_recv_waddr_rdy [0:3];
	 logic data_mem_recv_wdata_en [0:3];
	 logic data_mem_recv_wdata_rdy [0:3];
	//-------------------------------------------------------------
	
	//Reading from memory
  	//------------------------------------------
  	 logic data_mem_recv_raddr_en [0:3];
  	 logic [TCDMAddrWidth-1:0] data_mem_recv_raddr_msg [0:3];
  	 logic data_mem_recv_raddr_rdy [0:3];
  	 logic data_mem_send_rdata_en [0:3];
  	 logic data_mem_send_rdata_rdy [0:3];
  	//------------------------------------------
 
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


//chaning mem address to TCDMaddressWidth
CGRARTL__e95cacd33b23104e#(
.TCDMAddrWidth(TCDMAddrWidth)
) CGRARtl (
    .clk(clk_i),
    .reset(rst_ni),

    // CSR operations
    //-------------------------------------------------------------
    .recv_waddr__en	    (csr_tile_wr_en),
    .recv_waddr__msg	(csr_tile_addr),
    .recv_waddr__rdy	(recv_wadr_rdy_o),
    .recv_wopt__en		(csr_tile_wr_valid),
    .recv_wopt__msg	    (csr_tile_data),
    .recv_wopt__rdy	    (recv_wopt_rdy_o),
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
	for( i = 0; i < 16; i++) begin:	for_loop_assignment_rdy_wopt
	    assign recv_tile_rdy [i] = recv_wopt_rdy_o[i] & recv_wadr_rdy_o[i];
	end
endgenerate


//------------------------------------------
// Acc assignments
//------------------------------------------



always_comb begin
	
	for(int i = 0; i < 4 ; i++) begin: assign_loop //4 is the number of tiles connected to the data memory
	
		//avoiding inferred latches

		data_mem_recv_waddr_rdy[i] = tcdm_rsp_q_ready[i];
		data_mem_recv_wdata_rdy[i] = tcdm_rsp_q_ready[i];
		tcdm_req_amo[i] = 0;

		
		data_mem_send_rdata_msg_internal[i].bypass = 0;
		data_mem_send_rdata_msg_internal[i].predicate = 0;
		data_mem_send_rdata_msg_internal[i].payload = 0;
		data_mem_recv_raddr_rdy[i] = tcdm_rsp_q_ready[i];
		data_mem_send_rdata_en[i] = 0;
		
		//----------------------------------------------------------------------------
		//Write portion
		//----------------------------------------------------------------------------
		if ( data_mem_recv_waddr_en[i] == 1'd1 ) begin			
            
		        tcdm_req_addr[i] = data_mem_recv_waddr_msg[i];
			    tcdm_req_write[i] = data_mem_recv_waddr_en[i] & data_mem_recv_wdata_en[i];
			    tcdm_req_data[i] = data_mem_recv_wdata_msg_internal[i].payload;
			    tcdm_req_strb[i] = 8'hFF;	
			    tcdm_req_q_valid[i] = tcdm_rsp_q_ready[i] & data_mem_recv_wdata_msg_internal[i].predicate;	

        //----------------------------------------------------------------------------
		//Read portion
		//----------------------------------------------------------------------------
		
		end else if(data_mem_recv_raddr_en[i] == 1'd1) begin

				tcdm_req_addr[i] = data_mem_recv_raddr_msg[i];
				data_mem_send_rdata_en[i] = tcdm_rsp_p_valid[i];
				data_mem_send_rdata_msg_internal[i].predicate = 1'd1;
				data_mem_send_rdata_msg_internal[i].payload = tcdm_rsp_data[i];
				tcdm_req_q_valid[i] = data_mem_send_rdata_rdy[i] & data_mem_recv_raddr_en[i];
			end
		end

	end
	
endmodule
