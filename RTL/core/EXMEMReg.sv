import RISC_V_PKG::*;
module EXMEMReg (
    input logic clk,
    input logic rst_n,
    //from controller
    input Reg_state i_state,  //controller control reg's state
    //from IFIDReg
    input logic [31:0] i_inst, // inst provided by IFID, for debug
    input logic [31:0] i_PC,   // For debug
    input logic [31:0] i_PCA4,
    input logic i_reg_valid, // IFID valid

    input LoadStore_func3 i_loadstore_func3,
    input Mem_acc_type i_mem_acc_type, // memory write enable
    input Mem_acc_size i_mem_acc_size,
    input logic i_reg_we, //register file write enable
    input Inst_type i_inst_type, // for debug
    input logic [4:0] i_rd,
    input WB_source i_wb_source,
    input logic i_illegal,   // for debug
    input logic [31:0] i_imm, // immediate
    input logic [31:0] i_alu_result,

    input logic  i_exc_valid,
    input Mcause i_exc_mcause,
    input logic [31:0] i_exc_tval,

    input logic i_exe_fault_alive,
    input Mcause i_exe_fault_cause,
    input logic [31:0] i_exe_fault_tval,

    input logic i_flag_csr, 
    input logic i_csr_we,
    input logic [31:0] i_csr_result,
    input logic [31:0] i_csr_old_data,
    input Csr_sel i_csr_rd,
    input logic i_flag_mret,
    input logic i_redirect,
    input logic [31:0] i_redirect_addr,
 
    output logic [31:0] o_inst,  // ouptut instruction
    output logic [31:0] o_PC,  // output PC
    output logic [31:0] o_PCA4,
    output logic o_reg_valid,  // register valid

    output LoadStore_func3 o_loadstore_func3,
    output Mem_acc_type o_mem_acc_type, // memory write enable
    output Mem_acc_size o_mem_acc_size,
    output logic o_reg_we, //register file write enable
    output Inst_type o_inst_type, // for debug
    output logic [4:0] o_rd,
    output WB_source o_wb_source,
    output logic o_illegal,
    output logic [31:0] o_imm,
    output logic [31:0] o_alu_result,

    output logic o_exc_valid,
    output Mcause o_exc_mcause,
    output logic [31:0] o_exc_tval,

    output logic o_flag_csr, 
    output logic o_csr_we,
    output logic [31:0] o_csr_result,
    output logic [31:0] o_csr_old_data,
    output Csr_sel o_csr_rd,
    output logic o_flag_mret,
    output logic o_redirect,
    output logic [31:0] o_redirect_addr
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
            Reg_ADVANCE: o_exc_valid <= i_reg_valid && (i_exc_valid || i_exe_fault_alive);
            default: o_exc_valid <= 0;
        endcase
    end
end


always_ff@(posedge clk,negedge rst_n) begin
    if(!rst_n) begin
        o_inst <= 0;
        o_PC <= 0;
        o_PCA4 <= 0;
        o_loadstore_func3 <= LS_B;
        o_mem_acc_type <= Mem_none;
        o_mem_acc_size <= Mem_acc_size_none;
        o_reg_we <= 0;
        o_inst_type <= Inst_ADDI;
        o_rd <= 0;
        o_wb_source <= WB_alu;
        o_illegal <= 0;
        o_imm <= 0;
        o_alu_result <= 0;
        o_redirect <= 0;
        o_redirect_addr <= 0;
    end else begin
        if(i_state == Reg_ADVANCE) begin
            o_inst <= i_inst;
            o_PC <= i_PC;
            o_PCA4 <= i_PCA4;
            o_loadstore_func3 <= i_loadstore_func3;
            o_mem_acc_size <= i_mem_acc_size;
            o_inst_type <= i_inst_type;
            o_rd <= i_rd;
            o_wb_source <= i_wb_source;
            o_illegal <= i_illegal;
            o_imm <= i_imm;
            o_alu_result <= i_alu_result;
            o_redirect <= i_redirect;
            o_redirect_addr <= i_redirect_addr;
            if(i_reg_valid && (i_exc_valid || i_exe_fault_alive))begin
                o_reg_we <= 0;
                o_mem_acc_type <= Mem_none;
            end else begin
                o_reg_we <= i_reg_we;
                o_mem_acc_type <= i_mem_acc_type;
            end
        end
    end
end

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)begin
        o_exc_mcause <= Mcause_INST_MISALIGNED;
        o_exc_tval <= 0;
    end else begin
        if(i_state == Reg_ADVANCE && i_reg_valid)begin
            if(!i_exc_valid && i_exe_fault_alive)begin
                o_exc_mcause <= i_exe_fault_cause;
                o_exc_tval <= i_exe_fault_tval;
            end else begin
                o_exc_mcause <= i_exc_mcause;
                o_exc_tval <= i_exc_tval;
            end
        end
    end
end


always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)begin
        o_csr_we <= 0;
        o_flag_csr <= 0;
        o_csr_result <= 0;
        o_csr_old_data <= 0;
        o_csr_rd <= Csr_mstatus;
        o_flag_mret <= 0;
    end else begin
        if(i_state == Reg_ADVANCE)begin
            o_csr_we <= i_csr_we;
            o_flag_csr <= i_flag_csr;
            o_csr_result <= i_csr_result;
            o_csr_old_data <= i_csr_old_data;
            o_csr_rd <= i_csr_rd;
            o_flag_mret <= i_flag_mret;
        end
    end
end

endmodule