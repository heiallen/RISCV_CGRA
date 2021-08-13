`include "defines.v"

module exu_alu_rglr(
    input clk, rst_n,
    input alu_i_valid,
    input [`E203_XLEN-1:0] alu_i_rs1,
    input [`E203_XLEN-1:0] alu_i_rs2,
    input [`E203_XLEN-1:0] alu_i_imm,
    input [`E203_PC_SIZE-1:0] alu_i_pc,
    input [`E203_DECINFO_ALU_WIDTH-1:0] alu_i_info,

    output alu_i_ready,

    //ALU写回/交付接口
    //cmt = commit
    input alu_o_ready,
    output alu_o_valid,
    output [`E203_XLEN-1:0] alu_o_wbck_wdat,
    output alu_o_wbck_err,
    output alu_o_cmt_ecall,
    output alu_o_cmt_ebreak,
    output alu_o_cmt_wfi,

    //To share the ALU datapath
    //the operands and info to ALU
    output alu_req_alu_add,
    output alu_req_alu_sub,
    output alu_req_alu_xor,
    output alu_req_alu_sll,
    output alu_req_alu_srl,
    output alu_req_alu_sra,
    output alu_req_alu_or,
    output alu_req_alu_and,
    output alu_req_alu_slt,
    output alu_req_alu_sltu,
    output alu_req_alu_lui,
    output [`E203_XLEN-1:0] alu_req_alu_op1,
    output [`E203_XLEN-1:0] alu_req_alu_op2,

    input [`E203_XLEN-1:0] alu_req_alu_res
);

wire op2imm = alu_i_info[`E203_DECINFO_ALU_OP2IMM];
wire op1pc = alu_i_info[`E203_DECINFO_ALU_OP1PC];

assign alu_req_alu_op1 = op1pc ? alu_i_pc : alu_i_rs1;
assign alu_req_alu_op2 = op2imm ? alu_i_imm : alu_i_rs2;


wire nop = alu_i_info[`E203_DECINFO_ALU_NOP];
wire ecall = alu_i_info[`E203_DECINFO_ALU_ECAL];
wire ebreak = alu_i_info[`E203_DECINFO_ALU_EBRK];
wire wfi = alu_i_info [`E203_DECINFO_ALU_WFI];

//the nop is encoded as ADDI, so need to uncheck it

assign alu_req_alu_add = alu_i_info[`E203_DECINFO_ALU_ADD] & (~nop);
assign alu_req_alu_sub = alu_i_info[`E203_DECINFO_ALU_SUB];
assign alu_req_alu_xor = alu_i_info[`E203_DECINFO_ALU_XOR];
assign alu_req_alu_sll = alu_i_info[`E203_DECINFO_ALU_SLL];
assign alu_req_alu_srl = alu_i_info[`E203_DECINFO_ALU_SRL];
assign alu_req_alu_sra = alu_i_info[`E203_DECINFO_ALU_SRA];
assign alu_req_alu_or = alu_i_info[`E203_DECINFO_ALU_OR];
assign alu_req_alu_and = alu_i_info[`E203_DECINFO_ALU_AND];
assign alu_req_alu_slt = alu_i_info[`E203_DECINFO_ALU_SLT];
assign alu_req_alu_sltu = alu_i_info[`E203_DECINFO_ALU_SLTU];
assign alu_req_alu_lui = alu_i_info[`E203_DECINFO_ALU_LUI];

assign alu_o_valid = alu_i_valid;
assign alu_i_ready = alu_o_ready;
assign alu_o_wbck_dat = alu_req_alu_res;

assign alu_o_cmt_ecall = ecall;
assign alu_o_cmt_ebreak = ebreak;
assign alu_o_cmt_wfi = wfi;

//the exception or error result cannot write-back
assign alu_o_wbck_err = alu_o_cmt_ecall | alu_o_cmt_ebreak | alu_o_cmt_wfi;


endmodule