**写在最前**
本次实验的思路与总结，可以参考 **prj4.pdf**， 具体实现在 **RISC_V.v** 中。
本分支的目的是：实现定制 RISC-V 功能型处理器设计。
P3 分支中，已经实现过基于 MIPS 32 位指令集中45条指令的多周期处理器设计，本次重点在于了解 RISC-V 32-bit 
整型指令集，完成支持 37 条基本指令的 RISC-V 处理器设计。

与 MIPS 相比，RISC-V中增加了 B-Type, U-Type 等类型划分，指令的格式更加精简，在译码上更加容易。
RISC-V中取消了分支延迟槽的设计，因此对于 nop 指令并不做特殊区分，而是当作 addi 指令来处理。
RISC-V 处理器的状态机拆分了LD(内存读)和 ST(内存写)状态，以及指令等待(IW)和读数据等待(RDW)， 
load 和 store 类型的指令分别有不同的 Address, 需要在两阶段都对 Address 进行赋值。

处理器状态机如下所示:
![state_change](https://github.com/Fi-tang/computer_organization_lab/blob/P4_Custom_RISC_V_functional_processors/state_change.PNG)

在 **RISC_V.v** 的代码中，同样可以先从第 676 行的状态转换的时序逻辑开始看起，大致的思路与 P3 类似，
在指令集的译码和状态划分上有一些区别。
