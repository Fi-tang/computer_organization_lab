// 使用 one-hot 编码定义状态机的状态
localparam  INIT = 9'b000000001,
            BYPASS = 9'b000000010,
            TAG_RD = 9'b000000100,
            EVICT = 9'b000001000,
            MEM_RD = 9'b00010000,
            RECV = 9'b0001000000,
            REFILL = 9'b0010000000,
            RESP = 9'b0100000000,
            CACHE_RD = 9'b10000000;

// 定义状态机的现态和次态
    reg [ 8 : 0] current_state;
    reg [ 8 : 0] next_state;

// 状态机第一段描述状态机的时序逻辑
always @(posedge clk)
begin
  if(rst == 1'b1)
    current_state <= INIT;
  else
    current_state <= next_state;
end
// 状态机第二段描述次态的计算组合逻辑
always @(*)
begin
    case(current_state)
        INIT : begin
            if(~cache_op_req_valid & (|cache_op_sel))
                next_state = DISPATCH;
            else
                next_state = INIT;
        end

        DISPATCH : begin
            if(cache_op_sel[1])
            begin
                if(cache_res[HIT_BIT] & cache_op_req[32]) // write hit
                    next_state = UPDATE;
                else if(cache_res[HIT_BIT] & (~cache_op_req[32])) // read hit
                    next_state = RESP;
                else if(~cache_res[HIT_BIT] & cache_res[WB_BIT]) // write back
                    next_state = MEM_WR;
                else if(~cache_res[HIT_BIT] & (~cache_res[WB_BIT])) // read new line
                    next_state = MEM_RD;
                else
                    next_state = DISPATCH;
            end
        
        default:
            next_state = INIT;
    endcase
end
// 状态机第三段中时序逻辑电路描述方法
// 一个寄存器类型变量所有的赋值逻辑仅能出现在一个 always 块里
// 一个 always 块只对唯一一个寄存器类型变量进行描述
// 不同的赋值条件要互斥
    reg r;
    always @(posedge clk)
    begin
        if(条件1)
            r <= XXX;
        else if (条件2)
            r <= XXX;
        else if(条件 3)
            r <= XXX;
    end