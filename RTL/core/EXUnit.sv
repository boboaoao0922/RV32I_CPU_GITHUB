import RISC_V_PKG::*;
module EXUnit (
    input logic [31:0] i_PC,   // PC provided by IFID
    input logic i_reg_valid, // IFID valid
    //from IDEX reg
    //input Opcode i_opcode,
    input ALU_Operation i_alu_operation,
    input Branch_sel i_branch_sel,
    input ALU_source i_alu_source1,
    input ALU_source i_alu_source2,
    input BJ_type i_bj_type,
    input logic i_illegal,   // for debug
    input logic [31:0] i_imm, 
    input logic [31:0] i_rs1_data,
    input logic [31:0] i_rs2_data,

    input Mem_acc_type i_mem_acc_type,
    input Mem_acc_size i_mem_acc_size,

    output logic o_redirect,
    output logic [31:0] o_redirect_addr,
    output logic [31:0] o_PCA4,
    output logic [31:0] o_alu_result,

    output logic o_exc_valid,
    output Mcause o_mcause,
    output logic [31:0] o_mtval
);

logic [31:0] alu_operand1,alu_operand2;
logic [31:0] PC_jump,PC_branch;
logic redirect_branch;
logic jump_type;
logic ls_misalignment;
logic inst_misalignment;

always_comb begin
    case(i_alu_source1)
        ALUsrc_rs1: alu_operand1 = i_rs1_data;
        ALUsrc_rs2: alu_operand1 = i_rs2_data;
        ALUsrc_imm: alu_operand1 = i_imm;
        ALUsrc_PC: alu_operand1 = i_PC;
        ALUsrc_4: alu_operand1 = 4;
        default: alu_operand1 = 0;
    endcase
end

always_comb begin
    case(i_alu_source2)
        ALUsrc_rs1: alu_operand2 = i_rs1_data;
        ALUsrc_rs2: alu_operand2 = i_rs2_data;
        ALUsrc_imm: alu_operand2 = i_imm;
        ALUsrc_PC: alu_operand2 = i_PC;
        ALUsrc_4: alu_operand2 = 4;
        default: alu_operand2 = 0;
    endcase
end

assign jump_type = i_bj_type == BJ_jalr;

always_comb begin
    if(i_reg_valid && !i_illegal)begin
        case(i_bj_type)
            BJ_none: o_redirect = 0;
            BJ_branch: o_redirect = redirect_branch;
            BJ_jal,
            BJ_jalr: o_redirect = 1;
            default: o_redirect = 0;
        endcase
    end else 
        o_redirect = 0;
end

always_comb begin
    if(i_reg_valid && !i_illegal)begin
        case(i_bj_type)
            BJ_none: o_redirect_addr = 0;
            BJ_branch: o_redirect_addr = PC_branch;
            BJ_jal,
            BJ_jalr: o_redirect_addr = PC_jump;
            default: o_redirect_addr = 0;
        endcase
    end else 
        o_redirect_addr = 0;
end

ALU u_ALU(
    .operand1(alu_operand1),
    .operand2(alu_operand2),
    .op_sel(i_alu_operation),
    .alu_out(o_alu_result)
);

BchCmp u_BchCmp(
    .rs1(i_rs1_data),
    .rs2(i_rs2_data),
    .immidate(i_imm),
    .branch_sel(i_branch_sel),
    .PC_in(i_PC),
    .PC_out(PC_branch),
    .taken(redirect_branch)
);

JumpUnit u_JumpUnit(
    .jump_type(jump_type), // 0: JAL, 1:JALR
    .PC_in(i_PC),
    .rs1(i_rs1_data),
    .imm(i_imm),
    .PC_out(PC_jump),
    .Jump_out(o_PCA4)
);

assign inst_misalignment = i_reg_valid && o_redirect && (o_redirect_addr[1:0] != 2'b00);

always_comb begin
    if(i_reg_valid && (i_mem_acc_type == Mem_load || i_mem_acc_type == Mem_store) )begin
        case(i_mem_acc_size)
            Mem_acc_size_W: ls_misalignment = ( o_alu_result[1:0] != 2'b00 ) ? 1 : 0;
            Mem_acc_size_H: ls_misalignment = ( o_alu_result[1:0] != 2'b00 && o_alu_result[1:0] != 2'b10 ) ? 1 : 0;
            default: ls_misalignment = 0;
        endcase  
    end else
        ls_misalignment = 0;
end

assign o_exc_valid = ls_misalignment || inst_misalignment;

always_comb begin
    if(ls_misalignment)begin
        if(i_mem_acc_type == Mem_load)
            o_mcause = Mcause_LOAD_MISALIGNED;
        else
            o_mcause = Mcause_STORE_MISALIGNED;
    end else //if(inst_misalignment)
        o_mcause = Mcause_INST_MISALIGNED;
end

always_comb begin
    if(ls_misalignment)
        o_mtval = o_alu_result;
    else if(inst_misalignment)
        o_mtval = o_redirect_addr;
    else
        o_mtval = 0;
end

endmodule