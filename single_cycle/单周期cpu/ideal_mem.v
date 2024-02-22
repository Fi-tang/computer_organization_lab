`timescale  10 ns / 1 ns

module ideal_mem #(
    parameter  ADDR_WIDTH = 14 ;
    parameter MEM_WIDTH = 2 ** (ADDR_WIDTH -2)
)(
    input       clk,

    input [ADDR_WIDTH - 3 : 0] Waddr, // 内存写地址
    input [ADDR_WIDTH - 3 : 0] Raddr1, // 读端口 1
    input [ADDR_WIDTH - 3 : 0] Raddr2, // 读端口 2

    input       Wren,   // 写使能
    input       Rden1,  // 端口 1 读使能
    input       Rden2,  // 端口 2 读使能

    input [31 : 0]  Wdata, // 内存写数据
    input [3 : 0]   Wstrb, // 写有效
    output [31 : 0] Rdata1, // 内存读数据 1 
    output [31 : 0] Rdata2, // 内存读数据 2 
);

reg [31: 0]     mem[MEM_WIDTH - 1 : 0];

// 初始化仿真中的内存内容
reg [4095 : 0] initmem_f;
initial 
begin
    if($value$plusargs("INITMEM=%s",initmem_f))
        $readmem(initmem_f,mem);    
end

wire [7:0]  byte_0;
wire [7:0]  byte_1;
wire [7:0]  byte_2;
wire [7:0]  byte_3;

// 如果写使能有效，则该8-bit数据就是需要写入的数据，否则就是需要写入地址上的原数据
assign byte_0 = Wstrb[0] ? Wdata[7 : 0]  : mem[Waddr][7:0];
assign byte_1 = Wstrb[1] ? Wdata[15: 8]  : mem[Waddr][15:8];
assign byte_2 = Wstrb[2] ? Wdata[23: 16] : mem[Waddr][23:16];
assign byte_3 = Wstrb[3] ? Wdata[31: 24] : mem[Waddr][31:24];

always @ (posedge clk)
begin
    if(Wren)
        mem[Waddr] <= {byte_3,byte_2,byte_1,byte_0};
end

assign Rdata1 = {32{Rden1}} & mem[Raddr1];
assign Rdata2 = {32{Rden2}} & mem[Raddr2];

endmodule