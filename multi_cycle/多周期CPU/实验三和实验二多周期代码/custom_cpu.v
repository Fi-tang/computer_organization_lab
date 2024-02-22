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

    assign Inst_Req_Valid = (current_state == IF);
    assign Inst_Ready = (current_state == IW || current_state == INIT);
    assign MemRead = (current_state == LD);
    assign MemWrite = (current_state == ST);
    assign Read_data_Ready = (current_state == RDW || current_state == INIT);

// INIT
    wire RF_wen;            
    wire [4:0] RF_waddr;   // cpu_reg_waddr;  
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

    always @(posedge clk)begin
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
    always @(posedge clk)begin
        IW_ID_Instruction <= Instruction;
        IW_ID_cpu_PC <= cpu_PC;
    end


// ID
    wire [5 : 0] Opcode;
    wire [4 : 0] rs;
    wire [4 : 0] rt;
    wire [4 : 0] rd;
    wire [5 : 0] func;
    wire [15 : 0] Immediate;
    wire [5 : 0] sa;
    wire [25 : 0] instr_index;

    assign rs = IW_ID_Instruction[25 : 21];
    assign rt = IW_ID_Instruction[20 : 16];
    assign rd = IW_ID_Instruction[15 : 11];
    assign Opcode = IW_ID_Instruction[31 : 26];
    assign func = IW_ID_Instruction[5 : 0];
    assign Immediate = IW_ID_Instruction[15 : 0];
    assign sa = IW_ID_Instruction[10 : 6];
    assign instr_index = IW_ID_Instruction[25 : 0];

    wire R_Type_judge;
    wire I_Type_Compute_judge;
    wire J_Type_Judge;
    wire load_judge;
    wire store_Judge;
    wire I_Type_Branch;
    wire Regimm;
    wire NOP_judge;

    assign R_Type_judge = (Opcode == 6'b0);
    assign I_Type_Compute_judge = (Opcode[5 : 3] == 3'b001);
    assign J_Type_Judge = (Opcode[5:1] == 5'b00001);
    assign load_judge = (Opcode[5 : 3] == 3'b100);
    assign store_Judge = (Opcode[5 : 3] == 3'b101);
    assign I_Type_Branch = (Opcode[5 : 2] == 4'b0001);
    assign Regimm = (Opcode[5 : 0] == 6'b000001);
    assign NOP_judge = (IW_ID_Instruction == 32'b0);

    assign RF_raddr1 = rs;
    assign RF_raddr2 = rt;

    wire [31 : 0] cpu_alu_A;
    wire [31 : 0] cpu_alu_B;
    wire [2 : 0] cpu_ALUop;

    /* R-Type */
    wire MIPS_addu;
    wire MIPS_subu;
    wire MIPS_and;
    wire MIPS_nor;
    wire MIPS_or;
    wire MIPS_xor;
    wire MIPS_slt;
    wire MIPS_sltu;
    wire MIPS_movn;
    wire MIPS_movz;

    assign MIPS_addu = (R_Type_judge && func[5 : 0] == 6'b100001);
    assign MIPS_subu = (R_Type_judge && func[5 : 0] == 6'b100011);
    assign MIPS_and = (R_Type_judge && func[5 : 0] == 6'b100100);
    assign MIPS_nor = (R_Type_judge && func[5 : 0] == 6'b100111);
    assign MIPS_or = (R_Type_judge && func[5 : 0] == 6'b100101);
    assign MIPS_xor = (R_Type_judge && func[5 : 0] == 6'b100110);

    assign MIPS_slt = (R_Type_judge && func[5 : 0] == 6'b101010);
    assign MIPS_sltu = (R_Type_judge && func[5 : 0] == 6'b101011);

    assign MIPS_movn = (R_Type_judge && func[5 : 0] == 6'b001011);
    assign MIPS_movz = (R_Type_judge && func[5 : 0] == 6'b001010);

    /* I_Type compute */
    wire MIPS_addiu;
    wire MIPS_andi;
    wire MIPS_ori;
    wire MIPS_xori;
    wire MIPS_slti;
    wire MIPS_sltiu;
    wire MIPS_lui;
   
    assign MIPS_addiu = (I_Type_Compute_judge && Opcode[2 : 0] == 3'b001);
    assign MIPS_andi = (I_Type_Compute_judge && Opcode[2 : 0] == 3'b100);
    assign MIPS_ori = (I_Type_Compute_judge && Opcode[2 : 0] == 3'b101);
    assign MIPS_xori = (I_Type_Compute_judge && Opcode[2 : 0] == 3'b110);
    assign MIPS_slti = (I_Type_Compute_judge && Opcode[2 : 0] == 3'b010);
    assign MIPS_sltiu = (I_Type_Compute_judge && Opcode[2 : 0] == 3'b011);
    assign MIPS_lui = (I_Type_Compute_judge && Opcode[2 : 0] == 3'b111);

    /*I_Type_branch && Regimm */
    wire MIPS_bne;
    wire MIPS_beq;
    wire MIPS_bgez;
    wire MIPS_bgtz;
    wire MIPS_blez;
    wire MIPS_bltz;

    assign MIPS_bne = (I_Type_Branch && Opcode[1 : 0] == 2'b01);
    assign MIPS_beq = (I_Type_Branch && Opcode[1 : 0] == 2'b00);
    assign MIPS_bgez = (Regimm && rt == 5'b00001);
    assign MIPS_bgtz = (I_Type_Branch && Opcode[1 : 0] == 2'b11);
    assign MIPS_blez = (I_Type_Branch && Opcode[1 : 0] == 2'b10);
    assign MIPS_bltz = (Regimm && rt == 5'b0);

    assign cpu_alu_A = ( {32{(R_Type_judge  &&  func[5]) ||  I_Type_Compute_judge || I_Type_Branch || load_judge || store_Judge }} & RF_rdata1 ) |
                       ( {32{R_Type_judge  && ~func[5] }} & RF_rdata2 );

    wire [31 : 0] Sign_extend_immediate;
    wire [31 : 0] Zero_extend_immediate;
    assign Sign_extend_immediate = {{16{Immediate[15]}},Immediate};
    assign Zero_extend_immediate = {{16{1'b0}},Immediate};

    assign cpu_alu_B =  ({32{(R_Type_judge && func[5]) || I_Type_Branch || MIPS_bltz}} & RF_rdata2) |
                        ({32{(R_Type_judge && ~func[5]) || MIPS_blez }} & 32'b0) |
                        ({32{MIPS_addiu || MIPS_slti || MIPS_sltiu || load_judge || store_Judge}} & Sign_extend_immediate) |
                        ({32{MIPS_andi || MIPS_ori || MIPS_xori}} & Zero_extend_immediate);
    

    assign cpu_ALUop = ({3{MIPS_subu || MIPS_movn || MIPS_movz || I_Type_Branch || Regimm }} & 3'b110) |
                       ({3{ MIPS_addu || MIPS_addiu || load_judge || store_Judge }} & 3'b010) |
                       ({3{ MIPS_and || MIPS_andi}} & 3'b000) |
                       ({3{ MIPS_nor }} & 3'b101) |
                       ({3{ MIPS_or || MIPS_ori}} & 3'b001) |
                       ({3{ MIPS_xor || MIPS_xori }} & 3'b100) |
                       ({3{ MIPS_slt ||  MIPS_slti  }} & 3'b111) |
                       ({3{ MIPS_sltu || MIPS_sltiu}} & 3'b011);

    wire MIPS_sll;
    wire MIPS_sllv;
    wire MIPS_sra;
    wire MIPS_srav;
    wire MIPS_srl;
    wire MIPS_srlv;

    assign MIPS_sll = (R_Type_judge && func[5 : 0] == 6'b0);
    assign MIPS_sllv = (R_Type_judge && func[5 : 0] == 6'b000100);
    assign MIPS_sra = (R_Type_judge && func[5 : 0] == 6'b000011);
    assign MIPS_srav = (R_Type_judge && func[5 : 0] == 6'b000111);
    assign MIPS_srl = (R_Type_judge && func[5 : 0] == 6'b000010);
    assign MIPS_srlv = (R_Type_judge && func[5 : 0] == 6'b000110);

    wire [31 : 0] cpu_shifter_A;
    wire [4 : 0] cpu_shifter_B;
    wire [1 : 0] cpu_shifter_Shiftop;

    assign cpu_shifter_A = RF_rdata2;

    assign cpu_shifter_B = ( {32{MIPS_sll || MIPS_sra || MIPS_srl}} & sa ) |
                            ( {32{MIPS_sllv || MIPS_srav || MIPS_srlv}} & RF_rdata1[5 : 0] );

    assign cpu_shifter_Shiftop = func[1 : 0];

    wire MIPS_jr;
    wire MIPS_jalr;

    assign MIPS_jr = (R_Type_judge && func[5 : 0] == 6'b001000);
    assign MIPS_jalr = (R_Type_judge && func[5 : 0] == 6'b001001);


    /* J-Type */
    wire MIPS_j;
    wire MIPS_jal;

    assign MIPS_j = (J_Type_Judge && Opcode[0] == 0);
    assign MIPS_jal = (J_Type_Judge && Opcode[0] == 1);

    /*load and store*/
    wire MIPS_lb;
    wire MIPS_lh;
    wire MIPS_lw;
    wire MIPS_lbu;
    wire MIPS_lhu;
    wire MIPS_lwl;
    wire MIPS_lwr;

    wire MIPS_sb;
    wire MIPS_sh;
    wire MIPS_sw;
    wire MIPS_swl;
    wire MIPS_swr;


    assign MIPS_lb = (load_judge && Opcode[2 : 0] == 3'b000);
    assign MIPS_lh = (load_judge && Opcode[2 : 0] == 3'b001);
    assign MIPS_lw = (load_judge && Opcode[2 : 0] == 3'b011);
    assign MIPS_lbu = (load_judge && Opcode[2 : 0] == 3'b100);
    assign MIPS_lhu = (load_judge && Opcode[2 : 0] == 3'b101);
    assign MIPS_lwl = (load_judge && Opcode[2 : 0] == 3'b010);
    assign MIPS_lwr = (load_judge && Opcode[2 : 0] == 3'b110);

    assign MIPS_sb = (store_Judge && Opcode[2 : 0] == 3'b000);
    assign MIPS_sh = (store_Judge && Opcode[2 : 0] == 3'b001);
    assign MIPS_sw = (store_Judge && Opcode[2 : 0] == 3'b011);
    assign MIPS_swl = (store_Judge && Opcode[2 : 0] == 3'b010);
    assign MIPS_swr = (store_Judge && Opcode[2 : 0] == 3'b110);

    
    wire [31 : 0] cpu_PC_jump;
    wire [31 : 0] cpu_PC_R;
    wire [31 : 0] cpu_PC_branch;
    wire cpu_PC_jump_enable;
    wire cpu_PC_R_enable;

    assign cpu_PC_jump_enable = J_Type_Judge;
    assign cpu_PC_R_enable = (MIPS_jr || MIPS_jalr);

    assign cpu_PC_branch = IW_ID_cpu_PC + { {14{Immediate[15]}},Immediate,2'b0};
    assign cpu_PC_jump = {IW_ID_cpu_PC[31 : 28] ,instr_index, 2'b0};
    assign cpu_PC_R = RF_rdata1;

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


    reg ID_EXE_RF_wen_1;
    reg ID_EXE_MIPS_movn;
    reg ID_EXE_MIPS_movz;
    reg ID_EXE_MIPS_jal;
    reg ID_EXE_MIPS_lui;
    reg ID_EXE_R_Type_judge;
    reg ID_EXE_I_Type_Compute_judge;
    reg ID_EXE_store_Judge;
    reg ID_EXE_load_judge;

    reg [6 : 0] ID_EXE_load;
    reg [4 : 0] ID_EXE_store;

    reg [4 : 0] ID_EXE_rt;
    reg [4 : 0] ID_EXE_rd;
    reg [31 : 0] ID_EXE_PC_add;

    reg ID_EXE_RF_wdata_1;
    reg ID_EXE_RF_wdata_2;
    reg ID_EXE_RF_wdata_3;

    reg [15 : 0] ID_EXE_Immediate;
    reg [31 : 0] ID_EXE_Sign_extend_immediate;

    always @(posedge clk)begin
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

        ID_EXE_cpu_PC_branch_enable <={MIPS_bne, MIPS_beq, MIPS_bgez, MIPS_bgtz, MIPS_blez, MIPS_bltz};

        ID_EXE_RF_rdata1 <= RF_rdata1;
        ID_EXE_RF_rdata2 <= RF_rdata2;

        ID_EXE_Switch_WB <= ( (R_Type_judge ) || I_Type_Compute_judge || MIPS_jal);
        ID_EXE_Switch_IF <= (MIPS_j || Regimm || I_Type_Branch);

        ID_EXE_RF_wen_1 <= (R_Type_judge && ~MIPS_jr && ~MIPS_movn && ~MIPS_movz );
        ID_EXE_MIPS_movn <= MIPS_movn;
        ID_EXE_MIPS_movz <= MIPS_movz;
        ID_EXE_MIPS_jal <= MIPS_jal;
        ID_EXE_MIPS_lui <= MIPS_lui;
        ID_EXE_R_Type_judge <= R_Type_judge;
        ID_EXE_I_Type_Compute_judge <= I_Type_Compute_judge;

        ID_EXE_store_Judge <= store_Judge;
        ID_EXE_load_judge <= load_judge;
        ID_EXE_load <= {MIPS_lb, MIPS_lbu, MIPS_lh, MIPS_lhu,
        MIPS_lw, MIPS_lwl, MIPS_lwr};
        ID_EXE_store <= {MIPS_sb, MIPS_sh, MIPS_sw, MIPS_swl, MIPS_swr};

        ID_EXE_rt <= rt;
        ID_EXE_rd <= rd;
        ID_EXE_PC_add <= IW_ID_cpu_PC;

        ID_EXE_RF_wdata_1 <= (MIPS_addu || MIPS_subu || MIPS_and || MIPS_nor || MIPS_or || MIPS_xor || MIPS_slt || MIPS_sltu
    || (I_Type_Compute_judge && ~MIPS_lui));
        ID_EXE_RF_wdata_2 <= (MIPS_sll || MIPS_sllv || MIPS_sra || MIPS_srav || MIPS_srl || MIPS_srlv);
        ID_EXE_RF_wdata_3 <= (MIPS_jalr || MIPS_jal);

        ID_EXE_Immediate <= Immediate;
        ID_EXE_Sign_extend_immediate <= Sign_extend_immediate;
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

    assign cpu_PC_branch_enable = ( ID_EXE_cpu_PC_branch_enable[5] && ~cpu_Zero) ||
    ( ID_EXE_cpu_PC_branch_enable[4] && cpu_Zero) ||
    ( ID_EXE_cpu_PC_branch_enable[3] && ~ID_EXE_RF_rdata1[31]) ||
    ( ID_EXE_cpu_PC_branch_enable[2] && (~cpu_Zero && !(cpu_Result[31]^cpu_Overflow))) ||
    ( ID_EXE_cpu_PC_branch_enable[1] && (cpu_Zero || (cpu_Result[31]^cpu_Overflow))) ||
    ( ID_EXE_cpu_PC_branch_enable[0] && ID_EXE_RF_rdata1[31]);

    wire [31 : 0] cpu_shifter_Result;

    shifter cpu_shifter(
        .A(ID_EXE_cpu_shifter_A),
        .B(ID_EXE_cpu_shifter_B),
        .Shiftop(ID_EXE_cpu_shifter_Shiftop),
        .Result(cpu_shifter_Result)
    );

    assign cpu_PC_next = ( {32{current_state == EXE && cpu_PC_branch_enable }} & ID_EXE_cpu_PC_branch ) |
                         ( {32{current_state == EXE && ID_EXE_cpu_PC_jump_enable}} & ID_EXE_cpu_PC_jump) |
                         ( {32{current_state == EXE && ID_EXE_cpu_PC_R_enable}} & ID_EXE_cpu_PC_R);
    assign cpu_PC_next_enable = (cpu_PC_branch_enable || ID_EXE_cpu_PC_jump_enable ||  ID_EXE_cpu_PC_R_enable);

    reg EXE_WB_RF_wen_1;
    reg EXE_WB_MIPS_movn;
    reg EXE_WB_MIPS_movz;
    reg EXE_WB_MIPS_jal;
    reg EXE_WB_MIPS_lui;
    reg EXE_WB_cpu_Zero;
    reg EXE_WB_R_Type_judge;
    reg EXE_WB_I_Type_Compute_judge;

    reg [4 : 0] EXE_WB_rt;
    reg [4 : 0] EXE_WB_rd;
    reg [31 : 0] EXE_WB_PC_add;

    reg EXE_WB_RF_wdata_1;
    reg EXE_WB_RF_wdata_2;
    reg EXE_WB_RF_wdata_3;

    reg [31 : 0] EXE_WB_cpu_Result;
    reg [31 : 0] EXE_WB_cpu_shifter_Result;
    reg [31 : 0] EXE_WB_RF_rdata1;
    reg [15 : 0] EXE_WB_Immediate;


    reg [31 : 0] EXE_LD_RF_rdata1;
    reg [31 : 0] EXE_LD_RF_rdata2;
    reg [31 : 0] EXE_LD_Sign_extend_immediate;
    reg [6 : 0]  EXE_LD_load;
    reg EXE_LD_load_judge;
    reg [4 : 0] EXE_LD_rt;
    
    reg [31 : 0] EXE_ST_RF_rdata1;
    reg [31 : 0] EXE_ST_RF_rdata2;
    reg [31 : 0] EXE_ST_Sign_extend_immediate;
    reg [4 : 0] EXE_ST_store;
    always @(posedge clk)begin
        if(current_state == IF) begin
            EXE_WB_RF_wen_1 <= 0;
            EXE_WB_MIPS_movn <= 0;
            EXE_WB_MIPS_movz <= 0;
            EXE_WB_MIPS_jal <= 0;
            EXE_WB_MIPS_lui <= 0;
            EXE_WB_cpu_Zero <= 0;
            EXE_WB_R_Type_judge <= 0;
            EXE_WB_I_Type_Compute_judge <= 0;

            EXE_WB_rt <= 0;
            EXE_WB_rd <= 0;

            EXE_WB_PC_add <= 0;

            EXE_WB_RF_wdata_1 <= 0;
            EXE_WB_RF_wdata_2 <= 0;
            EXE_WB_RF_wdata_3 <= 0;

            EXE_WB_cpu_Result <= 0;
            EXE_WB_cpu_shifter_Result <= 0;
            EXE_WB_RF_rdata1 <= 0;
            EXE_WB_Immediate <= 0;

            EXE_LD_RF_rdata1 <= 0;
            EXE_LD_RF_rdata2 <= 0;
            EXE_LD_Sign_extend_immediate <= 0;
            EXE_LD_load <= 0;
            EXE_LD_load_judge <= 0;

            EXE_LD_rt <= 0;

            EXE_ST_RF_rdata1 <= 0;
            EXE_ST_RF_rdata2 <= 0;
            EXE_ST_Sign_extend_immediate <= 0;
            EXE_ST_store <= 0;
        end
        else if(current_state == EXE && next_state != EXE) begin
            EXE_WB_RF_wen_1 <= ID_EXE_RF_wen_1;
            EXE_WB_MIPS_movn <= ID_EXE_MIPS_movn;
            EXE_WB_MIPS_movz <= ID_EXE_MIPS_movz;
            EXE_WB_MIPS_jal <= ID_EXE_MIPS_jal;
            EXE_WB_MIPS_lui <= ID_EXE_MIPS_lui;
            EXE_WB_cpu_Zero <= cpu_Zero;
            EXE_WB_R_Type_judge <= ID_EXE_R_Type_judge;
            EXE_WB_I_Type_Compute_judge <= ID_EXE_I_Type_Compute_judge;

            EXE_WB_rt <= ID_EXE_rt;
            EXE_WB_rd <= ID_EXE_rd;

            EXE_WB_PC_add <= ID_EXE_PC_add;

            EXE_WB_RF_wdata_1 <= ID_EXE_RF_wdata_1;
            EXE_WB_RF_wdata_2 <= ID_EXE_RF_wdata_2;
            EXE_WB_RF_wdata_3 <= ID_EXE_RF_wdata_3;

            EXE_WB_cpu_Result <= cpu_Result;
            EXE_WB_cpu_shifter_Result <= cpu_shifter_Result;
            EXE_WB_RF_rdata1 <= ID_EXE_RF_rdata1;
            EXE_WB_Immediate <= ID_EXE_Immediate;

            EXE_LD_RF_rdata1 <= ID_EXE_RF_rdata1;
            EXE_LD_RF_rdata2 <= ID_EXE_RF_rdata2;
            EXE_LD_Sign_extend_immediate <= ID_EXE_Sign_extend_immediate;
            EXE_LD_load <= ID_EXE_load;
            EXE_LD_load_judge <= ID_EXE_load_judge;

            EXE_LD_rt <= ID_EXE_rt;

            EXE_ST_RF_rdata1 <= ID_EXE_RF_rdata1;
            EXE_ST_RF_rdata2 <= ID_EXE_RF_rdata2;
            EXE_ST_Sign_extend_immediate <= ID_EXE_Sign_extend_immediate;
            EXE_ST_store <= ID_EXE_store;
        end
    end
// LD
    wire [31 : 0] Address_real;
    assign Address_real = ({32{current_state == LD}}  & (EXE_LD_RF_rdata1 + EXE_LD_Sign_extend_immediate));

    reg [31 : 0] LD_RDW_Address_real;
    reg [6 : 0] LD_RDW_load;
    reg [31 : 0] LD_RDW_RF_rdata2;
    reg LD_RDW_load_judge;
    reg [4 : 0] LD_RDW_rt;
    always @(posedge clk)begin
        if(current_state == IF)begin
            LD_RDW_Address_real <= 0;
            LD_RDW_load <= 0;
            LD_RDW_RF_rdata2 <= 0;
            LD_RDW_load_judge <= 0;
            LD_RDW_rt <= 0;
        end
        else if(current_state == LD && next_state != LD)begin
            LD_RDW_Address_real <= Address_real;
            LD_RDW_load <= EXE_LD_load;
            LD_RDW_RF_rdata2 <= EXE_LD_RF_rdata2;
            LD_RDW_load_judge <= EXE_LD_load_judge;
            LD_RDW_rt <= EXE_LD_rt;
        end
    end

// RDW
    wire [7 : 0] load_byte;
    assign load_byte = ({8{LD_RDW_Address_real[1 : 0] == 2'b00}} & Read_data[7 : 0])|
                       ({8{LD_RDW_Address_real[1 : 0] == 2'b01}} & Read_data[15 : 8]) |
                       ({8{LD_RDW_Address_real[1 : 0] == 2'b10}} & Read_data[23 : 16])|
                       ({8{LD_RDW_Address_real[1 : 0] == 2'b11}} & Read_data[31 : 24]);
    wire [31 : 0] load_wdata_byte;
    assign load_wdata_byte = ({32{LD_RDW_load[6]}} & {{24{load_byte[7]}}, load_byte} ) |
                             ({32{LD_RDW_load[5]}} & {{24{1'b0}} , load_byte });

    wire [15 : 0] load_halfword;
    assign load_halfword = ({16{LD_RDW_Address_real[1 : 0] == 2'b00}} & Read_data[15 : 0]) |
                           ({16{LD_RDW_Address_real[1 : 0] == 2'b10}} & Read_data[31 : 16]);
    wire [31 : 0] load_wdata_halfword;
    assign load_wdata_halfword = ({32{LD_RDW_load[4]}} & {{16{load_halfword[15]}}, load_halfword}) |
                                 ({32{LD_RDW_load[3]}} & {{16{1'b0}}, load_halfword});
    wire [31 : 0] load_wdata_word;
    assign load_wdata_word = ( {32{LD_RDW_load[2]}} & Read_data[31 : 0]);

    wire [7 : 0] RF_byte_3;
    wire [7 : 0] RF_byte_2;
    wire [7 : 0] RF_byte_1;
    wire [7 : 0] RF_byte_0;

    wire [31 : 0] RF_load;
    assign RF_byte_3 =  ({8{LD_RDW_load[1] && LD_RDW_Address_real[1 : 0] == 2'b11}} & Read_data[31 : 24])  |
                        ({8{LD_RDW_load[1] && LD_RDW_Address_real[1 : 0] == 2'b10}} & Read_data[23 : 16])  |
                        ({8{LD_RDW_load[1] && LD_RDW_Address_real[1 : 0] == 2'b01}} & Read_data[15 : 8])  |
                        ({8{LD_RDW_load[1] && LD_RDW_Address_real[1 : 0] == 2'b00}} & Read_data[7 : 0])  |
                        ({8{LD_RDW_load[0] && LD_RDW_Address_real[1 : 0] == 2'b00}} & Read_data[31 : 24]) |
                        ({8{LD_RDW_load[0] && LD_RDW_Address_real[1 : 0] != 2'b00}} & LD_RDW_RF_rdata2[31 : 24]);
    
    assign RF_byte_2 =  ({8{LD_RDW_load[1] && LD_RDW_Address_real[1 : 0] == 2'b11}} & Read_data[23 : 16])  |
                        ({8{LD_RDW_load[1] && LD_RDW_Address_real[1 : 0] == 2'b10}} & Read_data[15 : 8])  |
                        ({8{LD_RDW_load[1] && LD_RDW_Address_real[1 : 0] == 2'b01}} & Read_data[7 : 0])  |
                        ({8{LD_RDW_load[0] && LD_RDW_Address_real[1 : 0] == 2'b01}} & Read_data[31 : 24])  |
                        ({8{LD_RDW_load[0] && LD_RDW_Address_real[1 : 0] == 2'b00}} & Read_data[23 : 16]) |
                        ({8{(LD_RDW_load[1] && LD_RDW_Address_real[1 : 0] == 2'b00) || (LD_RDW_load[1] && LD_RDW_Address_real[1 : 0] == 2'b10)
                        || (LD_RDW_load[0] && LD_RDW_Address_real[1 : 0] == 2'b11)}} & LD_RDW_RF_rdata2[23 : 16]);

    assign RF_byte_1 =  ({8{LD_RDW_load[1] && LD_RDW_Address_real[1 : 0] == 2'b11}} & Read_data[15 : 8])  |
                        ({8{LD_RDW_load[1] && LD_RDW_Address_real[1 : 0] == 2'b10}} & Read_data[7 : 0])  |
                        ({8{LD_RDW_load[0] && LD_RDW_Address_real[1 : 0] == 2'b10}} & Read_data[31 : 24])  |
                        ({8{LD_RDW_load[0] && LD_RDW_Address_real[1 : 0] == 2'b01}} & Read_data[23 : 16])  |
                        ({8{LD_RDW_load[0] && LD_RDW_Address_real[1 : 0] == 2'b00}} & Read_data[15 : 8]) |
                        ({8{(LD_RDW_load[1] && LD_RDW_Address_real[1 : 0] == 2'b01) || (LD_RDW_load[1] && LD_RDW_Address_real[1 : 0] == 2'b00) 
                        || (LD_RDW_load[0] && LD_RDW_Address_real[1 : 0] == 2'b11)  }} & LD_RDW_RF_rdata2[15 : 8] );

    assign RF_byte_0 =  ({8{LD_RDW_load[1] && LD_RDW_Address_real[1 : 0] == 2'b11}} & Read_data[7 : 0])  |
                        ({8{LD_RDW_load[0] && LD_RDW_Address_real[1 : 0] == 2'b11}} & Read_data[31 : 24])  |
                        ({8{LD_RDW_load[0] && LD_RDW_Address_real[1 : 0] == 2'b10}} & Read_data[23 : 16])  |
                        ({8{LD_RDW_load[0] && LD_RDW_Address_real[1 : 0] == 2'b01}} & Read_data[15 : 8])  |
                        ({8{LD_RDW_load[0] && LD_RDW_Address_real[1 : 0] == 2'b00}} & Read_data[7 : 0])  |
                        ( {8{LD_RDW_load[1] && LD_RDW_Address_real[1 : 0] != 2'b11} } & LD_RDW_RF_rdata2[7 : 0]);
    
    assign RF_load = ({32{LD_RDW_load[6] || LD_RDW_load[5]}} & load_wdata_byte) |
                      ({32{LD_RDW_load[4] || LD_RDW_load[3]}} & load_wdata_halfword ) |
                      ( {32{LD_RDW_load[2]}} & load_wdata_word) |
                      ({32{LD_RDW_load[1] || LD_RDW_load[0]}} & {RF_byte_3,RF_byte_2,RF_byte_1,RF_byte_0});

    reg [31 : 0] RDW_WB_RF_load;
    reg RDW_WB_load_judge;
    reg [4 : 0] RDW_WB_rt;
    always@(posedge clk)begin
        if(current_state == IF)begin
            RDW_WB_RF_load <= 0;
            RDW_WB_load_judge <= 0;
            RDW_WB_rt <= 0;
        end
        else if(current_state == RDW && next_state != RDW)begin
            RDW_WB_RF_load <= RF_load;
            RDW_WB_load_judge <= LD_RDW_load_judge;
            RDW_WB_rt <= LD_RDW_rt;
        end
    end

// WB:
    assign RF_wen = (current_state == WB && EXE_WB_RF_wen_1) |
                (current_state == WB && EXE_WB_MIPS_movn && ~EXE_WB_cpu_Zero) |
                (current_state == WB && EXE_WB_MIPS_movz && EXE_WB_cpu_Zero) |
                (current_state == WB && EXE_WB_I_Type_Compute_judge) |
                (current_state == WB && EXE_WB_MIPS_jal) |
                (current_state == WB && RDW_WB_load_judge);
    
    assign RF_waddr = ({5{EXE_WB_R_Type_judge}} & EXE_WB_rd ) |
                      ({5{EXE_WB_I_Type_Compute_judge}} & EXE_WB_rt ) |
                      ({5{EXE_WB_MIPS_jal}} & 5'd31) |
                      ({5{RDW_WB_load_judge}} & RDW_WB_rt);
    wire [31 : 0] PC_add;
    assign PC_add = EXE_WB_PC_add + 4;

    assign RF_wdata = ({32{EXE_WB_RF_wdata_1}} & EXE_WB_cpu_Result) |
                      ({32{EXE_WB_RF_wdata_2}} & EXE_WB_cpu_shifter_Result) |
                      ({32{EXE_WB_RF_wdata_3}} & PC_add) |
                      ({32{EXE_WB_MIPS_movn || EXE_WB_MIPS_movz}} & EXE_WB_RF_rdata1) |
                      ({32{EXE_WB_MIPS_lui}} & {EXE_WB_Immediate, {16{1'b0}}}) |
                      ({32{RDW_WB_load_judge}} & RDW_WB_RF_load);
// ST
    wire [31 : 0] Address_ST;
    assign Address_ST = ({32{current_state == ST || current_state == LD}}  & (EXE_ST_RF_rdata1 + EXE_ST_Sign_extend_immediate));
    assign Address = {Address_ST[31 : 2], 2'b0};

    assign Write_strb = ({4{EXE_ST_store[4] && Address_ST[1 : 0] == 2'b11}} & 4'b1000) |
                        ({4{EXE_ST_store[4] && Address_ST[1 : 0] == 2'b10}} & 4'b0100) |
                        ({4{EXE_ST_store[4] && Address_ST[1 : 0] == 2'b01}} & 4'b0010) |
                        ({4{EXE_ST_store[4] && Address_ST[1 : 0] == 2'b00}} & 4'b0001) |
                        ({4{EXE_ST_store[3] && Address_ST[1 : 0] == 2'b10}} & 4'b1100) |
                        ({4{EXE_ST_store[3] && Address_ST[1 : 0] == 2'b00}} & 4'b0011) |
                        ({4{EXE_ST_store[2]}} & 4'b1111) |
                        ({4{EXE_ST_store[1] && Address_ST[1 : 0] == 2'b00}} & 4'b0001) |
                        ({4{EXE_ST_store[1] && Address_ST[1 : 0] == 2'b01}} & 4'b0011) |
                        ({4{EXE_ST_store[1] && Address_ST[1 : 0] == 2'b10}} & 4'b0111) |
                        ({4{EXE_ST_store[1] && Address_ST[1 : 0] == 2'b11}} & 4'b1111) |
                        ({4{EXE_ST_store[0] && Address_ST[1 : 0] == 2'b00}} & 4'b1111) |
                        ({4{EXE_ST_store[0] && Address_ST[1 : 0] == 2'b01}} & 4'b1110) |
                        ({4{EXE_ST_store[0] && Address_ST[1 : 0] == 2'b10}} & 4'b1100) |
                        ({4{EXE_ST_store[0] && Address_ST[1 : 0] == 2'b11}} & 4'b1000);

    wire [7 : 0] Mem_byte_3;
    wire [7 : 0] Mem_byte_2;
    wire [7 : 0] Mem_byte_1;
    wire [7 : 0] Mem_byte_0;

    assign Mem_byte_3 = ({8{EXE_ST_store[4] && Address_ST[1 : 0] == 2'b11}} & EXE_ST_RF_rdata2[7 : 0]) |
                        ({8{EXE_ST_store[3] && Address_ST[1 : 0] == 2'b10}} & EXE_ST_RF_rdata2[15 : 8]) |
                        ({8{EXE_ST_store[2]}} & EXE_ST_RF_rdata2[31 : 24]) |
                        ({8{EXE_ST_store[1] && Address_ST[1 : 0] == 2'b11}} & EXE_ST_RF_rdata2[31 : 24]) |
                        ({8{EXE_ST_store[0] && Address_ST[1 : 0] == 2'b00}} & EXE_ST_RF_rdata2[31 : 24]) |
                        ({8{EXE_ST_store[0] && Address_ST[1 : 0] == 2'b01}} & EXE_ST_RF_rdata2[23 : 16]) |
                        ({8{EXE_ST_store[0] && Address_ST[1 : 0] == 2'b10}} & EXE_ST_RF_rdata2[15 : 8]) |
                        ({8{EXE_ST_store[0] && Address_ST[1 : 0] == 2'b11}} & EXE_ST_RF_rdata2[7 : 0]);
    
    assign Mem_byte_2 = ({8{EXE_ST_store[4] && Address_ST[1 : 0] == 2'b10}} & EXE_ST_RF_rdata2[7 : 0]) |
                        ({8{EXE_ST_store[3] && Address_ST[1 : 0] == 2'b10}} & EXE_ST_RF_rdata2[7 : 0]) |
                        ({8{EXE_ST_store[2]}} & EXE_ST_RF_rdata2[23 : 16]) |
                        ({8{EXE_ST_store[1] && Address_ST[1 : 0] == 2'b10}} & EXE_ST_RF_rdata2[31 : 24]) |
                        ({8{EXE_ST_store[1] && Address_ST[1 : 0] == 2'b11}} & EXE_ST_RF_rdata2[23 : 16]) |
                        ({8{EXE_ST_store[0] && Address_ST[1 : 0] == 2'b00}} & EXE_ST_RF_rdata2[23 : 16]) |
                        ({8{EXE_ST_store[0] && Address_ST[1 : 0] == 2'b01}} & EXE_ST_RF_rdata2[15 : 8]) |
                        ({8{EXE_ST_store[0] && Address_ST[1 : 0] == 2'b10}} & EXE_ST_RF_rdata2[7 : 0]);

    assign Mem_byte_1 = ({8{EXE_ST_store[4] && Address_ST[1 : 0] == 2'b01}} & EXE_ST_RF_rdata2[7 : 0]) |
                        ({8{EXE_ST_store[3] && Address_ST[1 : 0] == 2'b00}} & EXE_ST_RF_rdata2[15 : 8]) |
                        ({8{EXE_ST_store[2]}} & EXE_ST_RF_rdata2[15 : 8]) |
                        ({8{EXE_ST_store[1] && Address_ST[1 : 0] == 2'b01}} & EXE_ST_RF_rdata2[31 : 24]) |
                        ({8{EXE_ST_store[1] && Address_ST[1 : 0] == 2'b10}} & EXE_ST_RF_rdata2[23 : 16]) |
                        ({8{EXE_ST_store[1] && Address_ST[1 : 0] == 2'b11}} & EXE_ST_RF_rdata2[15 : 8]) |
                        ({8{EXE_ST_store[0] && Address_ST[1 : 0] == 2'b00}} & EXE_ST_RF_rdata2[15 : 8]) |
                        ({8{EXE_ST_store[0] && Address_ST[1 : 0] == 2'b01}} & EXE_ST_RF_rdata2[7 : 0]);

    assign Mem_byte_0 = ({8{EXE_ST_store[4] && Address_ST[1 : 0] == 2'b00}} & EXE_ST_RF_rdata2[7 : 0]) |
                        ({8{EXE_ST_store[3] && Address_ST[1 : 0] == 2'b00}} & EXE_ST_RF_rdata2[7 : 0]) |
                        ({8{EXE_ST_store[2]}} & EXE_ST_RF_rdata2[7 : 0]) |
                        ({8{EXE_ST_store[1] && Address_ST[1 : 0] == 2'b00}} & EXE_ST_RF_rdata2[31 : 24]) |
                        ({8{EXE_ST_store[1] && Address_ST[1 : 0] == 2'b01}} & EXE_ST_RF_rdata2[23 : 16]) |
                        ({8{EXE_ST_store[1] && Address_ST[1 : 0] == 2'b10}} & EXE_ST_RF_rdata2[15 : 8]) |
                        ({8{EXE_ST_store[1] && Address_ST[1 : 0] == 2'b11}} & EXE_ST_RF_rdata2[7 : 0]) |
                        ({8{EXE_ST_store[0] && Address_ST[1 : 0] == 2'b00}} & EXE_ST_RF_rdata2[7 : 0]);
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
                if(NOP_judge)
                    next_state = IF;
                else
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
    always @(posedge clk)begin
        if(rst)
            cycle_cnt <= 32'b0;
        else
            cycle_cnt <= cycle_cnt + 32'b1;
    end
    assign cpu_perf_cnt_0 = cycle_cnt;
endmodule