`timescale 10 ns/ 1 ns

`define DATA_WIDTH 32

module shifter(
    input [`DATA_WIDTH - 1 : 0] A,
    input [              4 : 0] B,
    input [              1 : 0] Shiftop,
    output [`DATA_WIDTH - 1 : 0] Result
);
    // TODO: Please add your logic code here 
    assign Result = ({32{{Shiftop == 2'b00}}} & ( A << B[4 : 0] ) ) |  
                    ({32{{Shiftop == 2'b11}}} & ( (A >> B[4 : 0]) ^ ({32{A[31]}} << (6'd32-B[4 : 0]) ) )) |
                    ({32{{Shiftop == 2'b10}}} & ( A >> B[4 : 0] ) );                   
endmodule