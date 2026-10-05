import RISC_V_PKG::*;
module WBUnit (
    input clk,
    input rst_n,
    input logic retire_allowed, //from controller
    input logic trap_allowed, //from controller
    input logic trap_interrupt, //from controller, indicate pipeline is empty, go trap now
    input logic [31:0] i_PCA4,
    input logic i_reg_valid,
    input logic i_reg_we, //register file write enable
    input logic [4:0] i_rd,
    input WB_source i_wb_source,
    input logic i_illegal,   // for debug
    input logic [31:0] i_imm, // immediate
    input logic [31:0] i_alu_result,
    input logic [31:0] i_mem_rsp_data,
    input Inst_type i_inst_type,

    input logic i_exc_valid,
    input logic i_flag_csr,
    input logic i_csr_we,
    input logic [31:0] i_csr_old_data,
    //input logic [31:0] i_csr_wdata,
    //input Csr_sel i_csr_WB_rd, //for WB write csr

    input logic [31:0] i_PC,
    input logic i_redirect, // it's from MEMWB Reg, means branch /jump architechturally should redirect.
    input logic [31:0] i_redirect_addr, // it's from MEMWB Reg, means branch /jump redirect address.
    input logic [31:0] i_mcause,
    input logic [31:0] i_mtval,
    input logic [31:0] i_mepc, // for corner case, mret -> interrupt, architechtural next should be mepc

    input logic i_flag_mret,
 
    output logic o_reg_we, //register file write enable
    output logic [4:0] o_rd,
    output logic [31:0] o_wb_data,
    output logic retire_fire,

    output Commit_type retire_type,

    output logic o_csr_we,
    output logic o_trap,
    output logic o_mret,
    output logic [31:0] o_trap_mepc,
    output logic [31:0] o_trap_mcause,
    output logic [31:0] o_trap_mtval
);

logic [31:0] architectural_next_PC;

assign retire_fire = retire_allowed && i_reg_valid && ((i_exc_valid && (i_inst_type == Inst_ECALL || i_inst_type == Inst_EBREAK)) || !i_exc_valid);
assign o_reg_we = retire_fire && i_reg_we && (i_rd != 0);
assign o_rd = i_rd;
always_comb begin
    case(i_wb_source)
        WB_alu: o_wb_data = i_alu_result;
        WB_mem: o_wb_data = i_mem_rsp_data;
        WB_imm: o_wb_data = i_imm;
        WB_PCA4: o_wb_data = i_PCA4;
        WB_csr: o_wb_data = i_csr_old_data;
        default: o_wb_data = 0;
    endcase
end

always_comb begin
    if(retire_fire)begin
        if(i_inst_type == Inst_ECALL || i_inst_type == Inst_EBREAK)
            retire_type = Commit_trap;
        else if(i_inst_type == Inst_MRET)
            retire_type = Commit_mret;
        else
            retire_type = Commit_normal;
    end else
        retire_type = Commit_none;
end

assign o_csr_we = retire_fire && i_flag_csr && i_csr_we;
assign o_trap = trap_allowed && ((i_reg_valid && i_exc_valid) || trap_interrupt);
assign o_mret = retire_fire && i_flag_mret;

assign o_trap_mepc = trap_interrupt ? architectural_next_PC : i_PC;
assign o_trap_mcause = trap_interrupt ? Mcause_EXT_INTERRUPT : i_mcause;
assign o_trap_mtval = trap_interrupt ? 0 : i_mtval;

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)
        architectural_next_PC <= 0;
    else begin
        if(i_reg_valid)begin
            if(i_flag_mret)
                architectural_next_PC <= i_mepc;
            else if(i_redirect)
                architectural_next_PC <= i_redirect_addr;
            else
                architectural_next_PC <= i_PCA4;
        end
    end
end



endmodule