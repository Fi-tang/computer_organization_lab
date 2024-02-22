**写在最前**
**single_cycle** 文件夹下的**单周期**文件夹下是本次编写的代码。


实验希望实现基于理想内存(Ideal Memory)的简单功能型处理器数据通路和控制单元。

这里需要充分区分处理器的取指(Instruction Fetch), 译码(Instruction Decoder), 执行(Execution),
访存(Memory Access), 和写回(Write Back) 这五个阶段。
具体的结构图如下所示:

![single_cycle_structure](https://github.com/Fi-tang/computer_organization_lab/blob/P2_Single_cycle_MIPS_processors_ideal_memory/MIPS_structure.PNG)

ALU 和通用寄存器堆(Registers) 复用了实验1种的设计，
PC作为寄存器(时序电路），复位时，需要将其设置为32bit的0，即 32'd0
一共需要支持45条 MIPS 指令，
包括运算类的 14 条指令，移位类的 6 条指令，跳转类的 10 条指令，访存类的 12 条指令，以及 3 条数据移动及立即数指令。

每个阶段需要对控制信号进行分别赋值。
例如译码(ID)阶段的寄存器堆读取地址选择，执行(EX)阶段 ALU 操作数，ALUop的选择，地址计算部件的选择。
内存访问(MEM)阶段的内存读/写使能，读写地址选择，写数据选择，写回(WB)阶段的寄存器堆写地址与写数据选择，写使能 wen, 以及 PC 寄存器更新时，目标PC值的选择。

这里专门列了一个 excel 表格，分析 45 条 MIPS 指令具体该如何译码，对每一条指令，分别列出
1. 指令格式
2. 涉及寄存器堆读的哪些位(raddr1, raddr2)
3. ALU 操作数A和B的值从哪里得到
4. 内存访问的地址
5. 内存读取的信号（按照byte, half word, word 等大小进行读取)
6. 内存写入的信号
7. 内存写入的数据
8. 内存写信号的控制
9. 是否存在跳转地址，以及地址更新条件
10. 寄存器堆写相关的 wen, waddr, wdata
11. 移位器相关的 A, B, Shiftop
12. PC 更新的值
    
按12 类进行指令的译码和分析，主体的 **single_cycle** 下的单周期子文件中，**simple_cpu.v** 是主要的赋值代码，
从代码逻辑看，每个时序信号来临时，判断是否为复位信号，如果复位，则 PC <= 32'd0, 否则 PC 会更新为新的值，
这个新的值来自上一轮对于指令的判断，同时根据本轮得到的 PC, 进行相应的指令译码，执行，访存，写回等步骤。
最终在云平台上，能够完成类似水仙花数这样的小程序执行。
