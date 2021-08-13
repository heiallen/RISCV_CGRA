`include "defines.v"

module exu_alu_bjp(
    input clk,
    input rst_n,
    input bjp_i_valid,
    output bjp_i_ready,

    input [`E203_XLEN-1:0] bjp_i_rs1,
    input [`E203_XLEN-1:0] bjp_i_rs2,
    input [`E203_XLEN-1:0] bjp_i_imm,
    input [`E203_PC_SIZE-1:0] bjp_i_pc,
    input [`E203_DECINFO_BJP_WIDTH-1:0] bjp_i_info,

    //bjp交付接口
    input bjp_o_ready,
    output bjp_o_valid,
    output [`E203_XLEN-1:0] bjp_o_wbck_dat,
    output bjp_o_cmt_err,
    output bjp_o_cmt_bjp,
    output bjp_o_cmt_mret,
    output bjp_o_cmt_dret,
    output bjp_o_cmt_fencei,
    output bjp_o_cmt_prdt,
    output bjp_o_cmt_rslv,

    //the operands and info to ALU
    output [`E203_XLEN-1:0] bjp_req_alu_op1,
    output [`E203_XLEN-1:0] bjp_req_alu_op2,
    output bjp_req_alu_cmp_eq,
    output bjp_req_alu_cmp_ne,
    output bjp_req_alu_cmp_lt,
    output bjp_req_alu_cmp_gt,
    output bjp_req_alu_cmp_ltu,
    output bjp_req_alu_cmp_gtu,
    output bjp_req_alu_add,

    input bjp_req_alu_cmp_res,
    input [`E203_XLEN-1:0] bjp_req_alu_add_res
);

    wire mret = bjp_i_info[`E203_DECINFO_BJP_MRET];
    wire dret = bjp_i_info[`E203_DECINFO_BJP_DRET];
    wire fencei = bjp_i_info[`E203_DECINFO_BJP_FENCEI];
    wire bxx = bjp_i_info[`E203_DECINFO_BJP_BXX];
    wire jump = bjp_i_info[`E203_DECINFO_BJP_JUMP];
    wire rv32 = bjp_i_info[`E203_DECINFO_RV32];

    wire wbck_link = jump;
    wire bjp_i_bprdt = bjp_i_info [`E203_DECINFO_BJP_BPRDT];
    assign bjp_req_alu_op1 = wbck_link ? bjp_i_pc : bjp_i_rs1;
    assign bjp_req_alu_op2 = wbck_link ? (rv32 ? `E203_XLEN'd4 : `E203_XLEN'd2) : bjp_i_rs2;

    assign bjp_o_cmt_bjp = bxx | jump;
    assign bjp_o_cmt_mret = mret;
    assign bjp_o_cmt_dret = dret;
    assign bjp_o_cmt_fencei = fencei;

    assign bjp_req_alu_cmp_eq = bjp_i_info[`E203_DECINFO_BJP_BEQ];
    assign bjp_req_alu_cmp_ne = bjp_i_info[`E203_DECINFO_BJP_BNE];
    assign bjp_req_alu_cmp_lt = bjp_i_info[`E203_DECINFO_BJP_BLT];
    assign bjp_req_alu_cmp_gt = bjp_i_info[`E203_DECINFO_BJP_BGT];
    assign bjp_req_alu_cmp_ltu = bjp_i_info[`E203_DECINFO_BJP_BLTU];
    assign bjp_req_alu_cmp_gtu = bjp_i_info[`E203_DECINFO_BJP_BGTU];

    assign bjp_req_alu_add = wbck_link;

    assign bjp_o_valid = bjp_i_valid;
    assign bjp_i_ready = bjp_o_ready;
    assign bjp_o_cmt_prdt = bjp_i_bprdt;
    assign bjp_o_cmt_rslv = jump ? 1'b1 : bjp_req_alu_cmp_res;

    assign bjp_o_wbck_wdat = bjp_req_alu_add_res;
    assign bjp_o_wbck_err = 1'b0;

endmodule

