**写在最前**
**guidebook** 文件夹下，主要是介绍计算机组成原理的实验平台，以及 Verilog 组合逻辑的基础语法，
使用 assign 语句对输出信号赋值，使用 always 块对reg型变量赋值(always块内只能赋值 reg 型变量)，
使用 always 语句描述状态机的状态转换，以及 if 语句必须加上 else 分支，case 语句必须有 default 分支，否则会
生成锁存器(latch) 这一细节。
回顾了组合逻辑种译码器，选择器，加法器的写法。
**P1——ALU** 文件夹是本次实验的目标，编写一个算术逻辑单元ALU(Atirhmetic Logic Unit)
一个32位的加法器结构如下图所示:

![32-bit_adder](https://github.com/Fi-tang/computer_organization_lab/blob/P1_ALU/P1_ALU/32bit_alu.PNG)

本次需要完成了 ALU 逻辑结构如下所示:

![ALU_structure](https://github.com/Fi-tang/computer_organization_lab/blob/P1_ALU/P1_ALU/alu.PNG)

实际上本次的任务在于，对于 add/sub/and/or/beq/slt 这6 条输入 ALU 的指令而言，
假设现在给定两个32bit的操作数 a 和 b, 在分别传递不同的 ALU operation 值时，
输出端的 32bit Result, 以及进位 Zero 和 Overflow 溢出位分别应该设置成多少。
具体的设计思路可以参考 **P1_ALU** 文件下的 prj1.pdf 实验报告。
