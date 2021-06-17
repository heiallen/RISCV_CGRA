`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/06/07 23:56:33
// Design Name: 
// Module Name: sirv_gnrl_xchecker
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


module sirv_gnrl_xchecker # (parameter DW = 32)
(i_dat,clk);
input [DW-1:0] i_dat;
input clk;

always@(posedge clk)
    begin : CHECK_X_VALUE
        if((^i_dat) != 1'bx)
            begin
            end
        else
            begin
                $display("Error: detect a X value! \n");
                $finish;
            end
            
    end


endmodule
