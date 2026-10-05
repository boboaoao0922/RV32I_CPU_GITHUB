import RISC_V_PKG::*;
module IDEXReg (
    input logic clk,
    input logic rst_n,
    //from controller
    input Reg_state i_state,  //controller control reg's state
    //from IFIDReg
    input logic [31:0] i_inst, // inst provided by IFID, for debug
    input logic [31:0] i_PC,   // PC provided by IFID
    input logic i_reg_valid, // IFID valid

    //from decoder
    input Opcode i_opcode,
    //input ImmSel i_immsel,
    input ALU_Operation i_alu_operation,
    input LoadStore_func3 i_loadstore_func3,
    input Mem_acc_type i_mem_acc_type, // memory write enable
    input Mem_acc_size i_mem_acc_size,
    input logic i_reg_we, //register file write enable
    input Branch_sel i_branch_sel,
    input Inst_type i_inst_type, // for debug
    input logic [4:0] i_rs1,
    input logic [4:0] i_rs2,
    input logic [4:0] i_rd,
    input WB_source i_wb_source,
    input ALU_source i_alu_source1,
    input ALU_source i_alu_source2,
    input BJ_type i_bj_type,
    input Use_rs i_use_rs,
    input logic i_illegal,   // for debug
    //from ImmGen
    input logic [31:0] i_imm, // immediate
    //from Regfile
    input logic [31:0] i_rs1_data,
    input logic [31:0] i_rs2_data,

    input logic  i_exc_valid,
    input Mcause i_exc_mcause,
    input logic [31:0] i_exc_tval,

    input logic i_decode_fault_alive,
    input Mcause i_decode_fault_cause,
    input logic [31:0] i_decoder_fault_tval,

    input logic i_flag_csr, // indicate if csr or not
    input logic i_csr_we,
    input logic [31:0] i_csr_old_data,
    input logic [31:0] i_zimm, 
    input logic [2:0] i_csr_func3,
    input Csr_sel i_csr_rd,
    input logic i_flag_mret,


    output logic [31:0] o_inst,  // ouptut instruction
    output logic [31:0] o_PC,  // output PC
    output logic o_reg_valid,  // register valid

    output Opcode o_opcode,
    //output ImmSel o_immsel,
    output ALU_Operation o_alu_operation,
    output LoadStore_func3 o_loadstore_func3,
    output Mem_acc_type o_mem_acc_type, // memory write enable
    output Mem_acc_size o_mem_acc_size,
    output logic o_reg_we, //register file write enable
    output Branch_sel o_branch_sel,
    output Inst_type o_inst_type, // for debug
    output logic [4:0] o_rs1,
    output logic [4:0] o_rs2,
    output logic [4:0] o_rd,
    output WB_source o_wb_source,
    output ALU_source o_alu_source1,
    output ALU_source o_alu_source2,
    output BJ_type o_bj_type,
    output Use_rs o_use_rs,
    output logic o_illegal,
    output logic [31:0] o_imm,
    output logic [31:0] o_rs1_data,
    output logic [31:0] o_rs2_data,

    output logic o_exc_valid,
    output Mcause o_exc_mcause,
    output logic [31:0] o_exc_tval,

    output logic o_flag_csr, // indicate if csr or not
    output logic o_csr_we,
    output logic [31:0] o_csr_old_data,
    output logic [31:0] o_zimm,
    output logic [2:0] o_csr_func3,
    output Csr_sel o_csr_rd,
    output logic o_flag_mret
);


always_ff@(posedge clk,negedge rst_n) begin
    if(!rst_n) 
        o_reg_valid <= 0;
    else begin
        case(i_state)
            Reg_BUBBLE: o_reg_valid <= 0;
            Reg_HOLD: o_reg_valid <= o_reg_valid;
            Reg_ADVANCE: o_reg_valid <= i_reg_valid;
            default: o_reg_valid <= 0;
        endcase
    end
end

always_ff@(posedge clk,negedge rst_n) begin
    if(!rst_n)
        o_exc_valid <= 0;
    else begin
        case(i_state)
            Reg_BUBBLE: o_exc_valid <= 0;
            Reg_HOLD: o_exc_valid <= o_exc_valid;
            Reg_ADVANCE: o_exc_valid <= i_reg_valid && (i_exc_valid || i_decode_fault_alive);
            default: o_exc_valid <= 0;
        endcase
    end
end

always_ff@(posedge clk,negedge rst_n) begin
    if(!rst_n) begin
        o_inst <= 0;
        o_PC <= 0;
        o_opcode <= OP_OP;
        o_alu_operation <= ALU_ADD;
        o_loadstore_func3 <= LS_B;
        o_mem_acc_type <= Mem_none;
        o_mem_acc_size <= Mem_acc_size_none;
        o_reg_we <= 0;
        o_branch_sel <= B_EQ;
        o_inst_type <= Inst_ADDI;
        o_rs1 <= 0;
        o_rs2 <= 0;
        o_rd <= 0;
        o_wb_source <= WB_alu;
        o_alu_source1 <= ALUsrc_rs1;
        o_alu_source2 <= ALUsrc_imm;
        o_bj_type <= BJ_none;
        o_use_rs <= Use_rs_none;
        o_illegal <= 0;
        o_imm <= 0;
        o_rs1_data <= 0;
        o_rs2_data <= 0;
    end else begin
        if(i_state == Reg_ADVANCE) begin
            o_inst <= i_inst;
            o_PC <= i_PC;
            o_opcode <= i_opcode;
            o_alu_operation <= i_alu_operation;
            o_loadstore_func3 <= i_loadstore_func3;
            o_mem_acc_size <= i_mem_acc_size;
            o_branch_sel <= i_branch_sel;
            o_inst_type <= i_inst_type;
            o_rs1 <= i_rs1;
            o_rs2 <= i_rs2;
            o_rd <= i_rd;
            o_wb_source <= i_wb_source;
            o_alu_source1 <= i_alu_source1;
            o_alu_source2 <= i_alu_source2;
            o_use_rs <= i_use_rs;
            o_illegal <= i_illegal;
            o_imm <= i_imm;
            o_rs1_data <= i_rs1_data;
            o_rs2_data <= i_rs2_data;
            if(i_reg_valid && (i_exc_valid || i_decode_fault_alive)) begin
                o_reg_we <= 0;
                o_mem_acc_type <= Mem_none;
                o_bj_type <= BJ_none;
            end else begin
                o_reg_we <= i_reg_we;
                o_mem_acc_type <= i_mem_acc_type;
                o_bj_type <= i_bj_type;
            end
        end
    end
end

always_ff@(posedge clk,negedge rst_n) begin
    if(!rst_n)begin
        o_exc_mcause <= Mcause_INST_MISALIGNED;
        o_exc_tval <= 32'd0;
    end else begin
        if(i_state == Reg_ADVANCE)begin
            if( i_reg_valid && (!i_exc_valid && i_decode_fault_alive))begin
                o_exc_mcause <=i_decode_fault_cause;
                o_exc_tval <= i_decoder_fault_tval; 
            end else begin
                o_exc_mcause <= i_exc_mcause;
                o_exc_tval <= i_exc_tval;
            end
        end
    end
end

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)begin
        o_flag_csr <= 0;
        o_csr_we <= 0;
        o_csr_old_data <= 0;
        o_zimm <= 0;
        o_csr_func3 <= 0;
        o_csr_rd <= Csr_mstatus;
        o_flag_mret <= 0;
    end else begin
        if(i_state == Reg_ADVANCE)begin
            o_flag_csr <= i_flag_csr;
            o_csr_we <= i_csr_we;
            o_csr_old_data <= i_csr_old_data;
            o_zimm <= i_zimm;
            o_csr_func3 <= i_csr_func3;
            o_csr_rd <= i_csr_rd;
            o_flag_mret <= i_flag_mret;
        end 
    end
end



endmodule