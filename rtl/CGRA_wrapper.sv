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
	parameter int unsigned DataWidth = 64,
  	parameter int unsigned SnaxTcdmPorts = 4,    //equal #tiles that can access memory
  	parameter int unsigned TCDMAddrWidth = 48,
   	parameter int unsigned AddrWidth = 6,

	parameter int unsigned CGRADim      = 16,
	parameter int unsigned KernelSize   = 4,
	parameter int unsigned RegDataWidth = DataWidth,
	parameter int unsigned RegAddrWidth = 32,

    parameter type         acc_req_t     = logic,
    parameter type         acc_rsp_t     = logic,
    parameter type         tcdm_req_t    = logic,
    parameter type         tcdm_rsp_t    = logic
)(
	
	input  logic                    clk_i,
	input  logic                    rst_ni,

	input  logic     snax_qvalid_i,
    output logic     snax_qready_o,
    input  acc_req_t snax_req_i,

    output acc_rsp_t snax_resp_o,
    output logic     snax_pvalid_o,
    input  logic     snax_pready_i,

    output tcdm_req_t [SnaxTcdmPorts-1:0] snax_tcdm_req_o,
    input  tcdm_rsp_t [SnaxTcdmPorts-1:0] snax_tcdm_rsp_i, // need to change to tcdm_req_t/rsp
    output logic                          snax_barrier_o

);

    CGRAData_16_1_1__payload_16__predicate_1__bypass_1 data_mem_recv_wdata_msg_internal [0:3];
    CGRAData_16_1_1__payload_16__predicate_1__bypass_1 data_mem_send_rdata_msg_internal [0:3];


	logic [RegAddrWidth-1:0] csr_addr_i;
	logic [RegDataWidth-1:0] csr_wr_data_i;
    logic                    csr_wr_en_i;
    logic                    csr_req_valid_i;
    logic                    csr_req_ready_o;
	logic [RegDataWidth-1:0] csr_rsp_data_o;
    logic                    csr_rsp_valid_o;
    logic                    csr_rsp_ready_i;
	
    //-----------------------------
    // Seperated TCDM ports signals
    //-----------------------------
    logic  [SnaxTcdmPorts-1:0]                        tcdm_req_write;
    logic  [SnaxTcdmPorts-1:0][TCDMAddrWidth-1:0]     tcdm_req_addr;
    //Note that tcdm_req_amo_i is 4 bits based on reqrsp definition
    logic  [SnaxTcdmPorts-1:0][3:0]                   tcdm_req_amo;
    logic  [SnaxTcdmPorts-1:0][DataWidth-1:0]   tcdm_req_data;
    //Note that tcdm_req_user_core_id_i is 5 bits based on Snitch definition
    logic  [SnaxTcdmPorts-1:0][4:0]                   tcdm_req_user_core_id;
    bit    [SnaxTcdmPorts-1:0]                        tcdm_req_user_is_core;
    logic  [SnaxTcdmPorts-1:0][DataWidth/8-1:0] tcdm_req_strb;
    logic  [SnaxTcdmPorts-1:0]                        tcdm_req_q_valid;
    logic  [SnaxTcdmPorts-1:0]                        tcdm_rsp_q_ready;
    logic  [SnaxTcdmPorts-1:0]                        tcdm_rsp_p_valid;
    logic  [SnaxTcdmPorts-1:0][DataWidth-1:0]   tcdm_rsp_data;



    //-------------------------------------------------------------
    //write to memory
  	//-------------------------------------------------------------
	 logic data_mem_recv_waddr_en [0:3];
	// size of waddr = clog2(Population Data Size) In this case I had mem size = 100, 7 bits.
	 logic [AddrWidth-1:0] data_mem_recv_waddr_msg [0:3];
	 logic data_mem_recv_waddr_rdy [0:3];
	 logic data_mem_recv_wdata_en [0:3];
	 logic data_mem_recv_wdata_rdy [0:3];

	
  	//------------------------------------------
	//Reading from memory
  	//------------------------------------------
  	 logic data_mem_recv_raddr_en [0:3];
  	 logic [AddrWidth-1:0] data_mem_recv_raddr_msg [0:3];
  	 logic data_mem_recv_raddr_rdy [0:3];
  	 logic data_mem_send_rdata_en [0:3];
  	 logic data_mem_send_rdata_rdy [0:3];

 
    logic [1:0] csr_tile_addr [0:15];
    CGRAConfig_6_4_6_8__764c37c5066f1efc csr_tile_data [0:15];
    logic  csr_tile_wr_en [0:15];
    logic  csr_tile_wr_valid [0:15];
    logic recv_tile_rdy [0:15];

    logic recv_wadr_rdy_o [0:15];
    logic recv_wopt_rdy_o [0:15];


snax_cgra_interface #(
        .acc_req_t ( acc_req_t ),
        .acc_rsp_t ( acc_rsp_t )
    ) i_snax_interface_translator(
        //-----------------------------
        // Clocks and reset
        //-----------------------------
        .clk_i(clk_i),
        .rst_ni(rst_ni),

        .snax_qvalid_i(snax_qvalid_i),
        .snax_qready_o(snax_qready_o),
        .snax_req_i(snax_req_i),

        .snax_resp_o(snax_resp_o),
        .snax_pvalid_o(snax_pvalid_o),
        .snax_pready_i(snax_pready_i),

        //-----------------------------
        // Simplified CSR control ports
        //-----------------------------
        // Request
        .io_csr_req_bits_data_i(csr_wr_data_i),
        .io_csr_req_bits_addr_i(csr_addr_i),
        .io_csr_req_bits_write_i(csr_wr_en_i),
        .io_csr_req_valid_i(csr_req_valid_i),
        .io_csr_req_ready_o(csr_req_ready_o),

        // Response
        .io_csr_rsp_ready_i(csr_rsp_ready_i),
        .io_csr_rsp_valid_o(csr_rsp_valid_o),
        .io_csr_rsp_bits_data_o(csr_rsp_data_o)

    );




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
  .csr_rd_data_o     (csr_rsp_data_o),
  .csr_rsp_valid_o   (csr_rsp_valid_o),
  .csr_rsp_ready_i   (csr_rsp_ready_i),

  .csr_tile_addr     (csr_tile_addr),
  .csr_tile_data     (csr_tile_data),
  .csr_tile_wr_en    (csr_tile_wr_en),
  .csr_tile_wr_valid (csr_tile_wr_valid),
  .csr_tile_ready    (recv_tile_rdy)
);


//chaning mem address to TCDMaddressWidth
CGRARTL__e95cacd33b23104e#(
.TCDMAddrWidth(AddrWidth)
) CGRARtl (
    .clk(clk_i),
    .reset(rst_ni),

    // CSR 
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
            
            tcdm_req_addr[i][5:0] = data_mem_recv_waddr_msg[i];
			tcdm_req_write[i] = data_mem_recv_waddr_en[i] & data_mem_recv_wdata_en[i];
			tcdm_req_data[i] = data_mem_recv_wdata_msg_internal[i].payload;
		    tcdm_req_strb[i] = 8'hFF;	
			tcdm_req_q_valid[i] = tcdm_rsp_q_ready[i] & data_mem_recv_wdata_msg_internal[i].predicate;	

        //----------------------------------------------------------------------------
		//Read portion
		//----------------------------------------------------------------------------
		
		end else if(data_mem_recv_raddr_en[i] == 1'd1) begin

            tcdm_req_addr[i][5:0] = data_mem_recv_raddr_msg[i];
			data_mem_send_rdata_en[i] = tcdm_rsp_p_valid[i];
			data_mem_send_rdata_msg_internal[i].predicate = 1'd1;
			data_mem_send_rdata_msg_internal[i].payload = tcdm_rsp_data[i];
		    tcdm_req_q_valid[i] = data_mem_send_rdata_rdy[i] & data_mem_recv_raddr_en[i];
			end
		end
	end

	/*always_comb begin: gen_hard_bundle
        for(int i=0; i < SnaxTcdmPorts; i++) begin

            snax_tcdm_req_o[i].q.write           = tcdm_req_write[i];
            snax_tcdm_req_o[i].q.addr            = tcdm_req_addr[i];
            // snax_tcdm_req_o[i].q.amo             = tcdm_req_amo_i[i];
            snax_tcdm_req_o[i].q.amo             = 0;
            snax_tcdm_req_o[i].q.data            = tcdm_req_data[i];
            snax_tcdm_req_o[i].q.user.core_id    = tcdm_req_user_core_id[i];
            snax_tcdm_req_o[i].q.user.is_core    = tcdm_req_user_is_core[i];
            snax_tcdm_req_o[i].q.strb            = tcdm_req_strb[i];
            snax_tcdm_req_o[i].q_valid           = tcdm_req_q_valid[i];

            tcdm_rsp_q_ready[i]                = snax_tcdm_rsp_i[i].q_ready;
            tcdm_rsp_p_valid[i]                = snax_tcdm_rsp_i[i].p_valid;
            tcdm_rsp_data[i]                   = snax_tcdm_rsp_i[i].p.data;

        end
    end*/

    assign snax_barrier_o = csr_req_ready_o;

endmodule
