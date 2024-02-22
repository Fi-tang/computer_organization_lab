**写在最前**
本分支在 P2 分支上进行了改进，由理想内存的设置变成真实内存、外设与性能计数器访问。
设计的处理器与真实内存交互。
从硬件角度：

改进了基于Ideal memory 的处理器，能够访问真实的内存通路。内存访问接口的时序逻辑基于握手机制。

从软件角度：
改进处理器访存接口后，实现了简单的 I/O 外设访问，能够支持字符串打印。

从硬件 + 软件的角度，增加性能计数器，对于复杂的 benchmark 进行性能测评。

一共有四个访存通道: 指令请求发送/指令应答接收/数据请求发送/数据应答接收， 每个通道增加了 Valid-Ready
的握手信号。

Valid: 高电平表示发送方发出的请求或者应答内容有效。

Ready: 高电平表示接收方可以接收发送方的请求或应答。

握手机制中需要的指令信号如下所示:
![real_memory](https://github.com/Fi-tang/computer_organization_lab/blob/P3_Custom_MIPS_functional_processors/real_memory.PNG)

此外，本次实验将 P2 的单周期处理器修改为 多周期处理器，需要处理多周期访存的接口时序。
例如在处理器请求发送时序时， 在等待接收方 Ready 拉高时，相应的请求信号(Valid + 指令或数据地址 + 写数据 + 读/写控制信号) 的输出值需要始终有效。
当接收端 Ready 在任一时刻有效后， Ready-Valid 同时拉高(握手成功）的第一个时钟上升沿，才能释放对应通道的请求信号。

多周期处理器的状态转移图如下所示:
![state_change](https://github.com/Fi-tang/computer_organization_lab/blob/P3_Custom_MIPS_functional_processors/state_change.PNG)

在编写 Verilog 时，使用三段式状态机描述的标准语法。

具体的代码内容，主要参考 **multi_cycle.v** 文件。
可以先从 第 695 行，观察整个状态的转换，定义了 current_state 和 next_state 两个变量，对于之前提到了处理器的取指(IF), 译码(ID), 执行(EXE), 访存(MEM), 写回(WB)，
对不同的指令而言，有的指令需要经过完整的 5 步结束，有的指令可能只涉及 IF, ID, EXE, WB 不需要访存，
对于一些简单的跳转指令，或许不需要经过 EXE, 只有 IF, ID 两个步骤。
所以在695 行开头的三段式状态机中，需要对每一个处理器执行阶段，严格判断其下一个状态，从而赋予不同的使能信号。
两个需要关注的时序逻辑，分别是第 45 行的状态赋值，以及 第 58 行的 PC 赋值，其余的 assign 语句与单周期的处理有相似之处。
