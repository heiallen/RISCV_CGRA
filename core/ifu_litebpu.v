`include "defines.v"

module ifu_litebpu  (
    
    //current pc
    input   [`E203_PC_SIZE-1 : 0] pc,

    //the mini-decode info
    input   dec_jal,
    input   dec_jalr,
    input   dec_bxx,
    input   [`E203_XLEN-1 : 0] dec_bjp_imm,
    input   [`E203_RFIDX_WIDTH-1:0] dec_jalr_rs1idx,

    //the ir index and OITF status to be used for checking dependency
    input   otif_empty,
    input   ir_empty,
    input   ir_rs1en,
    input   jalr_rs1idx_cam_irrdidx,

    //the add op to next-pc adder
    output  bpu_wait,
    output  prdt_taken,
    output  [`E203_PC_SIZE-1:0] prdt_pc_add_op1,
    output  [`E203_PC_SIZE-1:0] prdt_pc_add_op2,

    input   dec_i_valid,

    //the rs1 to read regfile
    output  bpu2rf_rs1_ena,
    input   ir_valid_clr,
    input   [`E203_XLEN-1:0] rf2bpu_x1,
    input   [`E203_XLEN-1:0] rf2bpu_rs1,

    input   clk,
    input   rst_n    
);


//the jal and jalr is always jump, bxxx backwar is predicted as taken
assign prdt_taken = (dec_jal | dec_jalr | (dec_bxx & dec_bjp_imm[`E203_XLEN-1]));

//the jalr with rs1 == x1 have dependency or xN have dependency
wire dec_jalr_rs1x0 = (dec_jalr_rs1idx == `E203_RFIDX_WIDTH'd0);
wire dec_jalr_rs1x1 = (dec_jalr_rs1idx == `E203_RFIDX_WIDTH'd1);
wire dec_jalr_rs1xn = (~dec_jalr_rs1x0) & (~dec_jalr_rs1x1);

wire jalr_rs1x1_dep = dec_i_valid & dec_jalr & dec_jalr_rs1x1 & ((~otif_empty) | jalr_rs1idx_cam_irrdidx);
wire jalr_rs1xn_dep = dec_i_valid & dec_jalr & dec_jalr_rs1xn & ((~otif_empty) | (~ir_empty));

wire jalr_rs1xn_dep_ir_clr = (jalr_rs1xn_dep & otif_empty & (~ir_empty)) & (ir_valid_clr | (~ir_rs1en));

wire rs1xn_rdrf_r;
//rs1xn_rdrf_set 为高表示需要读取regfile的读端口，
wire rs1xn_rdrf_set = (~rs1xn_rdrf_r) & dec_i_valid & dec_jalr & dec_jalr_rs1xn & ((~jalr_rs1xn_dep) | jalr_rs1xn_dep_ir_clr);  
wire rs1xn_rdrf_clr = rs1xn_rdrf_r;
wire rs1xn_rdrf_ena = rs1xn_rdrf_set | rs1xn_rdrf_clr;
wire rs1xn_rdrf_nxt = rs1xn_rdrf_set | (~rs1xn_rdrf_clr);

sirv_gnrl_dfflr #(1) rs1xn_rdrf_dfflrs(rs1xn_rdrf_ena,rs1xn_rdrf_nxt,rs1xn_rdrf_r,clk,rst_n);

assign bpu2rf_rs1_ena = rs1xn_rdrf_set;
assign bpu_wait = jalr_rs1x1_dep | jalr_rs1xn_dep | rs1xn_rdrf_set;

assign prdt_pc_add_op1 = (dec_bxx | dec_jal) ? pc[`E203_PC_SIZE-1:0]
                        : (dec_jalr & dec_jalr_rs1x0) ? `E203_PC_SIZE'b0
                        : (dec_jalr & dec_jalr_rs1x1) ? rf2bpu_x1[`E203_PC_SIZE-1:0]
                        : rf2bpu_rs1[`E203_PC_SIZE-1:0];

assign prdt_pc_add_op2 = dec_bjp_imm[`E203_PC_SIZE-1:0];


endmodule //ifu_litebpu