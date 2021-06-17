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

wire reset_flag_r;
sirv_gnrl_dffrs #(1) reset_flag_dffrs(1'b0,reset_flag_r,clk,rst_n);




    
endmodule