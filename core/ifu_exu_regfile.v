`include "defines.v"

module exu_regfile (clk, rst_n, test_mode,
    read_src1_idx, read_src2_idx, wbck_dest_wen, wbck_dest_idx, wbck_dest_dat,
    read_src1_dat, read_src2_dat, x1_r
);
input clk, rst_n;
input test_mode;
input wbck_dest_wen;
input [`E203_RFIDX_WIDTH-1:0] read_src1_idx, read_src2_idx;
input [`E203_RFIDX_WIDTH-1:0] wbck_dest_idx;
input [`E203_XLEN-1:0] wbck_dest_dat;
output [`E203_XLEN-1:0] read_src1_dat;
output [`E203_XLEN-1:0] read_src2_dat;
output [`E203_XLEN-1:0] x1_r;

wire [`E203_XLEN-1:0] rf_r [`E203_RFREG_NUM-1:0];
wire [`E203_RFREG_NUM-1:0] rf_wen;

genvar i;
generate
    for(i=0;i<`E203_RFREG_NUM-1;i=i+1)
        begin:regfile
            if(i==0) begin:rf0
                assign rf_wen[i] = 1'b0;
                assign rf_r[i] = `E203_XLEN'b0;
            end
            else begin:rfno0
                assign rf_wen[i] = wbck_dest_wen & (wbck_dest_idx == i);
                sirv_gnrl_dfflr #(`E203_XLEN) rf_dfflr (rf_wen[i],wbck_dest_dat,rf_r[i],clk,rst_n);
            end
        end
endgenerate

assign read_src1_dat = rf_r[read_src1_idx];
assign read_src2_dat = rf_r[read_src2_idx];



    
endmodule