`include "defines.v"

module ifu_ifetch (
    output [`E203_PC_SIZE-1:0] inspect_pc,

    input [`E203_PC_SIZE-1:0] pc_rtvec,

    output ifu_req_valid,   //handshake valid
    input ifu_req_ready,   //handshake ready

    output [`E203_PC_SIZE-1:0] ifu_req_pc,  //fetch pc
    output ifu_req_seq, //this request is a sequential ins fetch
    output ifu_req_seq_rv32, //increment 32bit ins
    output [`E203_PC_SIZE-1:0] ifu_req_last_pc, //the last accessed pc address

    //ifetch rsp channel
    input ifu_rsp_valid, //response valid
    output ifu_rsp_ready, //response ready
    input ifu_rsp_err, //response error

    input [`E203_INSTR_SIZE-1:0] ifu_rsp_instr, //response inst

    ///////////////////////////////////////////////////////////
    //the IR stage to EXU interface
    output [`E203_INSTR_SIZE-1:0] ifu_o_ir, //the inst reg
    output [`E203_PC_SIZE-1:0] ifu_o_pc, //the pc reg
    output ifu_o_pc_vld,
    output [`E203_RFIDX_WIDTH-1:0] ifu_o_rs1idx,
    output [`E203_RFIDX_WIDTH-1:0] ifu_o_rs2idx,
    output ifu_o_prdt_taken, //the Bxx is predicted as taken
    output ifu_o_misalgn, //the fetch misalign
    output ifu_o_buserr, //the fetch bus error
    output ifu_o_muldiv_b2b, //the mul/div back2back case
    output ifu_o_valid, //handshake signals with EXU stage
    input ifu_o_ready,

    output pipe_flush_ack,
    input pipe_flush_req,
    input [`E203_PC_SIZE-1:0] pipe_flush_add_op1,
    input [`E203_PC_SIZE-1:0] pipe_flush_add_op2,
    `ifdef E203_TIMING_BOOST
    input [`E203_PC_SIZE-1:0] pipe_flush_pc,
    `endif 

    //the halt req come from other commit stage
    input ifu_halt_req,
    output ifu_halt_ack,

    input otif_empty,
    input [`E203_XLEN-1:0] rf2ifu_x1,
    input [`E203_XLEN-1:0] rd2ifu_rs1,
    input dec2ifu_rs1en,
    input dec2ifu_rden,
    input [`E203_RFIDX_WIDTH-1:0] dec2ifu_rdidx,
    input dec2ifu_mulhsu,
    input dec2ifu_div,
    input dec2ifu_rem,
    input dec2ifu_divu,
    input dec2ifu_remu,

    input clk,
    input rst_n
);


wire ifu_req_hsked = (ifu_req_valid & ifu_req_ready);
wire ifu_rsp_hsked = (ifu_rsp_valid & ifu_rsp_ready);
wire ifu_ir_o_hsked = (ifu_o_valid & ifu_o_ready);
wire pipe_flush_hsked = pipe_flush_req & pipe_flush_ack;

//the rst_flag is the synced version of rst_n
wire reset_flag_r;
sirv_gnrl_dffrs #(1) reset_flag_dffrs(1'b0,reset_flag_r,clk,rst_n);


//the reset_req valid is set when currently rest_flag is asserting
//the reset_req valid is clear when currently reset_req is asserting 
//or currently the flush can be accepted by IFU
wire reset_req_r;
wire reset_req_set = (~reset_req_r) & reset_flag_r;
wire reset_req_clr = reset_req_r & ifu_req_hsked;
wire reset_req_ena = reset_req_set | reset_req_clr;
wire reset_req_nxt = reset_req_set | (~reset_req_clr);

sirv_gnrl_dfflr #(1) reset_req_dfflr(reset_req_ena,reset_req_nxt,reset_req_r,clk,rst_n);

wire ifu_reset_req = reset_req_r;


//////////////////////////////////////////////////////////////////
//the halt ack generation

wire halt_ack_set;
wire halt_ack_clr;
wire halt_ack_ena;
wire halt_ack_r;
wire halt_ack_nxt;

//the halt_ack will be set when
//  currently halt_req is asserting
//  currently halt_ack is not asserting
//  currently the ifetch REQ channel is ready, means there is no outstanding transactions

wire ifu_no_outs;
assign halt_ack_set = ifu_halt_req & (~halt_ack_r) & ifu_no_outs;

//the halt_ack_r valid is cleared when 
//  currently halt_ack is asserting
//  currently halt_req is de-asserting
assign halt_ack_clr = halt_ack_r & (~ifu_halt_req);
assign halt_ack_ena = halt_ack_set | halt_ack_clr;
assign halt_ack_nxt = halt_ack_set | (~halt_ack_clr);

sirv_gnrl_dfflr #(1) halt_ack_dfflr (halt_ack_ena,halt_ack_nxt,halt_ack_r,clk,rst_n);

assign ifu_halt_ack = halt_ack_r;


/////////////////////////////////////////////////////////////////////
//the flush ack signal generation

assign pipe_flush_ack = 1'b1;

wire dly_flush_set;
wire dly_flush_clr;
wire dly_flush_ena;
wire dly_flush_nxt;

//the delay flush will be set when there is a flush request is coming, but
//the ifu is not ready to accept new fetch request
wire dly_flus_r;
assign dly_flush_set = pipe_flush_req & (~ifu_req_hsked);

//the dly_flush_r valid is cleared when the delayde flush is issued
assign dly_flush_clr = dly_flush_r & ifu_req_hsked;
assign dly_flush_ena = dly_flush_set | dly_flush_clr;
assign dly_flush_nxt = dly_flush_set | (~dly_flush_clr);

sirv_gnrl_dfflr #(1) dly_flush_dfflr (dly_flush_ena, dly_flush_nxt, dly_flush_r, clk, rst_n);

wire dly_pipe_flush_req = dly_flush_r;
wire pipe_flush_req_real = pipe_flush_req | dly_pipe_flush_req;



/////////////////////////////////////////////////////////////////////////
//the IR reg to be used in EXU for decoding
wire ir_valid_set;
wire ir_valid_clr;
wire ir_valid_ena;
wire ir_valid_r;
wire ir_valid_nxt;

wire ir_pc_vld_set;
wire ir_pc_vld_clr;
wire ir_pc_vld_ena;
wire ir_pc_vld_r;
wire ir_pc_vld_nxt;

//the ir valid is set when there is new inst fetched and no flush happening
wire ifu_rsp_need_replay;
wire pc_newpend_r;
wire ifu_ir_i_ready;
assign ir_valid_set = ifu_rsp_hsked & (~pipe_flush_req_real) & (~ifu_rsp_need_replay);
assign ir_pc_vld_set = pc_newpend_r & ifu_ir_i_ready & (~pipe_flush_req_real) & (~ifu_rsp_need_replay);

//the ir valid is cleared when it is accepted by EXU stage or the flush happending
assign ir_valid_clr = ifu_ir_o_hsked | (pipe_flush_hsked & ir_valid_r);
assign ir_pc_vld_clr = ir_valid_clr;

assign ir_valid_ena = ir_valid_set | ir_valid_clr;
assign ir_valid_nxt = ir_valid_set | (~ir_valid_clr);
assign ir_pc_vld_ena = ir_pc_vld_set | ir_pc_vld_clr;
assign ir_pc_vld_nxt = ir_pc_vld_set | (~ir_pc_vld_clr);

sirv_gnrl_dfflr #(1) ir_valid_dfflr (ir_valid_ena,ir_valid_nxt,ir_valid_r,clk,rst_n);
sirv_gnrl_dfflr #(1) ir_pc_vld_dfflr (ir_pc_vld_ena,ir_pc_vld_nxt,ir_pc_vld_r,clk,rst_n);









    
endmodule