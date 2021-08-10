`include "defines.v"

module exu_oitf (
    input clk,
    input rst_n,
    input dis_ena,
    input ret_ena,
    input disp_i_rs1en,
    input disp_i_rs2en,
    input disp_i_rs3en,
    input disp_i_rdwen,
    input disp_i_rs1fpu,
    input disp_i_rs2fpu,
    input disp_i_rs3fpu,
    input disp_i_rdfpu,
    input [`E203_RFIDX_WIDTH-1:0] disp_i_rs1idx,
    input [`E203_RFIDX_WIDTH-1:0] disp_i_rs2idx,
    input [`E203_RFIDX_WIDTH-1:0] disp_i_rs3idx,
    input [`E203_RFIDX_WIDTH-1:0] disp_i_rdidx,
    input [`E203_PC_SIZE-1:0] disp_i_pc,

    output dis_ready,
    output [`E203_ITAG_WIDTH-1:0] dis_ptr,
    output [`E203_ITAG_WIDTH-1:0] ret_ptr,
    output [`E203_RFIDX_WIDTH-1:0] ret_rdidx,
    output ret_rdwen,
    output ret_rdfpu,
    output [`E203_PC_SIZE-1:0] ret_pc,
    output oitfrd_match_disprs1,
    output oitfrd_match_disprs2,
    output oitfrd_match_disprs3,
    output oitfrd_match_disprd,

    output oitf_empty
);
    
wire [`E203_OITF_DEPTH-1:0] vld_set;
wire [`E203_OITF_DEPTH-1:0] vld_clr;
wire [`E203_OITF_DEPTH-1:0] vld_ena;
wire [`E203_OITF_DEPTH-1:0] vld_nxt;
wire [`E203_OITF_DEPTH-1:0] vld_r;
wire [`E203_OITF_DEPTH-1:0] rdwen_r;
wire [`E203_OITF_DEPTH-1:0] rdfpu_r;
wire [`E203_RFIDX_WIDTH-1:0] rdidx_r[`E203_OITF_DEPTH-1:0];
wire [`E203_PC_SIZE-1:0] pc_r[`E203_OITF_DEPTH-1:0];

wire alc_ptr_ena = dis_ena;
wire ret_ptr_ena = ret_ena;

wire oitf_full;

wire [`E203_ITAG_WIDTH-1:0] alc_ptr_r;  //写指针
wire [`E203_ITAG_WIDTH-1:0] ret_ptr_r;  //读指针

generate//这里用generate的原因是因为if...else必须在某个块里
    if(`E203_OITF_DEPTH > 1) begin: depth_gt1
    //alc_ptr_flg_r, ret_ptr_flg_r在复位的时候被拉高

        wire alc_ptr_flg_r;
        wire alc_ptr_flg_nxt = ~alc_ptr_flg_r;
        wire alc_ptr_flg_ena = (alc_ptr_r == ($unsigned(`E203_OITF_DEPTH-1))) & alc_ptr_ena;

        sirv_gnrl_dfflr #(1) alc_ptr_flg_dfflrs(alc_ptr_flg_ena,alc_ptr_flg_nxt, alc_ptr_flg_r, clk, rst_n );
        
        wire [`E203_ITAG_WIDTH-1:0] alc_ptr_nxt;

        assign alc_ptr_nxt = alc_ptr_flg_ena ? `E203_ITAG_WIDTH'b0 : (alc_ptr_r + 1'b1);

        sirv_gnrl_dfflr #(`E203_ITAG_WIDTH) alc_ptr_dfflrs(alc_ptr_ena, alc_ptr_nxt, alc_ptr_r, clk, rst_n);

        wire ret_ptr_flg_r;
        wire ret_ptr_flg_nxt = ~ret_ptr_flg_r;
        wire ret_ptr_flg_ena = (ret_ptr_r == ($unsigned(`E203_OITF_DEPTH-1))) & ret_ptr_ena;

        sirv_gnrl_dfflr #(1) ret_ptr_flg_dfflrs(ret_ptr_flg_ena, ret_ptr_flg_nxt, ret_ptr_flg_r, clk, rst_n);

        wire [`E203_ITAG_WIDTH-1:0] ret_ptr_nxt;
        assign ret_ptr_nxt = ret_ptr_flg_ena ? `E203_ITAG_WIDTH'b0 : ret_ptr_r + 1'b1;

        sirv_gnrl_dfflr #(`E203_ITAG_WIDTH) ret_ptr_dfflrs(ret_ptr_ena, ret_ptr_nxt, ret_ptr_r, clk, rst_n);

        //ret_ptr_flg_r == alc_ptr_flg_r代表写指针和读指针都从FIFO尾跳到了FIFO头，此时要么OITF中尚未写进表项
        //要么OITF中上一次写满的表项都已读出（即清除），再由（ret_ptr_r == alc_ptr_r）保证当前轮OITF中写进的表项都已读出
        //从而保证FIFO空
        //由(ret_ptr_flg_r == alc_ptr_flg_r)来保证读指针和写指针跳转了相同的轮次，
        //（ret_ptr_r == alc_ptr_r）来保证当前轮次中，写进OITF的项都已读出，从而保证OITF为空
        assign oitf_empty = (ret_ptr_r == alc_ptr_r) & (ret_ptr_flg_r == alc_ptr_flg_r);
        
        //这条语句表明读指针和写指针之间正好差一个轮次，新写进的表项和尚未读出的表项正好填满OITF，所以此时OITF是满的；
        assign oitf_full = (ret_ptr_r == alc_ptr_r) & (ret_ptr_flg_r != alc_ptr_flg_r);
    end
    else begin: depth_eq1
       assign alc_ptr_r = 1'b0;
       assign ret_ptr_r = 1'b0;
       assign oitf_empty = ~vld_r[0];
       assign oitf_empty = vld_r[0];
    end
endgenerate

    assign ret_ptr = ret_ptr_r;
    assign dis_ptr = alc_ptr_r;

    wire [`E203_OITF_DEPTH-1:0] rd_match_rs1idx;
    wire [`E203_OITF_DEPTH-1:0] rd_match_rs2idx;
    wire [`E203_OITF_DEPTH-1:0] rd_match_rs3idx;
    wire [`E203_OITF_DEPTH-1:0] rd_match_rdidx;

    genvar i;

    generate
        for(i = 0; i < `E203_OITF_DEPTH; i=i + 1)
            begin:oitf_entries
                assign vld_set[i] = alc_ptr_ena & (alc_ptr_r == i);
                assign vld_clr[i] = ret_ptr_ena & (ret_ptr_r == i);
                assign vld_ena[i] = vld_set[i] | vld_clr[i];    //只有当要读或者要写某一表项时，该表项的vld位才会改变，否则保持不变
                assign vld_nxt[i] = vld_set[i] | ~vld_clr[i];   //写的时候当前表项有效信号置高，读的时候当前表项有效信号置低

                sirv_gnrl_dfflr #(1) vld_dfflrs(vld_ena[i],vld_nxt[i],vld_r[i],clk,rst_n);
                sirv_gnrl_dffl #(`E203_RFIDX_WIDTH) rdidx_dfflrs(vld_set[i], disp_i_rdidx, rdidx_r[i], clk);
                sirv_gnrl_dffl #(`E203_PC_SIZE) pc_dfflrs(vld_set[i], disp_i_pc, pc_r[i], clk);
                sirv_gnrl_dffl #(1) rdwen_dfflrs(vld_set[i], disp_i_rdwen, rdwen_r[i], clk);
                sirv_gnrl_dffl #(1) rdfpu_dfflrs(vld_set[i], disp_i_rdfpu, rdfpu_r[i], clk);
                assign rd_match_rs1idx[i] = vld_r[i] & rdwen_r[i] & disp_i_rs1en & ((rdfpu_r[i] == disp_i_rs1fpu) | (rdidx_r[i] == disp_i_rs1idx));
                assign rd_match_rs2idx[i] = vld_r[i] & rdwen_r[i] & disp_i_rs2en & ((rdfpu_r[i] == disp_i_rs2fpu) | (rdidx_r[i] == disp_i_rs2idx));
                assign rd_match_rs3idx[i] = vld_r[i] & rdwen_r[i] & disp_i_rs3en & ((rdfpu_r[i] == disp_i_rs3fpu) | (rdidx_r[i] == disp_i_rs3idx));
                assign rd_match_rdidx[i] = vld_r[i] & rdwen_r[i] & disp_i_rdwen & ((rdfpu_r[i] == disp_i_rdfpu) | (rdidx_r[i] == disp_i_rdidx));
            end
    endgenerate

    assign oitfrd_match_disprs1 = |rd_match_rs1idx;
    assign oitfrd_match_disprs2 = |rd_match_rs2idx;
    assign oitfrd_match_disprs3 = |rd_match_rs3idx;
    assign oitfrd_match_disprd = |rd_match_rdidx;

    assign ret_rdidx = rdidx_r[ret_ptr];
    assign ret_pc = pc_r[ret_ptr];
    assign ret_rdwen = rdwen_r[ret_ptr];
    assign ret_rdfpu = rdfpu_r[ret_ptr];

endmodule