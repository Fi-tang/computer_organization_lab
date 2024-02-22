`define DATA_WIDTH 32

module alu(
    input [`DATA_WIDTH - 1 : 0] A,
    input [`DATA_WIDTH - 1 : 0] B,
    input [              2 : 0] ALUop,
    output  Overflow,
    output  CarryOut,
    output Zero,
    output [`DATA_WIDTH - 1 : 0] Result
);

    //构造一个加减法使能信号
    wire cin,cout,enable;
    assign enable = ({ALUop == 3'b010} & 0 ) |
                    ({ALUop == 3'b110 } & 1) |
                    ({ALUop == 3'b011 } & 1) |
                    ({ALUop == 3'b111} & 1);
    wire [`DATA_WIDTH - 1 : 0] Result_prev;
    wire [`DATA_WIDTH : 0] B1;
    assign B1 = enable? ~B:B;
    assign cin = enable? 1:0;
    assign {cout,Result_prev} = A + B1 + cin;

    wire [`DATA_WIDTH : 0] A_1;
    wire [`DATA_WIDTH : 0] B_1;

    assign A_1 = {1'b0,A};
    assign B_1 = {1'b0,B};

    wire [`DATA_WIDTH: 0] Result_1;
    assign Result_1 = A_1 + ~B_1 + 1;

    assign Result = ( {32{ALUop == 3'b000}} & (A & B)    ) |
                    ( {32{ALUop == 3'b001}} & (A | B)    ) |
                    ( {32{ALUop == 3'b100}} & (A ^ B)   ) |
                    ( {32{ALUop == 3'b101}} & ((~A) &(~B) )  ) |
                    ( {32{ALUop == 3'b010}} & (Result_prev)    ) |
                    ( {32{ALUop == 3'b110}} &  (Result_prev) ) |
                    ( {32{ALUop == 3'b111}} & (Result_prev[31] ^ Overflow) ) |
                    ( {32{ALUop == 3'b011}} & (Result_1[32]) );


    assign CarryOut = ( {ALUop == 3'b010} & cout) |
                      (  {ALUop == 3'b110} & cout);
    assign Overflow =   ( {ALUop == 3'b010} & ((~A[31] & ~B[31] & Result_prev[31]) | (A[31] & B[31] & ~Result_prev[31]) )    ) |
                        ( {ALUop == 3'b110} &  (  (~A[31] & B[31] & Result_prev[31])    | (A[31] & ~B[31] & ~Result_prev[31]) ) ) |
                        ( {ALUop == 3'b111} & (  (~A[31] & B[31] & Result_prev[31])    | (A[31] & ~B[31] & ~Result_prev[31])) );
    assign Zero = (Result==32'b0)? 1 : 0;
endmodule