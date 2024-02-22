`timescale  10 ns / 1 ns

module simple_cpu(
    input       clk,
    input       rst,

    output [31:0] PC,
    input  [31:0] Instruction,

    output [31:0] Address,
    output        MemWrite,
    output [31:0] Write_data,
    output [3:0] Write_strb,

    input [31:0] Read_data,
    output      MemRead
);

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

    always @(posedge clk) begin
        if(rst)
            cpu_PC <= 32'b0;
        else
            cpu_PC <= cpu_PC_next;
    end
    assign PC = cpu_PC;

    wire [31 : 0] cpu_PC_seq;
    wire [31 : 0] cpu_PC_branch;
    wire cpu_PC_branch_enable;
    wire cpu_PC_jump_enable;
    wire [31 : 0] cpu_PC_jump;
    wire cpu_PC_R_enable;
    wire [31 : 0] cpu_PC_R;

    assign cpu_PC_seq = cpu_PC + 4;
    assign cpu_PC_next = ({32{cpu_PC_branch_enable}} & cpu_PC_branch ) |
                          ({32{cpu_PC_jump_enable}} & cpu_PC_jump) |
                          ({32{cpu_PC_R_enable}} & cpu_PC_R) |
                          ( {32{~cpu_PC_branch_enable && ~cpu_PC_jump_enable && ~cpu_PC_R_enable}} & cpu_PC_seq);

// ID
    wire [5 : 0] Opcode;
    wire [4 : 0] rs;
    wire [4 : 0] rt;
    wire [4 : 0] rd;
    wire [5 : 0] func;
    wire [5 : 0] branch_func;
    wire [15 : 0] Immediate;
    wire [5 : 0] sa;
    wire [25 : 0] instr_index;

    assign rs = Instruction[25 : 21];
    assign rt = Instruction[20 : 16];
    assign rd = Instruction[15 : 11];
    assign Opcode = Instruction[31 : 26];
    assign func = Instruction[5 : 0];
    assign Immediate = Instruction[15 : 0];
    assign sa = Instruction[10 : 6];
    assign branch_func = rt;
    assign instr_index = Instruction[25 : 0];


    wire R_Type_judge;
    wire I_Type_Compute_judge;
    wire J_Type_Judge;
    wire load_judge;
    wire store_Judge;
    wire I_Type_Branch;
    wire Regimm;

    assign R_Type_judge = (Opcode == 6'b0);
    assign I_Type_Compute_judge = (Opcode[5 : 3] == 3'b001);
    assign J_Type_Judge = (Opcode[5:1] == 5'b00001);
    assign load_judge = (Opcode[5 : 3] == 3'b100);
    assign store_Judge = (Opcode[5 : 3] == 3'b101);
    assign I_Type_Branch = (Opcode[5 : 2] == 4'b0001);
    assign Regimm = (Opcode[5 : 0] == 6'b000001);



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


    assign cpu_PC_jump_enable = J_Type_Judge;

    assign cpu_PC_branch = cpu_PC_seq + { {14{Immediate[15]}}, Immediate, 2'b0};
    assign cpu_PC_jump = {cpu_PC[31 : 28] , instr_index, 2'b0};

    assign cpu_PC_R_enable = (MIPS_jr || MIPS_jalr);
    assign cpu_PC_R = RF_rdata1;



// EXE
    
    wire cpu_Overflow;
    wire cpu_CarryOut;
    wire cpu_Zero;
    wire [31 : 0] cpu_Result;

    alu cpu_alu(
        .A(cpu_alu_A),
        .B(cpu_alu_B),
        .ALUop(cpu_ALUop),
        .Overflow(cpu_Overflow),
        .CarryOut(cpu_CarryOut),
        .Zero(cpu_Zero),
        .Result(cpu_Result)
    );

    assign cpu_PC_branch_enable = ( (MIPS_bne && ~cpu_Zero) ||
     (MIPS_beq && cpu_Zero) || 
     (MIPS_bgez && ~RF_rdata1[31]) || 
    (MIPS_bgtz && (~cpu_Zero && !( cpu_Result[31]^cpu_Overflow ) ) ) ||
    (MIPS_blez && (cpu_Zero || ( cpu_Result[31]^cpu_Overflow ) )) ||  
    (MIPS_bltz && (~cpu_Zero && RF_rdata1[31] );
// TODO ALUOP=slt
    wire [31 : 0] cpu_shifter_Result;

    shifter cpu_shifter(
        .A(cpu_shifter_A),
        .B(cpu_shifter_B),
        .Shiftop(cpu_shifter_Shiftop),
        .Result(cpu_shifter_Result)
    );


// MEM
    wire  [31 : 0] Address_real;
    assign Address_real = (RF_rdata1 + Sign_extend_immediate);

    assign Address = (Address_real &  { {30{1'b1}} , 2'b0} ) ;

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

    // 这里根据load指令，确定寄存器堆写有效的部分;
    // TODO
    wire [7 : 0] load_byte;
    assign load_byte = ({8{Address_real[1 : 0] == 2'b00}} & Read_data[7 : 0])|
                       ({8{Address_real[1 : 0] == 2'b01}} & Read_data[15 : 8]) |
                       ({8{Address_real[1 : 0] == 2'b10}} & Read_data[23 : 16])|
                       ({8{Address_real[1 : 0] == 2'b11}} & Read_data[31 : 24]);

    wire [31 : 0] load_wdata_byte;
    assign load_wdata_byte = ({32{MIPS_lb}} & {{24{load_byte[7]}}, load_byte} ) |
                             ({32{MIPS_lbu}} & {{24{1'b0}} , load_byte });

    wire [15 : 0] load_halfword;
    assign load_halfword = ({16{Address_real[1 : 0] == 2'b00}} & Read_data[15 : 0]) |
                           ({16{Address_real[1 : 0] == 2'b10}} & Read_data[31 : 16]);
    
    wire [31 : 0] load_wdata_halfword;
    assign load_wdata_halfword = ({32{MIPS_lh}} & {{16{load_halfword[15]}}, load_halfword}) |
                                 ({32{MIPS_lhu}} & {{16{1'b0}}, load_halfword});
    
    wire [31 : 0] load_wdata_word;
    assign load_wdata_word = ( {32{MIPS_lw}} & Read_data[31 : 0]);

    wire [7 : 0] RF_byte_3;
    wire [7 : 0] RF_byte_2;
    wire [7 : 0] RF_byte_1;
    wire [7 : 0] RF_byte_0;

    wire [31 : 0] RF_load;

    assign RF_byte_3 =  ({8{MIPS_lwl && Address_real[1 : 0] == 2'b11}} & Read_data[31 : 24])  |
                        ({8{MIPS_lwl && Address_real[1 : 0] == 2'b10}} & Read_data[23 : 16])  |
                        ({8{MIPS_lwl && Address_real[1 : 0] == 2'b01}} & Read_data[15 : 8])  |
                        ({8{MIPS_lwl && Address_real[1 : 0] == 2'b00}} & Read_data[7 : 0])  |
                        ({8{MIPS_lwr && Address_real[1 : 0] == 2'b00}} & Read_data[31 : 24]) |
                        ({8{MIPS_lwr && Address_real[1 : 0] != 2'b00}} & RF_rdata2[31 : 24]);


    assign RF_byte_2 =  ({8{MIPS_lwl && Address_real[1 : 0] == 2'b11}} & Read_data[23 : 16])  |
                        ({8{MIPS_lwl && Address_real[1 : 0] == 2'b10}} & Read_data[15 : 8])  |
                        ({8{MIPS_lwl && Address_real[1 : 0] == 2'b01}} & Read_data[7 : 0])  |
                        ({8{MIPS_lwr && Address_real[1 : 0] == 2'b01}} & Read_data[31 : 24])  |
                        ({8{MIPS_lwr && Address_real[1 : 0] == 2'b00}} & Read_data[23 : 16]) |
                        ({8{(MIPS_lwl && Address_real[1 : 0] == 2'b00) || (MIPS_lwr && Address_real[1 : 0] == 2'b10)
                        || (MIPS_lwr && Address_real[1 : 0] == 2'b11)}} & RF_rdata2[23 : 16]);

    assign RF_byte_1 =  ({8{MIPS_lwl && Address_real[1 : 0] == 2'b11}} & Read_data[15 : 8])  |
                        ({8{MIPS_lwl && Address_real[1 : 0] == 2'b10}} & Read_data[7 : 0])  |
                        ({8{MIPS_lwr && Address_real[1 : 0] == 2'b10}} & Read_data[31 : 24])  |
                        ({8{MIPS_lwr && Address_real[1 : 0] == 2'b01}} & Read_data[23 : 16])  |
                        ({8{MIPS_lwr && Address_real[1 : 0] == 2'b00}} & Read_data[15 : 8]) |
                        ({8{(MIPS_lwl && Address_real[1 : 0] == 2'b01) || (MIPS_lwl && Address_real[1 : 0] == 2'b00) 
                        || (MIPS_lwr && Address_real[1 : 0] == 2'b11)  }} & RF_rdata2[15 : 8] );
 
    assign RF_byte_0 =  ({8{MIPS_lwl && Address_real[1 : 0] == 2'b11}} & Read_data[7 : 0])  |
                        ({8{MIPS_lwr && Address_real[1 : 0] == 2'b11}} & Read_data[31 : 24])  |
                        ({8{MIPS_lwr && Address_real[1 : 0] == 2'b10}} & Read_data[23 : 16])  |
                        ({8{MIPS_lwr && Address_real[1 : 0] == 2'b01}} & Read_data[15 : 8])  |
                        ({8{MIPS_lwr && Address_real[1 : 0] == 2'b00}} & Read_data[7 : 0])  |
                        ( {8{MIPS_lwl && Address_real[1 : 0] != 2'b11} } & RF_rdata2[ 7 : 0]);
    
    assign RF_load = ({32{MIPS_lb || MIPS_lbu}} & load_wdata_byte) |
                      ({32{MIPS_lh || MIPS_lhu}} & load_wdata_halfword ) |
                      ( {32{MIPS_lw}} & load_wdata_word) |
                      ({32{MIPS_lwl || MIPS_lwr}} & {RF_byte_3,RF_byte_2,RF_byte_1,RF_byte_0});

    
    // 这里根据store指令，确定mem写有效的部分
    assign MemWrite = (store_Judge);
    assign MemRead = (load_judge);

    assign Write_strb = ({4{MIPS_sb && Address_real[1 : 0] == 2'b11}} & 4'b1000) |
                        ({4{MIPS_sb && Address_real[1 : 0] == 2'b10}} & 4'b0100) |
                        ({4{MIPS_sb && Address_real[1 : 0] == 2'b01}} & 4'b0010) |
                        ({4{MIPS_sb && Address_real[1 : 0] == 2'b00}} & 4'b0001) |
                        ({4{MIPS_sh && Address_real[1 : 0] == 2'b10}} & 4'b1100) |
                        ({4{MIPS_sh && Address_real[1 : 0] == 2'b00}} & 4'b0011) |
                        ({4{MIPS_sw}} & 4'b1111) |
                        ({4{MIPS_swl && Address_real[1 : 0] == 2'b00}} & 4'b0001) |
                        ({4{MIPS_swl && Address_real[1 : 0] == 2'b01}} & 4'b0011) |
                        ({4{MIPS_swl && Address_real[1 : 0] == 2'b10}} & 4'b0111) |
                        ({4{MIPS_swl && Address_real[1 : 0] == 2'b11}} & 4'b1111) |
                        ({4{MIPS_swr && Address_real[1 : 0] == 2'b00}} & 4'b1111) |
                        ({4{MIPS_swr && Address_real[1 : 0] == 2'b01}} & 4'b1110) |
                        ({4{MIPS_swr && Address_real[1 : 0] == 2'b10}} & 4'b1100) |
                        ({4{MIPS_swr && Address_real[1 : 0] == 2'b11}} & 4'b1000);
    
    wire [7 : 0] Mem_byte_3;
    wire [7 : 0] Mem_byte_2;
    wire [7 : 0] Mem_byte_1;
    wire [7 : 0] Mem_byte_0;

    assign Mem_byte_3 = ({8{MIPS_sb && Address_real[1 : 0] == 2'b11}} & RF_rdata2[7 : 0]) |
                        ({8{MIPS_sh && Address_real[1 : 0] == 2'b10}} & RF_rdata2[15 : 8]) |
                        ({8{MIPS_sw}} & RF_rdata2[31 : 24]) |
                        ({8{MIPS_swl && Address_real[1 : 0] == 2'b11}} & RF_rdata2[31 : 24]) |
                        ({8{MIPS_swr && Address_real[1 : 0] == 2'b00}} & RF_rdata2[31 : 24]) |
                        ({8{MIPS_swr && Address_real[1 : 0] == 2'b01}} & RF_rdata2[23 : 16]) |
                        ({8{MIPS_swr && Address_real[1 : 0] == 2'b10}} & RF_rdata2[15 : 8]) |
                        ({8{MIPS_swr && Address_real[1 : 0] == 2'b11}} & RF_rdata2[7 : 0]);
    
    assign Mem_byte_2 = ({8{MIPS_sb && Address_real[1 : 0] == 2'b10}} & RF_rdata2[7 : 0]) |
                        ({8{MIPS_sh && Address_real[1 : 0] == 2'b10}} & RF_rdata2[7 : 0]) |
                        ({8{MIPS_sw}} & RF_rdata2[23 : 16]) |
                        ({8{MIPS_swl && Address_real[1 : 0] == 2'b10}} & RF_rdata2[31 : 24]) |
                        ({8{MIPS_swl && Address_real[1 : 0] == 2'b11}} & RF_rdata2[23 : 16]) |
                        ({8{MIPS_swr && Address_real[1 : 0] == 2'b00}} & RF_rdata2[23 : 16]) |
                        ({8{MIPS_swr && Address_real[1 : 0] == 2'b01}} & RF_rdata2[15 : 8]) |
                        ({8{MIPS_swr && Address_real[1 : 0] == 2'b10}} & RF_rdata2[7 : 0]);

    assign Mem_byte_1 = ({8{MIPS_sb && Address_real[1 : 0] == 2'b01}} & RF_rdata2[7 : 0]) |
                        ({8{MIPS_sh && Address_real[1 : 0] == 2'b00}} & RF_rdata2[15 : 8]) |
                        ({8{MIPS_sw}} & RF_rdata2[15 : 8]) |
                        ({8{MIPS_swl && Address_real[1 : 0] == 2'b01}} & RF_rdata2[31 : 24]) |
                        ({8{MIPS_swl && Address_real[1 : 0] == 2'b10}} & RF_rdata2[23 : 16]) |
                        ({8{MIPS_swl && Address_real[1 : 0] == 2'b11}} & RF_rdata2[15 : 8]) |
                        ({8{MIPS_swr && Address_real[1 : 0] == 2'b00}} & RF_rdata2[15 : 8]) |
                        ({8{MIPS_swr && Address_real[1 : 0] == 2'b01}} & RF_rdata2[7 : 0]);
    
     assign Mem_byte_0 = ({8{MIPS_sb && Address_real[1 : 0] == 2'b00}} & RF_rdata2[7 : 0]) |
                        ({8{MIPS_sh && Address_real[1 : 0] == 2'b00}} & RF_rdata2[7 : 0]) |
                        ({8{MIPS_sw}} & RF_rdata2[7 : 0]) |
                        ({8{MIPS_swl && Address_real[1 : 0] == 2'b00}} & RF_rdata2[31 : 24]) |
                        ({8{MIPS_swl && Address_real[1 : 0] == 2'b01}} & RF_rdata2[23 : 16]) |
                        ({8{MIPS_swl && Address_real[1 : 0] == 2'b10}} & RF_rdata2[15 : 8]) |
                        ({8{MIPS_swl && Address_real[1 : 0] == 2'b11}} & RF_rdata2[7 : 0]) |
                        ({8{MIPS_swr && Address_real[1 : 0] == 2'b00}} & RF_rdata2[7 : 0]);

    assign Write_data = {Mem_byte_3,Mem_byte_2,Mem_byte_1,Mem_byte_0};

// WB

    assign RF_wen =   (R_Type_judge && ~MIPS_jr && ~MIPS_movn && ~MIPS_movz) |
                      (MIPS_movn && ~cpu_Zero ) |
                      (MIPS_movz && cpu_Zero) |
                      (I_Type_Compute_judge ) |
                      (load_judge ) |
                      (MIPS_jal);
            
    assign RF_waddr = ( {5{R_Type_judge}} & rd ) |
                      ( {5{I_Type_Compute_judge}} & rt ) |
                      ( {5{load_judge}} & rt) |
                      ( {5{MIPS_jal}} & 5'd31);
    wire [31 : 0] PC_add;
    assign PC_add = cpu_PC + 8;

    assign RF_wdata = ( {32{MIPS_addu || MIPS_subu || MIPS_and || MIPS_nor || MIPS_or || MIPS_xor || MIPS_slt || MIPS_sltu}} &   cpu_Result) |
                      ( {32{MIPS_sll || MIPS_sllv || MIPS_sra || MIPS_srav || MIPS_srl || MIPS_srlv}} & cpu_shifter_Result) |
                      (  {32{MIPS_jalr}} & (PC_add)) |
                      (  {32{MIPS_movn || MIPS_movz}} & RF_rdata1) |
                      (  {32{I_Type_Compute_judge && ~MIPS_lui}} & cpu_Result) |
                      (  {32{MIPS_lui}} & {Immediate ,{16{1'b0}}}) |
                      (  {32{load_judge}} & RF_load) |
                      (  {32{MIPS_jal}} & (PC_add));

endmodule
