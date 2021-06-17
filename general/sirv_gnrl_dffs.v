`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/06/07 23:26:01
// Design Name: 
// Module Name: sirv_gnrl_dffs
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module sirv_gnrl_dfflr # (
    parameter DW = 32   //ģ�����󣬶˿���ǰ��#���������ɹ��ⲿ���õĳ�������
) (lden,dnxt,qout,clk,rst_n);
input lden;
input   [DW-1:0] dnxt;
output  [DW-1:0] qout;
    
input clk,rst_n;
    
reg [DW-1:0] qout_r;
    
always@(posedge clk or negedge rst_n)
    begin : DFFLR_PROC
        if(rst_n == 1'b0)
            qout_r <= {DW{1'b1}};
        else if (lden == 1'b1)
            qout_r <= dnxt;
    end
    
assign qout = qout_r;

`ifndef FPGA_SOURCE
`ifndef DISABLE_ASSERTION
sirv_gnrl_xchecker # (.DW(1))
u_sirv_gnrl_xchecker(
    .i_dat(lden),
    .clk(clk)
);
`endif
`endif

endmodule


module sirv_gnrl_dffrs #(
    parameter DW = 32
)(
    input [DW-1:0] dnxt,
    output [DW-1:0] qout,

    input clk,
    input rst_n
);

reg [DW-1:0] qout_r;

always @(posedge clk or negedge rst_n) begin : DFFRS_PROC
    if(!rst_n)
        qout_r <= {DW{1'b1}};
    else
        qout_r <= dnxt;
end

assign qout = qout_r;


endmodule


/*
module sirv_gnrl_dfflr # (parameter DW = 32) (
    lden, dnxt, qout, clk, rst_n
);

input lden;
input [DW-1:0] dnxt;
output [DW-1:0] qout;

input  wire clk,rst_n;

reg [DW-1: 0] qout_r;

always @(posedge clk or negedge rst_n) 
begin : DFFLR_PROC
    if(rst_n == 1'b0)
        qout_r <= {DW{1'b0}};
    else if(lden == 1'b1)
        qout_r <= dnxt;
end

assign qout_r = qout_r;

`ifndef FPGA_SOURCE
`ifndef DISABLE_SV_ASSERTION
sirv_gnrl_xchecker # (.DW(1))
    u_sirv_gnrl_xchecker(
        .i_dat(lden),
        .clk(clk)
    );
`endif 
`endif
    
endmodule

*/
