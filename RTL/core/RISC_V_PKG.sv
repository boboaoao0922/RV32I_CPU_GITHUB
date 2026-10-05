

package RISC_V_PKG;

    typedef enum logic [6:0] {
        OP_LOAD    = 7'b0000011,
        OP_FENCE   = 7'b0001111,
        OP_OP_IMM  = 7'b0010011,
        OP_AUIPC   = 7'b0010111,
        OP_STORE   = 7'b0100011,
        OP_OP      = 7'b0110011,
        OP_LUI     = 7'b0110111,
        OP_BRANCH  = 7'b1100011,
        OP_JALR    = 7'b1100111,
        OP_JAL     = 7'b1101111,
        OP_SYSTEM  = 7'b1110011,
        OP_ERR  = 7'b1111111
    } Opcode;

    typedef enum logic [2:0] {
        Immsel_I = 3'b000,
        Immsel_S = 3'b001,
        Immsel_B = 3'b010,
        Immsel_U = 3'b011,
        Immsel_J = 3'b100,
        Immsel_None = 3'b111
    } ImmSel;
	/*
    typedef enum logic [2:0] {
        ALU_ADD_SUB = 3'b000,
        ALU_SLL     = 3'b001,
        ALU_SLT     = 3'b010,
        ALU_SLTU    = 3'b011,
        ALU_XOR     = 3'b100,
        ALU_SR      = 3'b101,
        ALU_OR      = 3'b110,
        ALU_AND     = 3'b111
    } ALU_func3;
    */
    typedef enum logic [3:0] {
        ALU_ADD = 4'd0,  
        ALU_SUB = 4'd1,
        ALU_SLL = 4'd2, //shift left logical
        ALU_SLT = 4'd3, //select less than
        ALU_SLTU = 4'd4, // select less than unsigned
        ALU_XOR = 4'd5,
        ALU_SRL = 4'd6, //shift right logical
        ALU_SRA = 4'd7, //shift right arithmetic
        ALU_OR = 4'd8,
        ALU_AND = 4'd9,
        ALU_ERR = 4'd10
        //ALU_SLTIU = 4'd10;
    } ALU_Operation;

    typedef enum logic [2:0] {
        LS_B = 3'b000,
        LS_H = 3'b001,
        LS_W = 3'b010,
        LS_BU = 3'b100,
        LS_HU = 3'b101,
        LS_ERR = 3'b111
    } LoadStore_func3;

    typedef enum logic [2:0] {
        B_EQ = 3'b000,
        B_BNE = 3'b001,
        B_BLT = 3'b100,
        B_BGE = 3'b101,
        B_BLTU = 3'b110,
        B_BGEU = 3'b111,
        B_ERR = 3'b010
    } Branch_sel;

    typedef enum logic [2:0] {  
        fetch_load = 3'd0,
        fetch_hold = 3'd1,
        fetch_clear = 3'd2,
        fetch_redirect = 3'd3,
        fetch_capture = 3'd4
    } fetch_state;

    typedef enum logic [5:0] {  
        Inst_ADD = 6'd0,
        Inst_SUB = 6'd1,
        Inst_SLL = 6'd2,
        Inst_SLT = 6'd3,
        Inst_SLTU = 6'd4,
        Inst_XOR = 6'd5,
        Inst_SRL = 6'd6,
        Inst_SRA = 6'd7,
        Inst_OR = 6'd8,
        Inst_AND = 6'd9,
        Inst_ADDI = 6'd10,
        Inst_SLTI = 6'd11,
        Inst_SLTIU = 6'd12,
        Inst_XORI = 6'd13,
        Inst_ORI = 6'd14,
        Inst_ANDI = 6'd15,
        Inst_SLLI = 6'd16,
        Inst_SRLI = 6'd17,
        Inst_SRAI = 6'd18,
        Inst_LB = 6'd19,
        Inst_LH = 6'd20,
        Inst_LW = 6'd21,
        Inst_LBU = 6'd22,
        Inst_LHU = 6'd23,
        Inst_SB = 6'd24,
        Inst_SH = 6'd25,
        Inst_SW = 6'd26,
        Inst_BEQ = 6'd27,
        Inst_BNE = 6'd28,
        Inst_BLT = 6'd29,
        Inst_BGE = 6'd30,
        Inst_BLTU = 6'd31,
        Inst_BGEU = 6'd32,
        Inst_JAL = 6'd33,
        Inst_JALR = 6'd34,
        Inst_LUI = 6'd35,
        Inst_AUIPC = 6'd36,
        Inst_FENCE = 6'd37,
        Inst_ECALL = 6'd38,
        Inst_EBREAK = 6'd39,
        Inst_CSRRW = 6'd40,
        Inst_CSRRS = 6'd41,
        Inst_CSRRC = 6'd42,
        Inst_CSRRWI = 6'd43,
        Inst_CSRRSI = 6'd44,
        Inst_CSRRCI = 6'd45,
        Inst_MRET = 6'd46,
        Inst_ERR = 6'd47
    } Inst_type;

    typedef enum logic [2:0] {   // write back source
        WB_alu = 3'd0,
        WB_mem = 3'd1,
        WB_PCA4 = 3'd2,
        WB_imm = 3'd3,
        WB_csr = 3'd4
    } WB_source;

    typedef enum logic [2:0] {   //ALU operand source
        ALUsrc_rs1 = 3'd0,
        ALUsrc_rs2 = 3'd1,
        ALUsrc_0 = 3'd2,
        ALUsrc_PC = 3'd3,
        ALUsrc_imm = 3'd4,
        ALUsrc_4 = 3'd5
    } ALU_source;

    typedef enum logic [1:0] {   // branch / jump type
        BJ_none = 2'd0,
        BJ_branch = 2'd1,
        BJ_jal = 2'd2,
        BJ_jalr = 2'd3
    } BJ_type;

    typedef enum logic [1:0] {  // if use rs1 / rs2 , for hazard / forward unit
        Use_rs_none = 2'd0,
        Use_rs_rs1 = 2'd1,
        Use_rs_rs2 = 2'd2,
        Use_rs_all = 2'd3
    } Use_rs;

    typedef enum logic [1:0] {   // memory access type
        Mem_none = 2'd0,
        Mem_load = 2'd1,
        Mem_store = 2'd2,
        Mem_flush = 2'd3
    } Mem_acc_type;

    typedef enum logic [1:0] {   // memory acess size
        Mem_acc_size_none = 2'd0,
        Mem_acc_size_B = 2'd1,  // byte
        Mem_acc_size_H = 2'd2,  // half word
        Mem_acc_size_W = 2'd3  // word
    } Mem_acc_size;


    typedef enum logic [1:0] {   // pipeline register state
        Reg_BUBBLE = 2'd0,  
        Reg_HOLD = 2'd1,  // 
        Reg_ADVANCE = 2'd2  // 
        //Reg_ = 2'd3  // 
    } Reg_state;

    typedef enum logic [1:0] {
        Con_RESET = 2'd0,
        Con_WORK = 2'd1
    } Con_state;

    typedef enum logic [31:0]{
        Mcause_INST_MISALIGNED = 32'h0000_0000,
        Mcause_INST_ACCFAULT = 32'h0000_0001,
        Mcause_INST_ILLEGAL  = 32'h0000_0002,
        Mcause_EBREAK        = 32'h0000_0003,
        Mcause_LOAD_MISALIGNED = 32'h0000_0004,
        Mcause_LOAD_ACCFAULT = 32'h0000_0005,
        Mcause_STORE_MISALIGNED = 32'h0000_0006,
        Mcause_STORE_ACCFAULT = 32'h0000_0007,
        Mcause_ECALL         = 32'h0000_000B,
        Mcause_EXT_INTERRUPT      = 32'h8000_000B
    } Mcause;

    typedef enum logic [1:0]{
        Csr_op_RW = 2'd0,
        Csr_op_RS = 2'd1,
        Csr_op_RC = 2'd2
    } Csr_op_t;
    
    typedef enum logic [2:0]{
        Csr_mstatus = 3'd0,
        Csr_mie = 3'd1,
        Csr_mtvec = 3'd2,
        Csr_mepc = 3'd3,
        Csr_mcause = 3'd4,
        Csr_mtval = 3'd5,
        Csr_mip = 3'd6
    } Csr_sel;

    typedef enum logic [1:0]{
        Commit_none = 2'd0,
        Commit_normal = 2'd1,
        Commit_trap = 2'd2,
        Commit_mret = 2'd3
    } Commit_type;
    

endpackage