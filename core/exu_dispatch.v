`include "defines.v"

module exu_disp(
    input clk, rst_n,
    input wfi_halt_exu_req, //wfi = wait for interrupt，用来使CPU进入idle状态
    output wfi_halt_exu_ack,

    input oitf_empty,
    input amo_wait,

    input disp_i_valid, //handshake valid
    output disp_i_ready, //handshake ready

    //the operand 1/2 read-enable signals and indexes
    input disp_i_rs1x0,
    input disp_i_rs2x0, 
    input disp_i_rs1en,
    input disp_i_rs2en,
    input [`E203_RFIDX_WIDTH-1:0] disp_i_rs1idx,
    input [`E203_RFIDX_WIDTH-1:0] disp_i_rs2idx,
    input [`E203_XLEN-1:0] disp_i_rs1,
    input [`E203_XLEN-1:0] disp_i_rs2,

    input disp_i_rdwen,
    input [`E203_RFIDX_WIDTH-1:0] disp_i_rdidx,
    input [`E203_DECINFO_WIDTH-1:0] disp_i_info,
    input [`E203_XLEN-1:0] disp_i_imm,
    input [`E203_PC_SIZE-1:0] disp_i_pc,
    input disp_i_misalgn,
    input disp_i_buserr,
    input disp_i_ilegl,

    //dispatch to alu
    output disp_o_alu_valid,
    input disp_o_alu_ready,
    input disp_o_alu_longpipe,

    output [`E203_XLEN-1:0] disp_o_alu_rs1,
    output [`E203_XLEN-1:0] disp_o_alu_rs2,
    output disp_o_alu_rdwen,
    output [`E203_RFIDX_WIDTH-1:0] disp_o_alu_rdidx,
    output [`E203_DECINFO_WIDTH-1:0] disp_o_alu_info,
    output [`E203_XLEN-1:0] disp_o_alu_imm,
    output [`E203_PC_SIZE-1:0] disp_o_alu_pc,
    output [`E203_ITAG_WIDTH-1:0] disp_o_alu_itag,
    output disp_o_alu_misalgn,
    output disp_o_alu_buserr,
    output disp_o_alu_ilegl,

    //dispatch to oitf
    input oitfrd_match_disprs1,
    input oitfrd_match_disprs2,
    input oitfrd_match_disprs3,
    input oitfrd_match_disprd,
    input [`E203_ITAG_WIDTH-1:0] disp_oitf_ptr,

    output disp_oitf_ena,
    input disp_oitf_ready,

    output disp_oitf_rs1fpu,
    output disp_oitf_rs2fpu,
    output disp_oitf_rs3fpu,
    output disp_oitf_rdfpu,

    output disp_oitf_rs1en,
    output disp_oitf_rs2en,
    output disp_oitf_rs3en,
    output disp_oitf_rdwen,

    output [`E203_RFIDX_WIDTH-1:0] disp_oitf_rs1idx,
    output [`E203_RFIDX_WIDTH-1:0] disp_oitf_rs2idx,
    output [`E203_RFIDX_WIDTH-1:0] disp_oitf_rs3idx,
    output [`E203_RFIDX_WIDTH-1:0] disp_oitf_rdidx,

    output [`E203_PC_SIZE-1:0] disp_oitf_pc

);

wire [`E203_DECINFO_GRP_WIDTH-1:0] disp_i_info_grp = disp_i_info[`E203_DECINFO_GRP];

wire disp_csr = (disp_i_info_grp == `E203_DECINFO_GRP_CSR);
wire disp_alu_longp_prdt = (disp_i_info_grp == `E203_DECINFO_GRP_AGU);  //预测为长指令
wire disp_alu_longp_real = disp_o_alu_longpipe; //确定为长指令

wire disp_fence_fencei = (disp_i_info_grp == `E203_DECINFO_GRP_BJP) & (disp_i_info[`E203_DECINFO_BJP_FENCE] | disp_i_info[`E203_DECINFO_BJP_FENCEI]);

wire disp_i_valid_pos;
wire disp_i_ready_pos = disp_o_alu_ready;
assign disp_o_alu_valid = disp_i_valid_pos;

//The dispatch scheme inroduction for two_pipe stage
//#1 分发后的指令必须已经取完了操作数，所有不会有WAR依赖发生；也就是说解决WAR依赖在分发这一步中就需要完成
//#2 在ALU内，ALU指令是按序分发和执行的，所以在ALU指令之间不会存在WAW依赖；
//  注：由于LSU的AGU是位于ALU内部的，所以LSU指令被当作ALU指令对待；
//#3 非ALU指令均被OITF跟踪，并且必须被顺序写回，所以和顺序执行的ALU指令一样，所以在非ALU指令间也不存在WAW依赖；
//还有两种依赖可能会出现：
//  @RAW 真数据相关
//  @WAW 存在与ALU指令和非ALU指令之间的数据相关
//  
//所以： #1在以下情况中，ALU指令的分发必须停滞：
//      **RAW ALU要读取的操作数与OITF中的条目之间由数据依赖；
//              注意：因为只有两级流水线，所以在执行当前ALU指令时，上一条ALU指令必然已经写回了reg file，所以两条相邻的ALU指令之间不会有RAW依赖的问题
//                  如果是三级流水线的话，就需要考虑ALU-to-ALU 的RAW依赖
//      **WAW ALU的写结果和OITF的条目之间没有任何依赖？？？
//              注意：因为ALU处理的ALU指令有可能会超过OITF处理的非ALU指令，所以必须检查这个
//      #2在以下情况中，非ALU指令的分发必须停滞
//      **RAW 非ALU指令的读操作数和OITF中的条目有数据依赖
//              注意：因为只有两级流水线，所以当前非ALU指令执行时，上一条ALU指令已经写回，两者之间不会存在RAW依赖冲突
//                  如果是三级流水线就需要考虑no ALU-to-ALU 的RAW依赖
wire raw_dep = ((oitfrd_match_disprs1) | (oitfrd_match_disprs2) | (oitfrd_match_disprs3));

//仅对长指令（非ALU）检查WAW依赖；
wire waw_dep = (oitfrd_match_disprd);
wire dep = raw_dep | waw_dep;

assign wfi_halt_exu_ack = oitf_empty &(~amo_wait);

//为了更保守一点，任何的CSR访问指令都必须等到OITF为空，理论上来说，CSR更新后流水线应该被冲刷，以确保后续的指令
//可以取到正确的CSR值，但是在现有的两级流水线中，CSR实在EXU之后更新的，后续的指令都是在EXU阶段执行的，没有机会
//取到错误的CSR值，所以不用担心这一点。（也就是说在指令执行阶段，CSR还没有被更新）

wire disp_condition = (disp_csr? oitf_empty : 1'b1) & (disp_fence_fencei ? oitf_empty : 1'b1)
                        & (~wfi_halt_exu_req) & (~dep) 
                        //如果分发到ALU的是长流水指令的话，必须要检查oitf是否ready
                        //为了从长流水信号上切断关键时序路径，我们总是假设LSU需要OITF ready
                        & (disp_alu_longp_prdt ? disp_oitf_ready : 1'b1);

assign disp_i_valid_pos = disp_condition & disp_i_valid;
assign disp_i_ready = disp_condition & disp_i_ready_pos;

wire [`E203_XLEN-1:0] disp_i_rs1_msked = disp_i_rs1 & {`E203_XLEN{~disp_i_rs1x0}};
wire [`E203_XLEN-1:0] disp_i_rs2_msked = disp_i_rs2 & {`E203_XLEN{~disp_i_rs2x0}};
//因为指令总是要分发到ALU，所以这里无需门控，如果需要门控的话，每个信号前面都要与上一个等位宽拓展的disp_alu
assign disp_o_alu_rs1 = disp_i_rs1_msked;
assign disp_o_alu_rs2 = disp_i_rs2_msked;
assign disp_o_alu_rdwen = disp_i_rdwen;
assign disp_o_alu_rdidx = disp_i_rdidx;
assign disp_o_alu_info = disp_i_info;

//只有当指令是确定的long pipe时，才使能OITF
assign disp_oitf_ena = disp_o_alu_valid & disp_o_alu_ready & disp_alu_longp_real;

assign disp_o_alu_imm = disp_i_imm;
assign disp_o_alu_pc = disp_i_pc;
assign disp_o_alu_itag = disp_oitf_ptr;
assign disp_o_alu_misalgn = disp_i_misalgn;
assign disp_o_alu_buserr = disp_i_buserr;
assign disp_o_alu_ilegl = disp_i_ilegl;

`ifndef E203_HAS_FPU
wire disp_i_fpu = 1'b0;
wire disp_i_fpu_rs1en = 1'b0;
wire disp_i_fpu_rs2en = 1'b0;
wire disp_i_fpu_rs3en = 1'b0;
wire disp_i_fpu_rdwen = 1'b0;
wire [`E203_RFIDX_WIDTH-1:0] disp_i_fpu_rs1idx = `E203_RFIDX_WIDTH'b0;
wire [`E203_RFIDX_WIDTH-1:0] disp_i_fpu_rs2idx = `E203_RFIDX_WIDTH'b0;
wire [`E203_RFIDX_WIDTH-1:0] disp_i_fpu_rs3idx = `E203_RFIDX_WIDTH'b0;
wire [`E203_RFIDX_WIDTH-1:0] disp_i_fpu_rdidx = `E203_RFIDX_WIDTH'b0;
wire disp_i_fpu_rs1fpu = 1'b0;
wire disp_i_fpu_rs2fpu = 1'b0;
wire disp_i_fpu_rs3fpu = 1'b0;
wire disp_i_fpu_rdfpu = 1'b0;
`endif

assign disp_oitf_rs1fpu = disp_i_fpu ? (disp_i_fpu_rs1en & disp_i_fpu_rs1fpu) : 1'b0;
assign disp_oitf_rs2fpu = disp_i_fpu ? (disp_i_fpu_rs2en & disp_i_fpu_rs2fpu) : 1'b0;
assign disp_oitf_rs3fpu = disp_i_fpu ? (disp_i_fpu_rs3en & disp_i_fpu_rs3fpu) : 1'b0;
assign disp_oitf_rdfpu = disp_i_fpu ? (disp_i_fpu_rdwen & disp_i_fpu_rdfpu) : 1'b0;

assign disp_oitf_rs1en = disp_i_fpu ? disp_i_fpu_rs1en : disp_i_rs1en;
assign disp_oitf_rs2en = disp_i_fpu ? disp_i_fpu_rs2en : disp_i_rs2en;
assign disp_oitf_rs3en = disp_i_fpu ? disp_i_fpu_rs3en : 1'b0;
assign disp_oitf_rdwen = disp_i_fpu ? disp_i_fpu_rdwen : disp_i_rdwen;

assign disp_oitf_rs1idx = disp_i_fpu ? disp_i_fpu_rs1idx : disp_i_rs1idx;
assign disp_oitf_rs2idx = disp_i_fpu ? disp_i_fpu_rs2idx : disp_i_rs2idx;
assign disp_oitf_rs3idx = disp_i_fpu ? disp_i_fpu_rs3idx : `E203_RFIDX_WIDTH'b0;
assign disp_oitf_rdidx = disp_i_fpu ? disp_i_fpu_rdidx : disp_i_rdidx;

assign disp_oitf_pc = disp_i_pc;


endmodule