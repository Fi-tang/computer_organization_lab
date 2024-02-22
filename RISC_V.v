`timescale 10ns / 1ns

module custom_cpu(
	input         clk,
	input         rst,

	//Instruction request channel
	output [31:0] PC,
	output        Inst_Req_Valid,
	input         Inst_Req_Ready,

	//Instruction response channel
	input  [31:0] Instruction,
	input         Inst_Valid,
	output        Inst_Ready,

	//Memory request channel
	output [31:0] Address,
	output        MemWrite,
	output [31:0] Write_data,
	output [ 3:0] Write_strb,
	output        MemRead,
	input         Mem_Req_Ready,

	//Memory data response channel
	input  [31:0] Read_data,
	input         Read_data_Valid,
	output        Read_data_Ready,

	input         intr,

	output [31:0] cpu_perf_cnt_0,
	output [31:0] cpu_perf_cnt_1,
	output [31:0] cpu_perf_cnt_2,
	output [31:0] cpu_perf_cnt_3,
	output [31:0] cpu_perf_cnt_4,
	output [31:0] cpu_perf_cnt_5,
	output [31:0] cpu_perf_cnt_6,
	output [31:0] cpu_perf_cnt_7,
	output [31:0] cpu_perf_cnt_8,
	output [31:0] cpu_perf_cnt_9,
	output [31:0] cpu_perf_cnt_10,
	output [31:0] cpu_perf_cnt_11,
	output [31:0] cpu_perf_cnt_12,
	output [31:0] cpu_perf_cnt_13,
	output [31:0] cpu_perf_cnt_14,
	output [31:0] cpu_perf_cnt_15,

	output [69:0] inst_retire
);

/* The following signal is leveraged for behavioral simulation, 
* which is delivered to testbench.
*
* STUDENTS MUST CONTROL LOGICAL BEHAVIORS of THIS SIGNAL.
*
* inst_retired (70-bit): detailed information of the retired instruction,
* mainly including (in order) 
* { 
*   reg_file write-back enable  (69:69,  1-bit),
*   reg_file write-back address (68:64,  5-bit), 
*   reg_file write-back data    (63:32, 32-bit),  
*   retired PC                  (31: 0, 32-bit)
* }
*
*/
    wire [69:0] inst_retire;
    localparam  INIT = 9'b000000001,
                  IF = 9'b000000010,
                  IW = 9'b000000100,
                  ID = 9'b000001000,
                EXE =  9'b000010000,
                 WB =  9'b000100000,
                 ST =  9'b001000000,
                 LD =  9'b010000000,
                RDW =  9'b100000000;
    
    reg [8 : 0] current_state;
    reg [8 : 0] next_state;
    always@(posedge clk)begin
        if(rst)
            current_state <= INIT;
        else
            current_state <= next_state;
    end

    assign Inst_Req_Valid = (current_state == IF );
    assign Inst_Ready = (current_state == IW || current_state == INIT);
    assign MemRead = (current_state == LD);
    assign MemWrite = (current_state == ST);
    assign Read_data_Ready = (current_state == RDW || current_state == INIT);

 // INIT
    wire RF_wen;
    wire [4 : 0] RF_waddr; 
    wire [31 : 0] RF_wdata;
    wire [4 : 0] RF_raddr1;
    wire [4 : 0] RF_raddr2;
    wire [31 : 0] RF_rdata1;
    wire [31 : 0] RF_rdata2;

    reg_file RF(
        .clk(clk),
        .waddr(RF_waddr),
        .raddr1(RF_raddr1),
        .raddr2(RF_raddr2),
        .wen(RF_wen),
        .wdata(RF_wdata),
        .rdata1(RF_rdata1),
        .rdata2(RF_rdata2));
// IF
    reg [31 : 0] cpu_PC;
    wire [31 : 0] cpu_PC_next;
    wire cpu_PC_next_enable;

    always@(posedge clk)begin
        if(rst)
            cpu_PC <= 32'b0;
        else if(current_state == IF && next_state == IW)
            cpu_PC <= cpu_PC + 4;
        else if(current_state == EXE && cpu_PC_next_enable)
            cpu_PC <= cpu_PC_next;
        else
            cpu_PC <= cpu_PC;
    end

    assign PC = cpu_PC;
// IW

    reg [31 : 0] IW_ID_Instruction;
    reg [31 : 0] IW_ID_cpu_PC;
    always@(posedge clk)begin
        IW_ID_Instruction <= Instruction;
        IW_ID_cpu_PC <= cpu_PC;
    end


// ID
    wire [6 : 0] R_func7;
    wire [4 : 0] rs2;
    wire [4 : 0] rs1;
    wire [4 : 0] rd;
    wire [2 : 0] func3;
    wire [6 : 0] Opcode;
  
    wire [11 : 0] I_Immediate;
    wire [11 : 0] S_Immediate;
    wire [12 : 0] B_Immediate;
    wire [19 : 0] U_Immediate;
    wire [20 : 0] J_Immediate;

    assign I_Immediate = IW_ID_Instruction[31 : 20];
    assign S_Immediate = {IW_ID_Instruction[31 : 25], IW_ID_Instruction[11 : 7]};
    assign B_Immediate = {IW_ID_Instruction[31], IW_ID_Instruction[7], IW_ID_Instruction[30 : 25], IW_ID_Instruction[11 : 8],1'b0};
    assign U_Immediate = IW_ID_Instruction[31 : 12];
    assign J_Immediate = {IW_ID_Instruction[31], IW_ID_Instruction[19 : 12], IW_ID_Instruction[20], IW_ID_Instruction[30 : 21], 1'b0};

    wire [4 : 0] shamt;

    assign R_func7 = IW_ID_Instruction[31 : 25];
    assign rs2 = IW_ID_Instruction[24 : 20];
    assign rs1 = IW_ID_Instruction[19 : 15];
    assign func3 = IW_ID_Instruction[14 : 12];
    assign rd = IW_ID_Instruction[11 : 7];
    assign Opcode = IW_ID_Instruction[6 : 0];

    assign shamt = IW_ID_Instruction[24 : 20];

    wire R_Type_judge;
    wire I_Type_Compute_judge;
    wire U_Type_judge;
    wire J_Type_judge;
    wire I_Type_jump_judge;
    wire B_Type_judge;
    wire I_Type_load_judge;
    wire S_Type_judge;
    wire NOP_judge;

    assign R_Type_judge = (Opcode == 7'b0110011);
    assign I_Type_Compute_judge = (Opcode == 7'b0010011);
    assign U_Type_judge = (Opcode == 7'b0110111 || Opcode == 7'b0010111);
    assign J_Type_judge = (Opcode == 7'b1101111);
    assign I_Type_jump_judge = (Opcode == 7'b1100111);
    assign B_Type_judge = (Opcode == 7'b1100011);
    assign I_Type_load_judge = (Opcode == 7'b0000011);
    assign S_Type_judge = (Opcode == 7'b0100011);
    assign NOP_judge = (I_Immediate == 12'b0 && rs1 == 5'b0 && func3 == 3'b0 && rd == 5'b0 && I_Type_Compute_judge);

    assign RF_raddr1 = rs1;
    assign RF_raddr2 = rs2;

    wire [31 : 0] cpu_alu_A;
    wire [31 : 0] cpu_alu_B;
    wire [2 : 0] cpu_ALUop;

    /*R-Type */
    wire RISC_add;
    wire RISC_sub;
    wire RISC_and;
    wire RISC_or;
    wire RISC_xor;
    wire RISC_slt;
    wire RISC_sltu;
    wire RISC_sll;
    wire RISC_srl;
    wire RISC_sra;

    assign RISC_add = (R_Type_judge && R_func7 == 7'b0 && func3 == 3'b0);
    assign RISC_sub = (R_Type_judge && R_func7 == 7'b0100000 && func3 == 3'b0);
    assign RISC_and = (R_Type_judge && func3 == 3'b111);
    assign RISC_or = (R_Type_judge && func3 == 3'b110);
    assign RISC_xor = (R_Type_judge && func3 == 3'b100);
    assign RISC_slt = (R_Type_judge && func3 == 3'b010);
    assign RISC_sltu = (R_Type_judge && func3 == 3'b011);
    assign RISC_sll = (R_Type_judge && func3 == 3'b001);
    assign RISC_srl = (R_Type_judge && R_func7 == 7'b0 && func3 == 3'b101);
    assign RISC_sra = (R_Type_judge && R_func7 == 7'b0100000 && func3 == 3'b101);

    /* I_Type cpmpute */
    wire RISC_addi;
    wire RISC_andi;
    wire RISC_ori;
    wire RISC_xori;
    wire RISC_slti;
    wire RISC_sltiu;
    wire RISC_slli;
    wire RISC_srli;
    wire RISC_srai;
    wire RISC_nop;

    assign RISC_addi = (I_Type_Compute_judge && func3 == 3'b0);
    assign RISC_andi = (I_Type_Compute_judge && func3 == 3'b111);
    assign RISC_ori = (I_Type_Compute_judge && func3 == 3'b110);
    assign RISC_xori = (I_Type_Compute_judge && func3 == 3'b100);
    assign RISC_slti = (I_Type_Compute_judge && func3 == 3'b010);
    assign RISC_sltiu = (I_Type_Compute_judge && func3 == 3'b011);
    assign RISC_slli = (I_Type_Compute_judge && func3 == 3'b001);
    assign RISC_srli = (I_Type_Compute_judge && func3 == 3'b101 && R_func7 == 7'b0);
    assign RISC_srai = (I_Type_Compute_judge && func3 == 3'b101 && R_func7 == 7'b0100000);
    assign RISC_nop = NOP_judge;

    /* U-Type */
    wire RISC_lui;
    wire RISC_auipc;

    assign RISC_lui = (U_Type_judge && Opcode == 7'b0110111);
    assign RISC_auipc = (U_Type_judge && Opcode == 7'b0010111);

    /* J-Type */
    wire RISC_jal;
    assign RISC_jal = J_Type_judge;

    /* I-Type-jump */
    wire RISC_jalr;
    assign RISC_jalr = I_Type_jump_judge;

    /*B-Type */
    wire RISC_beq;
    wire RISC_bne;
    wire RISC_blt;
    wire RISC_bltu;
    wire RISC_bge;
    wire RISC_bgeu;

    assign RISC_beq = (B_Type_judge && func3 == 3'b0);
    assign RISC_bne = (B_Type_judge && func3 == 3'b001);
    assign RISC_blt = (B_Type_judge && func3 == 3'b100);
    assign RISC_bltu = (B_Type_judge && func3 == 3'b110);
    assign RISC_bge = (B_Type_judge && func3 == 3'b101);
    assign RISC_bgeu = (B_Type_judge && func3 == 3'b111);

    /* I-Type-load */
    wire RISC_lb;
    wire RISC_lh;
    wire RISC_lw;
    wire RISC_lbu;
    wire RISC_lhu;

    assign RISC_lb = (I_Type_load_judge && func3 == 3'b0);
    assign RISC_lh = (I_Type_load_judge && func3 == 3'b001);
    assign RISC_lw = (I_Type_load_judge && func3 == 3'b010);
    assign RISC_lbu = (I_Type_load_judge && func3 == 3'b100);
    assign RISC_lhu = (I_Type_load_judge && func3 == 3'b101);

    /* S-Type */
    wire RISC_sb;
    wire RISC_sh;
    wire RISC_sw;

    assign RISC_sb = (S_Type_judge && func3 == 3'b0);
    assign RISC_sh = (S_Type_judge && func3 == 3'b001);
    assign RISC_sw = (S_Type_judge && func3 == 3'b010);

    assign cpu_alu_A = ( {32{ R_Type_judge || I_Type_Compute_judge || B_Type_judge}} & RF_rdata1);

    wire [31 : 0] Sign_extend_I_immediate;
    wire [31 : 0] Sign_extend_U_immediate;
    wire [31 : 0] Sign_extend_J_immediate;
    wire [31 : 0] Sign_extend_B_immediate;
    wire [31 : 0] Sign_extend_S_immediate;
    
    assign Sign_extend_I_immediate = { {20{I_Immediate[11]}}, I_Immediate};
    assign Sign_extend_U_immediate = { {12{U_Immediate[19]}}, U_Immediate};
    assign Sign_extend_J_immediate = { {11{J_Immediate[20]}}, J_Immediate};
    assign Sign_extend_B_immediate = { {19{B_Immediate[12]}}, B_Immediate};
    assign Sign_extend_S_immediate = { {20{S_Immediate[11]}}, S_Immediate};

    assign cpu_alu_B = ({32{RISC_add || RISC_sub || RISC_and || RISC_or || RISC_xor || RISC_slt || RISC_sltu || B_Type_judge}} & RF_rdata2) |
                       ({32{RISC_addi || RISC_andi || RISC_ori || RISC_xori || RISC_slti || RISC_sltiu}} & Sign_extend_I_immediate);

    assign cpu_ALUop = ( {3{RISC_sub || B_Type_judge}} & 3'b110) |
                       ( {3{RISC_add || RISC_addi}} & 3'b010) |
                       ( {3{RISC_and || RISC_andi}} & 3'b000) |
                       ( {3{ RISC_or || RISC_ori}} & 3'b001) |
                       ( {3{ RISC_xor || RISC_xori}} & 3'b100) |
                       ( {3{ RISC_slt || RISC_slti}} & 3'b111) |
                       ( {3{ RISC_sltu || RISC_sltiu}} & 3'b011);
    
    wire [31 : 0] cpu_shifter_A;
    wire [4 : 0] cpu_shifter_B;
    wire [1 : 0] cpu_shifter_Shiftop;

    assign cpu_shifter_A = ({32{RISC_sll || RISC_srl || RISC_sra || RISC_slli || RISC_srli || RISC_srai}} & RF_rdata1 ) |
                           ({32{U_Type_judge}} & Sign_extend_U_immediate);
    
    assign cpu_shifter_B = ({5{RISC_sll || RISC_srl || RISC_sra}} & RF_rdata2[4 : 0]) |
                           ({5{RISC_slli || RISC_srli || RISC_srai}} & shamt) |
                           ({5{U_Type_judge}} & 5'b01100);

    assign cpu_shifter_Shiftop = ( {2{RISC_sll || RISC_slli || U_Type_judge }} & 2'b00 ) |
                                 ( {2{RISC_srl || RISC_srli}} & 2'b10) |
                                 ( {2{RISC_sra || RISC_srai}} & 2'b11);
    wire [31 : 0] cpu_PC_jump;
    wire [31 : 0] cpu_PC_R; // RISC_jalr
    wire [31 : 0] cpu_PC_branch;
    wire cpu_PC_jump_enable;
    wire cpu_PC_R_enable;

    assign cpu_PC_jump_enable = RISC_jal;
    assign cpu_PC_R_enable = RISC_jalr;

    assign cpu_PC_branch = IW_ID_cpu_PC + Sign_extend_B_immediate;
    assign cpu_PC_jump = IW_ID_cpu_PC + Sign_extend_J_immediate;
    assign cpu_PC_R = RF_rdata1 + Sign_extend_I_immediate;

    reg [31 : 0] ID_EXE_cpu_alu_A;
    reg [31 : 0] ID_EXE_cpu_alu_B;
    reg [2 : 0] ID_EXE_cpu_ALUop;
    reg [31 : 0] ID_EXE_cpu_shifter_A;
    reg [4 : 0] ID_EXE_cpu_shifter_B;
    reg [1 : 0] ID_EXE_cpu_shifter_Shiftop;
    reg [31 : 0] ID_EXE_cpu_PC_jump;
    reg [31 : 0] ID_EXE_cpu_PC_R;
    reg [31 : 0] ID_EXE_cpu_PC_branch;
    reg ID_EXE_cpu_PC_jump_enable;
    reg ID_EXE_cpu_PC_R_enable;
    reg [5 : 0] ID_EXE_cpu_PC_branch_enable;

    reg [31 : 0] ID_EXE_RF_rdata1;
    reg [31 : 0] ID_EXE_RF_rdata2;

    reg ID_EXE_Switch_WB;
    reg ID_EXE_Switch_IF;

    reg [31 : 0] ID_EXE_Sign_extend_I_immediate;
    reg [31 : 0] ID_EXE_Sign_extend_S_immediate;
    reg [4 : 0] ID_EXE_load;
    reg [2 : 0] ID_EXE_store;

    reg ID_EXE_RF_wen_1;
    reg ID_EXE_I_Type_Compute_judge;
    reg ID_EXE_U_Type_judge;
    reg ID_EXE_RISC_jal;
    reg ID_EXE_RISC_auipc;
    reg ID_EXE_I_Type_jump_judge;
    reg ID_EXE_store_Judge;
    reg ID_EXE_load_judge;

    reg [4 : 0] ID_EXE_rd;
    reg [31 : 0] ID_EXE_PC_add;

    reg ID_EXE_RF_wdata_1;
    reg ID_EXE_RF_wdata_2;

    always@(posedge clk)begin
        ID_EXE_cpu_alu_A <= cpu_alu_A;
        ID_EXE_cpu_alu_B <= cpu_alu_B;
        ID_EXE_cpu_ALUop <= cpu_ALUop;
        ID_EXE_cpu_shifter_A <= cpu_shifter_A;
        ID_EXE_cpu_shifter_B <= cpu_shifter_B;
        ID_EXE_cpu_shifter_Shiftop <= cpu_shifter_Shiftop;

        ID_EXE_cpu_PC_jump <= cpu_PC_jump;
        ID_EXE_cpu_PC_R <= cpu_PC_R;
        ID_EXE_cpu_PC_branch <= cpu_PC_branch;
        ID_EXE_cpu_PC_jump_enable <= cpu_PC_jump_enable;
        ID_EXE_cpu_PC_R_enable <= cpu_PC_R_enable;

        ID_EXE_cpu_PC_branch_enable <= {RISC_beq, RISC_bne, RISC_blt, RISC_bltu, RISC_bge, RISC_bgeu};

        ID_EXE_RF_rdata1 <= RF_rdata1;
        ID_EXE_RF_rdata2 <= RF_rdata2;

        ID_EXE_Switch_WB <= (R_Type_judge || I_Type_Compute_judge || U_Type_judge || J_Type_judge || I_Type_jump_judge);
        ID_EXE_Switch_IF <= (B_Type_judge);

        ID_EXE_Sign_extend_I_immediate <= Sign_extend_I_immediate;
        ID_EXE_Sign_extend_S_immediate <= Sign_extend_S_immediate;
        ID_EXE_load <= {RISC_lb, RISC_lh, RISC_lw, RISC_lbu, RISC_lhu};
        ID_EXE_store <= {RISC_sb, RISC_sh, RISC_sw};

        ID_EXE_RF_wen_1 <= R_Type_judge;
        ID_EXE_I_Type_Compute_judge <= I_Type_Compute_judge;
        ID_EXE_U_Type_judge <= U_Type_judge;
        ID_EXE_RISC_jal <= RISC_jal;
        ID_EXE_RISC_auipc <= RISC_auipc;
        ID_EXE_I_Type_jump_judge <= I_Type_jump_judge;
        ID_EXE_store_Judge <= S_Type_judge;
        ID_EXE_load_judge <= I_Type_load_judge;

        ID_EXE_rd <= rd;
        ID_EXE_PC_add <= IW_ID_cpu_PC;

        ID_EXE_RF_wdata_1 <= (RISC_add || RISC_sub || RISC_and || RISC_or || RISC_xor || RISC_slt || RISC_sltu || RISC_addi || RISC_andi || RISC_ori || RISC_xori || RISC_slti || RISC_sltiu);
        ID_EXE_RF_wdata_2 <= (RISC_sll || RISC_srl || RISC_sra || RISC_slli || RISC_srli || RISC_srai || RISC_lui);

    end

// EXE
    wire cpu_Overflow;
    wire cpu_CarryOut;
    wire cpu_Zero;
    wire [31 : 0] cpu_Result;

    alu cpu_alu(
        .A(ID_EXE_cpu_alu_A),
        .B(ID_EXE_cpu_alu_B),
        .ALUop(ID_EXE_cpu_ALUop),
        .Overflow(cpu_Overflow),
        .CarryOut(cpu_CarryOut),
        .Zero(cpu_Zero),
        .Result(cpu_Result)
    );

    wire cpu_PC_branch_enable;

    /*
    bne(不相等) , beq(相等), bgez(>= 0), bgtz(> 0), blez(<= 0), bltz(< 0) */
    assign cpu_PC_branch_enable = (ID_EXE_cpu_PC_branch_enable[5] && cpu_Zero ) ||
                                  (ID_EXE_cpu_PC_branch_enable[4] && ~cpu_Zero) ||
                                  (ID_EXE_cpu_PC_branch_enable[3] && (~cpu_Zero && (cpu_Result[31]^cpu_Overflow))) ||
                                  (ID_EXE_cpu_PC_branch_enable[2] && (~cpu_Zero && cpu_Result[31]) ) ||
                                  (ID_EXE_cpu_PC_branch_enable[1] && (cpu_Zero || !(cpu_Result[31] ^cpu_Overflow))) ||
                                  (ID_EXE_cpu_PC_branch_enable[0] && (cpu_Zero || !cpu_Result[31]));

    wire [31 : 0] cpu_shifter_Result;

    shifter cpu_shifter(
        .A(ID_EXE_cpu_shifter_A),
        .B(ID_EXE_cpu_shifter_B),
        .Shiftop(ID_EXE_cpu_shifter_Shiftop),
        .Result(cpu_shifter_Result)
    );

    assign cpu_PC_next = ( {32{current_state == EXE && cpu_PC_branch_enable}} & (ID_EXE_cpu_PC_branch - 4) ) |
                         ( {32{current_state == EXE && ID_EXE_cpu_PC_jump_enable}} & (ID_EXE_cpu_PC_jump - 4)) |
                         ( {32{current_state == EXE && ID_EXE_cpu_PC_R_enable}} & (ID_EXE_cpu_PC_R));
    assign cpu_PC_next_enable = (cpu_PC_branch_enable || ID_EXE_cpu_PC_jump_enable || ID_EXE_cpu_PC_R_enable);

    reg [31 : 0] EXE_LD_RF_rdata1;
    reg [31 : 0] EXE_LD_Sign_extend_I_immediate;
    reg [4 : 0] EXE_LD_load;
    reg EXE_LD_load_judge;
    reg [4 : 0] EXE_LD_rd;

    reg EXE_WB_RF_wen_1;
    reg EXE_WB_I_Type_Compute_judge;
    reg EXE_WB_U_Type_judge;
    reg EXE_WB_RISC_jal;
    reg EXE_WB_RISC_auipc;
    reg EXE_WB_I_Type_jump_judge;
    reg [4 : 0] EXE_WB_rd;
    reg [31 : 0] EXE_WB_PC_add;

    reg EXE_WB_RF_wdata_1;
    reg EXE_WB_RF_wdata_2;

    reg [31 : 0] EXE_WB_cpu_Result;
    reg [31 : 0] EXE_WB_cpu_shifter_Result;
    reg [31 : 0] EXE_WB_cpu_auipc;

    reg [31 : 0] EXE_ST_RF_rdata1;
    reg [31 : 0] EXE_ST_RF_rdata2;
    reg [31 : 0] EXE_ST_Sign_extend_S_immediate;
    reg [2 : 0] EXE_ST_store;

    always@ (posedge clk)begin
        if(current_state == IF)begin
            EXE_LD_RF_rdata1 <= 0;
            EXE_LD_Sign_extend_I_immediate <= 0;
            EXE_LD_load <= 0;
            EXE_LD_load_judge <= 0;
            EXE_LD_rd <= 0;

            EXE_WB_RF_wen_1 <= 0;
            EXE_WB_I_Type_Compute_judge <= 0;
            EXE_WB_U_Type_judge <= 0;
            EXE_WB_RISC_jal <= 0;
            EXE_WB_RISC_auipc <= 0;
            EXE_WB_I_Type_jump_judge <= 0;

            EXE_WB_rd <= 0;
            EXE_WB_PC_add <= 0;

            EXE_WB_RF_wdata_1 <= 0;
            EXE_WB_RF_wdata_2 <= 0;
            
            EXE_WB_cpu_Result <= 0;
            EXE_WB_cpu_shifter_Result <= 0;
            EXE_WB_cpu_auipc <= 0;

            EXE_ST_RF_rdata1 <= 0;
            EXE_ST_RF_rdata2 <= 0;
            EXE_ST_Sign_extend_S_immediate <= 0;
            EXE_ST_store <= 0;
        end
        else if(current_state == EXE && next_state != EXE)begin
            EXE_LD_RF_rdata1 <= ID_EXE_RF_rdata1;
            EXE_LD_Sign_extend_I_immediate <= ID_EXE_Sign_extend_I_immediate;
            EXE_LD_load <= ID_EXE_load;
            EXE_LD_load_judge <= ID_EXE_load_judge;
            EXE_LD_rd <= ID_EXE_rd;

            EXE_WB_RF_wen_1 <= ID_EXE_RF_wen_1;
            EXE_WB_I_Type_Compute_judge <= ID_EXE_I_Type_Compute_judge;
            EXE_WB_U_Type_judge <= ID_EXE_U_Type_judge;
            EXE_WB_RISC_jal <= ID_EXE_RISC_jal;
            EXE_WB_RISC_auipc <= ID_EXE_RISC_auipc;
            EXE_WB_I_Type_jump_judge <= ID_EXE_I_Type_jump_judge;

            EXE_WB_rd <= ID_EXE_rd;
            EXE_WB_PC_add <= ID_EXE_PC_add;

            EXE_WB_RF_wdata_1 <= ID_EXE_RF_wdata_1;
            EXE_WB_RF_wdata_2 <= ID_EXE_RF_wdata_2;
            
            EXE_WB_cpu_Result <= cpu_Result;
            EXE_WB_cpu_shifter_Result <= cpu_shifter_Result;
            EXE_WB_cpu_auipc <= cpu_shifter_Result + ID_EXE_PC_add;

            EXE_ST_RF_rdata1 <= ID_EXE_RF_rdata1;
            EXE_ST_RF_rdata2 <= ID_EXE_RF_rdata2;
            EXE_ST_Sign_extend_S_immediate <= ID_EXE_Sign_extend_S_immediate;
            EXE_ST_store <= ID_EXE_store;
        end
    end

// LD
    wire [31 : 0] Address_real;
    assign Address_real = ( {32{current_state == LD}} & (EXE_LD_RF_rdata1 + EXE_LD_Sign_extend_I_immediate));

    reg [31 : 0] LD_RDW_Address_real;
    reg [4 : 0] LD_RDW_load;
    reg LD_RDW_load_judge;
    reg [4 : 0] LD_RDW_rd;

    always@(posedge clk)begin
        if(current_state == IF)begin
            LD_RDW_Address_real <= 0;
            LD_RDW_load <= 0;
            LD_RDW_load_judge <= 0;
            LD_RDW_rd <= 0;
        end
        else if(current_state == LD && next_state != LD)begin
            LD_RDW_Address_real <= Address_real;
            LD_RDW_load <= EXE_LD_load;
            LD_RDW_load_judge <= EXE_LD_load_judge;
            LD_RDW_rd <= EXE_LD_rd;
        end
    end

// RDW
    wire [7 : 0] load_byte;
    assign load_byte = ({8{LD_RDW_Address_real[1 : 0] == 2'b00}} & Read_data[7 : 0]) |
                       ({8{LD_RDW_Address_real[1 : 0] == 2'b01}} & Read_data[15 : 8]) |
                       ({8{LD_RDW_Address_real[1 : 0] == 2'b10}} & Read_data[23 : 16]) |
                       ({8{LD_RDW_Address_real[1 : 0] == 2'b11}} & Read_data[31 : 24]);
    wire [31 : 0] load_wdata_byte;
    assign load_wdata_byte =  ({32{LD_RDW_load[4]}} & {{24{load_byte[7]}}, load_byte} ) |
                              ({32{LD_RDW_load[1]}} & { {24{1'b0}}, load_byte });

    wire [15 : 0] load_halfword;
    assign load_halfword = ({16{LD_RDW_Address_real[1 : 0] == 2'b00}} & Read_data[15 : 0]) |
                           ({16{LD_RDW_Address_real[1 : 0] == 2'b10}} & Read_data[31 : 16]);
    wire [31 : 0] load_wdata_halfword;
    assign load_wdata_halfword = ({32{LD_RDW_load[3]}} & {{16{load_halfword[15]}} , load_halfword}) |
                                 ({32{LD_RDW_load[0]}} & {{16{1'b0}}, load_halfword});
    wire [31 : 0] load_wdata_word;
    assign load_wdata_word = ({32{LD_RDW_load[2]}} & Read_data[31 : 0]);

    wire [31 : 0] RF_load;
    assign RF_load = ({32{LD_RDW_load[4] || LD_RDW_load[1]}} & load_wdata_byte ) |
                     ({32{LD_RDW_load[3] || LD_RDW_load[0]}} & load_wdata_halfword ) |
                     ({32{LD_RDW_load[2]}} & load_wdata_word);

    reg [31 : 0] RDW_WB_RF_load;
    reg RDW_WB_load_judge;
    reg [4 : 0] RDW_WB_rd;
    always@(posedge clk)begin
        if(current_state == IF)begin
            RDW_WB_RF_load <= 0;
            RDW_WB_load_judge <= 0;
            RDW_WB_rd <= 0;
        end
        else if(current_state == RDW && next_state != RDW)begin
            RDW_WB_RF_load <= RF_load;
            RDW_WB_load_judge <= LD_RDW_load_judge;
            RDW_WB_rd <= LD_RDW_rd;
        end
    end

// WB:
    assign RF_wen = (current_state == WB && EXE_WB_RF_wen_1) |
                    (current_state == WB && EXE_WB_I_Type_Compute_judge) |
                    (current_state == WB && EXE_WB_U_Type_judge) |
                    (current_state == WB && EXE_WB_RISC_jal) |
                    (current_state == WB && EXE_WB_I_Type_jump_judge) |
                    (current_state == WB && RDW_WB_load_judge);
    assign RF_waddr = ( {5{EXE_WB_RF_wen_1 || EXE_WB_I_Type_Compute_judge || EXE_WB_U_Type_judge || EXE_WB_RISC_jal || EXE_WB_I_Type_jump_judge}} & EXE_WB_rd ) |
                      ( {5{RDW_WB_load_judge}} & RDW_WB_rd );
    wire [31 : 0] PC_add;
    assign PC_add = EXE_WB_PC_add;

    assign RF_wdata = ( {32{EXE_WB_RF_wdata_1}} & EXE_WB_cpu_Result) |
                      ( {32{EXE_WB_RF_wdata_2}} & EXE_WB_cpu_shifter_Result) |
                      ( {32{EXE_WB_RISC_auipc}} & EXE_WB_cpu_auipc) |
                      ( {32{EXE_WB_I_Type_jump_judge || EXE_WB_RISC_jal}} & PC_add) |
                      ( {32{RDW_WB_load_judge}} & RDW_WB_RF_load);

// ST
    wire [31 : 0] Address_ST;
    assign Address_ST = ({32{current_state == ST }} & (EXE_ST_RF_rdata1 + EXE_ST_Sign_extend_S_immediate));
    assign Address = ( {32{current_state == ST}} & {Address_ST[31 : 2], 2'b0}) |
                     ( {32{current_state == LD}} & {Address_real[31 : 2], 2'b0});

    assign Write_strb = ({4{EXE_ST_store[2] && Address_ST[1 : 0] == 2'b11}} & 4'b1000) |
                        ({4{EXE_ST_store[2] && Address_ST[1 : 0] == 2'b10}} & 4'b0100) |
                        ({4{EXE_ST_store[2] && Address_ST[1 : 0] == 2'b01}} & 4'b0010) |
                        ({4{EXE_ST_store[2] && Address_ST[1 : 0] == 2'b00}} & 4'b0001) |
                        ({4{EXE_ST_store[1] && Address_ST[1 : 0] == 2'b10}} & 4'b1100) |
                        ({4{EXE_ST_store[1] && Address_ST[1 : 0] == 2'b00}} & 4'b0011) |
                        ({4{EXE_ST_store[0] }} & 4'b1111);
    
    wire [7 : 0] Mem_byte_3;
    wire [7 : 0] Mem_byte_2;
    wire [7 : 0] Mem_byte_1;
    wire [7 : 0] Mem_byte_0;

    assign Mem_byte_3 = ({8{EXE_ST_store[2] && Address_ST[1 : 0] == 2'b11}} & EXE_ST_RF_rdata2[7 : 0]) |
                        ({8{EXE_ST_store[1] && Address_ST[1 : 0] == 2'b10}} & EXE_ST_RF_rdata2[15 : 8])|
                        ({8{EXE_ST_store[0]}} & EXE_ST_RF_rdata2[31 : 24]);

    assign Mem_byte_2 = ({8{EXE_ST_store[2] && Address_ST[1 : 0] == 2'b10}} & EXE_ST_RF_rdata2[7 : 0]) |
                        ({8{EXE_ST_store[1] && Address_ST[1 : 0] == 2'b10}} & EXE_ST_RF_rdata2[7 : 0]) |
                        ({8{EXE_ST_store[0]}} & EXE_ST_RF_rdata2[23 : 16]);
    
    assign Mem_byte_1 = ({8{EXE_ST_store[2] && Address_ST[1 : 0] == 2'b01}} & EXE_ST_RF_rdata2[7 : 0]) |
                        ({8{EXE_ST_store[1] && Address_ST[1 : 0] == 2'b00}} & EXE_ST_RF_rdata2[15 : 8]) |
                        ({8{EXE_ST_store[0]}} & EXE_ST_RF_rdata2[15 : 8]);

    assign Mem_byte_0 = ({8{EXE_ST_store[2] && Address_ST[1 : 0] == 2'b00}} & EXE_ST_RF_rdata2[7 : 0]) |
                        ({8{EXE_ST_store[1] && Address_ST[1 : 0] == 2'b00}} & EXE_ST_RF_rdata2[7 : 0]) |
                        ({8{EXE_ST_store[0]}} & EXE_ST_RF_rdata2[7 : 0]);
    assign Write_data = {Mem_byte_3,Mem_byte_2,Mem_byte_1,Mem_byte_0};

 always @(*)begin
        case(current_state)
            INIT:
                if(rst)
                    next_state = INIT;
                else
                    next_state = IF;
            IF:
            /* Inst_Req_Valid: 此时PC有效，
            等待对方接收 PC
            */
                if(Inst_Req_Ready)
                    next_state = IW;
                else
                    next_state = IF;
            IW:
            /* 对方已经接收了 PC, 此时等待传回有效的
            Instruction
            */
                if(Inst_Valid)
                    next_state = ID;
                else
                    next_state = IW;
            ID:
                    next_state = EXE;
            EXE:
                if(ID_EXE_Switch_IF)
                    next_state = IF;
                else if( ID_EXE_Switch_WB)
                    next_state = WB;
                else if( ID_EXE_store_Judge)
                    next_state = ST;
                else if( ID_EXE_load_judge)
                    next_state = LD;
                else
                    next_state = IF;
            ST:
            /* 内存写指令，如果对方接受写请求，则跳转
            */
                if(Mem_Req_Ready)
                    next_state = IF;
                else 
                    next_state = ST;
            LD:
            /* 如果对方接受读请求，则跳转
            */
                if(Mem_Req_Ready)
                    next_state = RDW;
                else
                    next_state = LD;
            RDW:
            /* 如果传回了有效数据，则写
            */
                if(Read_data_Valid)
                    next_state = WB;
                else
                    next_state = RDW;
            WB:
                next_state = IF;
            default:
                next_state = INIT;
        endcase
    end

    reg [31 : 0] cycle_cnt;
    always@(posedge clk)begin
        if(rst)
            cycle_cnt <= 32'b0;
        else
            cycle_cnt <= cycle_cnt + 32'b1;
    end
    assign cpu_perf_cnt_0 = cycle_cnt;
endmodule