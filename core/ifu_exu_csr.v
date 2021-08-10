`include "defines.v"

module exu_csr(clk, rst_n, clk_aon,
    nonflush_cmt_ena, csr_ena, csr_wr_en, csr_rd_en,
    ext_irq_r, sft_irq_r, tmr_irq_r,
    dbg_mode, dbg_stopcycle, cmt_badaddr_ena, cmt_epc_ena, cmt_cause_ena, cmt_status_ena, cmt_instret_ena, cmt_mret_ena,
    csr_idx, wbck_csr_dat, core_mhartid, dcsr_r, dpc_r, dscratch_r, cmt_badaddr, cmt_epc, cmt_cause,
    eai_xs_off, csr_access_ilgl, tm_stop, core_cgstop, tcm_cgstop, itcm_nohold, mdv_nob2b, status_mie_r, mtie_r, msie_r, meie_r,
    wr_dcsr_ena, wr_dpc_ena, wr_dscratch_ena, 
    u_mode, s_mode, h_mode, m_mode,
    read_csr_dat, wr_csr_nxt, csr_epc_r, csr_dpc_r, csr_mtvec_r
    );
    input clk, rst_n, clk_aon;
    input nonflush_cmt_ena, csr_ena, csr_wr_en, csr_rd_en;
        //外部中断请求、软中断请求、定时器中断请求
    input ext_irq_r, sft_irq_r, tmr_irq_r;
    input dbg_mode, dbg_stopcycle;
    input cmt_badaddr_ena, cmt_epc_ena, cmt_cause_ena, cmt_status_ena, cmt_instret_ena, cmt_mret_ena;
    input [12-1:0] csr_idx;
    input [`E203_XLEN-1:0] wbck_csr_dat;
    input [`E203_HART_ID_W-1:0] core_mhartid;
    input [`E203_XLEN-1:0] dcsr_r;
    input [`E203_PC_SIZE-1:0] dpc_r;
    input [`E203_XLEN-1:0] dscratch_r;
    input [`E203_ADDR_SIZE-1:0] cmt_badaddr;
    input [`E203_PC_SIZE-1:0] cmt_epc;
    input [`E203_XLEN-1:0] cmt_cause;
        //协处理器eai
    output eai_xs_off, csr_access_ilgl, tm_stop, core_cgstop, tcm_cgstop, itcm_nohold, mdv_nob2b;
    output status_mie_r, mtie_r, msie_r, meie_r, wr_dcsr_ena, wr_dpc_ena, wr_dscratch_ena;
    output u_mode, s_mode, h_mode, m_mode;
    output [`E203_XLEN-1:0] read_csr_dat;
    output [`E203_XLEN-1:0] wr_csr_nxt;
    output [`E203_PC_SIZE-1:0] csr_epc_r;
    output [`E203_PC_SIZE-1:0] csr_dpc_r;
    output [`E203_XLEN-1:0] csr_mtvec_r;

    assign csr_access_ilgl = 1'b0;
    wire wbck_csr_ena = csr_ena & csr_wr_en & (~csr_access_ilgl);
    wire read_csr_ena = csr_ena & csr_rd_en & (~csr_access_ilgl);

    wire [1:0] priv_mode = u_mode ? 2'b00:
                            s_mode ? 2'b01:
                            h_mode ? 2'b10:
                            m_mode ? 2'b11:
                                    2'b11;

    wire sel_ustatus = (csr_idx == 12'h000);
    wire sel_mstatus = (csr_idx == 12'h300);

    wire rd_ustatus = sel_ustatus & csr_rd_en;
    wire rd_mstatus = sel_mstatus & csr_rd_en;
    wire wr_ustatus = sel_ustatus & csr_wr_en;
    wire wr_mstatus = sel_mstatus & csr_wr_en;

    ////////////////////////////////////////////////////////////////
    ////the below implementation only apply to Machine-mode config

    // implement MPIE field
    wire status_mpie_r;
    wire status_mpie_ena = (wr_mstatus & wbck_csr_ena) | cmt_mret_ena | cmt_status_ena;

    

endmodule

    