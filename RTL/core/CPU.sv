import RISC_V_PKG::*;
module CPU(
    input logic clk,
    input logic rst_n,
    
    input logic MEIP,

    output logic commit_fire,
    output logic [31:0] commit_PC, //for debug
    output logic [31:0] commit_inst,
    output logic [4:0] commit_rd,
    output logic commit_we,
    output logic [31:0] commit_wb_data,
    output Commit_type commit_type,

    // I - cache interface
    input logic i_cpu_req_ready_I_cache,
    input logic i_cpu_rsp_valid_I_cache,
    input logic i_cpu_acc_fault_I_cache,
    input logic [31:0]  i_cpu_rsp_data_I_cache,
    output logic o_cpu_req_valid_I_cache,
    output logic [31:0]  o_cpu_req_addr_I_cache,

    // D - cache interface
    input logic         i_cpu_req_ready_D_cache,  
    input logic         i_cpu_rsp_load_ack_D_cache, 
    input logic [31:0]  i_cpu_rsp_data_D_cache,
	input logic         i_cpu_rsp_flush_ack_D_cache, 
	input logic 		i_cpu_rsp_store_ack_D_cache,
    input logic         i_cpu_acc_fault_D_cache, 
	input logic 		i_b_err_bit_D_cache,
    
    output  logic         o_cpu_req_LS_valid_D_cache,  
    output  logic [31:0]  o_cpu_req_addr_D_cache,
	output  logic [31:0]  o_cpu_wdata_D_cache,	
	output  logic 		  o_cpu_we_D_cache,  
	output  logic [3:0]   o_cpu_wstrb_D_cache,
	output  logic 		  o_cpu_req_flush_D_cache

);

logic decode_illegal;
logic mem_err;
//====Controller signals====
//logic fetch_valid, redirect, load_use_stall, mem_stall;
fetch_state ctrl_fetch_state_wire;
Reg_state ctrl_IFID_state, ctrl_IDEX_state, ctrl_EXMEM_state, ctrl_MEMWB_state;
logic ctrl_LS_issue_allowed, ctrl_retire_allowed, ctrl_trap_allowed, ctrl_trap_interrupt;
logic [31:0] ctrl_fetch_redirect_addr;
logic ctrl_fetch_exc_valid_alive, ctrl_ID_exc_valid_alive, ctrl_EX_exc_valid_alive, ctrl_MEM_exc_valid_alive;
//==========================

//====Fetch Unit signals ====
//logic [31:0] redirect_addr;
logic [31:0] fetch_inst,fetch_PC, fetch_mtval;
logic fetch_out_valid, fetch_exc_valid;
Mcause fetch_mcause;
//===========================

//====IFID Reg===============
logic [31:0] IFID_inst,IFID_PC, IFID_exc_tval;
logic IFID_reg_valid, IFID_exc_valid;
Mcause IFID_exc_mcause;
//===========================

//====Decoder signals========
Opcode decoder_opcode;
ImmSel decoder_immsel;
ALU_Operation decoder_alu_operation;
LoadStore_func3 decoder_loadstore_func3;
Mem_acc_type decoder_mem_acc_type;
Mem_acc_size decoder_mem_acc_size;
logic decoder_reg_we;
Branch_sel decoder_branch_sel;
Inst_type decoder_inst_type;
logic [4:0] decoder_rs1, decoder_rs2, decoder_rd;
WB_source decoder_wb_src;
ALU_source decoder_alu_src1, decoder_alu_src2;
BJ_type decoder_bj_type;
Use_rs decoder_use_rs;
logic decoder_illegal;
Mcause decoder_mcause;
logic [31:0] decoder_mtval, decoder_zimm;
logic decoder_flag_csr, decoder_csr_we, decoder_flag_mret, decoder_csr_use_rs;
Csr_sel decoder_csr_rd;
logic [2:0] decoder_csr_func3;
logic decoder_exc_valid;
//============================

//====ImmGen signal===========
logic [31:0] ImmGen_out_imm;
//============================

//====RegFile signals=========
logic [31:0] regfile_out_rs1_data, regfile_out_rs2_data;
//============================

//====CsrFile signals=========
logic [31:0] csrfile_csr_data, csrfile_mepc, csrfile_mtvec;
logic csrfile_mstatus_MPIE, csrfile_mstatus_MIE, csrfile_MEIE, csrfile_MEIP;
//============================



//====IDEX signals ===========
logic [31:0] IDEX_inst, IDEX_PC, IDEX_imm, IDEX_rs1_data, IDEX_rs2_data;
logic IDEX_reg_valid, IDEX_reg_we, IDEX_illegal;
Opcode IDEX_opcode;
ALU_Operation IDEX_alu_operation;
LoadStore_func3 IDEX_loadstore_func3;
Mem_acc_type IDEX_mem_acc_type;
Mem_acc_size IDEX_mem_acc_size;
Branch_sel IDEX_branch_sel;
Inst_type IDEX_inst_type;
logic [4:0] IDEX_rs1, IDEX_rs2, IDEX_rd;
WB_source IDEX_wb_source;
ALU_source IDEX_alu_src1, IDEX_alu_src2;
BJ_type IDEX_bj_type;
Use_rs IDEX_use_rs;
logic IDEX_exc_valid, IDEX_flag_csr, IDEX_csr_we, IDEX_flag_mret;
logic [31:0] IDEX_exc_tval, IDEX_csr_old_data, IDEX_zimm;
logic [2:0] IDEX_csr_func3;
Csr_sel IDEX_csr_rd;
Mcause IDEX_exc_mcause;
//=============================

//====Forward signals==========
logic [31:0] forward_rs1_data, forward_rs2_data;
//=============================

//====HDUnit signals===========
logic hd_load_use_stall, hd_csr_use_stall;

//====EXUnit signals===========
logic ex_redirect, ex_exc_valid;
logic [31:0] ex_redirect_addr, ex_PCA4, ex_alu_result, ex_mtval;
Mcause ex_mcause;
//=============================

//====CSREXUnit signals========
logic [31:0] csrex_result;
//=============================

//====EXMEM reg signals========
logic [31:0] EXMEM_inst, EXMEM_PC, EXMEM_PCA4, EXMEM_imm, EXMEM_alu_result;
logic EXMEM_reg_valid, EXMEM_reg_we, EXMEM_illgal;
LoadStore_func3 EXMEM_loadstore_func3;
Mem_acc_type EXMEM_mem_acc_type;
Mem_acc_size EXMEM_mem_acc_size;
Inst_type EXMEM_inst_type;
logic [4:0] EXMEM_rd;
WB_source EXMEM_wbsrc;
logic EXMEM_exc_valid, EXMEM_flag_csr, EXMEM_csr_we, EXMEM_flag_mret, EXMEM_redirect;
Mcause EXMEM_mcause;
logic [31:0] EXMEM_tval, EXMEM_csr_result, EXMEM_csr_old_data, EXMEM_redirect_addr;
Csr_sel EXMEM_csr_rd;
//=============================

//====LSUnit signals===========
logic ls_rsp_valid, ls_mem_err, ls_exc_valid, ls_stall;
logic [31:0] ls_rsp_data, ls_mtval;
Mcause ls_mcause;
//=============================

//====MEMWB reg signals========
logic [31:0] MEMWB_inst, MEMWB_PC, MEMWB_PCA4, MEMWB_imm, MEMWB_alu_result, MEMWB_mem_rsp_result;
logic MEMWB_reg_valid, MEMWB_reg_we, MEMWB_illegal, MEMWB_downstream_ready;
Inst_type MEMWB_inst_type;
WB_source MEMWB_wbsrc;
logic [4:0] MEMWB_rd;
logic MEMWB_exc_valid, MEMWB_flag_csr, MEMWB_csr_we, MEMWB_flag_mret, MEMWB_redirect;
logic [31:0] MEMWB_exc_tval, MEMWB_csr_result, MEMWB_csr_old_data, MEMWB_redirect_addr;
Mcause MEMWB_exc_mcause;
Csr_sel MEMWB_csr_rd;
//=============================

//====WBUnit signals===========
logic wb_reg_we, wb_retire_fire;
logic [4:0] wb_rd;
logic [31:0] wb_wb_data;
Commit_type wb_retire_type;
logic wb_csr_we, wb_trap, wb_mret;
logic [31:0] wb_trap_mepc, wb_trap_mcause, wb_trap_mtval;
//=============================
/*
logic ex_stage_exc_valid;
Mcause ex_stage_mcause;
logic [31:0] ex_stage_mtval;

assign ex_stage_exc_valid = ex_exc_valid || ls_exc_valid;
always_comb begin
    if(ex_exc_valid)
        ex_stage_mcause = ex_mcause;
    else if(ls_exc_valid)
        ex_stage_mcause = ls_mcause;
end
always_comb begin
    if(ex_exc_valid)
        ex_stage_mtval = ex_mtval;
    else if(ls_exc_valid)
        ex_stage_mcause = ls_mtval;
end
*/

assign commit_fire = wb_retire_fire;
assign commit_PC = MEMWB_PC;
assign commit_inst = MEMWB_inst;
assign commit_rd = wb_rd;
assign commit_we = wb_reg_we;
assign commit_wb_data = wb_wb_data;
assign commit_type = wb_retire_type;

Controller u_controller(
    .clk(clk),
    .rst_n(rst_n),
    .i_IF_fetch_valid(fetch_out_valid),
    .i_EX_redirect(ex_redirect),
    .i_EX_redirect_addr(ex_redirect_addr),
    .i_GPR_load_use_stall(hd_load_use_stall),
    .i_CSR_load_use_stall(hd_csr_use_stall),
    .i_mem_stall(ls_stall),

    .i_IFID_reg_valid(IFID_reg_valid),
    .i_IDEX_reg_valid(IDEX_reg_valid),
    .i_EXMEM_reg_valid(EXMEM_reg_valid),
    .i_MEMWB_reg_valid(MEMWB_reg_valid),

    .i_fetch_exc_valid(fetch_exc_valid),
    .i_ID_exc_valid(decoder_exc_valid),
    .i_EX_exc_valid(ex_exc_valid),
    .i_MEM_exc_valid(ls_exc_valid),

    .i_IFID_exc_valid(IFID_exc_valid),
    .i_IDEX_exc_valid(IDEX_exc_valid),
    .i_EXMEM_exc_valid(EXMEM_exc_valid),
    .i_MEMWB_exc_valid(MEMWB_exc_valid),

    .i_ID_flag_mret(decoder_flag_mret),
    .i_IDEX_flag_mret(IDEX_flag_mret),
    .i_EXMEM_flag_mret(EXMEM_flag_mret),
    .i_MEMWB_flag_mret(MEMWB_flag_mret),

    .i_mepc(csrfile_mepc),
    .i_mstatus_MIE(csrfile_mstatus_MIE),
    .i_mie_MEIE(csrfile_MEIE),
    .i_mip_MEIP(csrfile_MEIP),
    .i_trap(wb_trap),
    .i_mret(wb_mret),
    .i_mtvec(csrfile_mtvec),
    .i_WB_csr_we(wb_csr_we),
    //input logic i_ext_interrupt, // from external 

    .o_fetch_state(ctrl_fetch_state_wire),  
    .o_IFID_state(ctrl_IFID_state),
    .o_IDEX_state(ctrl_IDEX_state),
    .o_EXMEM_state(ctrl_EXMEM_state),
    .o_MEMWB_state(ctrl_MEMWB_state),
    .o_LS_issue_allowed(ctrl_LS_issue_allowed),
    .o_retire_allowed(ctrl_retire_allowed),
    .o_trap_allowed(ctrl_trap_allowed),
    .o_trap_interrupt(ctrl_trap_interrupt),
    .o_fetch_redirect_addr(ctrl_fetch_redirect_addr),
    .o_fetch_exc_valid_alive(ctrl_fetch_exc_valid_alive),
    .o_ID_exc_valid_alive(ctrl_ID_exc_valid_alive),
    .o_EX_exc_valid_alive(ctrl_EX_exc_valid_alive),
    .o_MEM_exc_valid_alive(ctrl_MEM_exc_valid_alive)
);

FetchUnit u_fetchunit(
    .clk(clk),
    .rst_n(rst_n),
    .i_state(ctrl_fetch_state_wire),
   // input logic i_redirect,
    .i_redirect_addr(ctrl_fetch_redirect_addr),
    .i_cpu_req_ready(i_cpu_req_ready_I_cache),
    .i_cpu_rsp_valid(i_cpu_rsp_valid_I_cache),
    .i_cpu_rsp_data(i_cpu_rsp_data_I_cache),
    .i_cpu_acc_fault(i_cpu_acc_fault_I_cache),
    .o_inst(fetch_inst),
    .o_cpu_req_valid(o_cpu_req_valid_I_cache),
    .o_cpu_req_addr(o_cpu_req_addr_I_cache),
    .o_PC(fetch_PC),
    .o_out_valid(fetch_out_valid),
    .o_exc_valid(fetch_exc_valid),
    .o_mcause(fetch_mcause),
    .o_mtval(fetch_mtval)
);

IFIDReg u_IFIDReg(
    .clk(clk),
    .rst_n(rst_n),
    .i_state(ctrl_IFID_state),  //controller control reg's state
    .i_inst(fetch_inst), // inst provided by fetcher
    .i_PC(fetch_PC),   // PC provided by fetcher
    .i_fetch_valid(fetch_out_valid), // fetcher valid
    .i_fetch_access_fault_alive(ctrl_fetch_exc_valid_alive),
    .i_fetch_fault_cause(fetch_mcause),
    .i_fetch_fault_tval(fetch_mtval),
    .o_inst(IFID_inst),  // ouptut instruction
    .o_PC(IFID_PC),  // output PC
    .o_reg_valid(IFID_reg_valid),  // register valid
    .o_exc_valid(IFID_exc_valid),
    .o_exc_mcause(IFID_exc_mcause),
    .o_exc_tval(IFID_exc_tval)
);

Decoder u_Decoder(
    .inst(IFID_inst),
    .opcode(decoder_opcode),
    .immsel(decoder_immsel),
    .alu_operation(decoder_alu_operation),
    .loadstore_func3(decoder_loadstore_func3),
    .mem_acc_type(decoder_mem_acc_type), // memory write enable
    .mem_acc_size(decoder_mem_acc_size),
    .reg_we(decoder_reg_we), //register file write enable
    .branch_sel(decoder_branch_sel),
    .inst_type(decoder_inst_type), // for debug
    .rs1(decoder_rs1),
    .rs2(decoder_rs2),
    .rd(decoder_rd),
    .wb_source(decoder_wb_src),
    .alu_source1(decoder_alu_src1),
    .alu_source2(decoder_alu_src2),
    .bj_type(decoder_bj_type),
    .use_rs(decoder_use_rs),
    .illegal(decoder_illegal),
    .exc_valid(decoder_exc_valid),
    .mcause(decoder_mcause),
    .mtval(decoder_mtval),
    .flag_csr(decoder_flag_csr),
    .csr_we(decoder_csr_we),
    .zimm(decoder_zimm),
    .csr_func3(decoder_csr_func3),
    .csr_rd(decoder_csr_rd),
    .flag_mret(decoder_flag_mret),
    .csr_use_rs(decoder_csr_use_rs)
);

ImmGen u_ImmGen(
    .inst(IFID_inst),
    .immsel(decoder_immsel),
    .imm(ImmGen_out_imm)
);

RegFile u_RegFile(
    .clk(clk),
    .rs1_addr(decoder_rs1),
    .rs2_addr(decoder_rs2),
    .rd_addr(wb_rd),
    .rd_wen(wb_reg_we),
    .rd_data(wb_wb_data),
    .rs1_data(regfile_out_rs1_data),
    .rs2_data(regfile_out_rs2_data)
);

CSRFile u_CSRFile(
    .clk(clk),
    .rst_n(rst_n),

    .i_csr_we(wb_csr_we),
    
    .i_csr_ID_rd(decoder_csr_rd),  // for ID read csr
    .i_csr_wdata(MEMWB_csr_result),
    .i_csr_WB_rd(MEMWB_csr_rd), //for WB write csr

    .i_trap(wb_trap),
    .i_trap_mepc(wb_trap_mepc),
    .i_trap_mcause(wb_trap_mcause),
    .i_trap_mtval(wb_trap_mtval),

    .i_mret(wb_mret),

    .i_mip_MEIP(MEIP),

    .o_csr_data(csrfile_csr_data),
    
    .o_mepc(csrfile_mepc),
    .o_mtvec(csrfile_mtvec), 
    .o_mstatus_MPIE(csrfile_mstatus_MPIE),
    .o_mstatus_MIE(csrfile_mstatus_MIE),
    .o_mie_MEIE(csrfile_MEIE),
    .o_mip_MEIP(csrfile_MEIP)
);


IDEXReg u_IDEXReg(
    .clk(clk),
    .rst_n(rst_n),
    //from controller
    .i_state(ctrl_IDEX_state),  //controller control reg's state
    //from IFIDReg
    .i_inst(IFID_inst), // inst provided by IFID, for debug
    .i_PC(IFID_PC),   // PC provided by IFID
    .i_reg_valid(IFID_reg_valid), // IFID valid

    //from decoder
    .i_opcode(decoder_opcode),
    //input ImmSel i_immsel,
    .i_alu_operation(decoder_alu_operation),
    .i_loadstore_func3(decoder_loadstore_func3),
    .i_mem_acc_type(decoder_mem_acc_type), // memory write enable
    .i_mem_acc_size(decoder_mem_acc_size),
    .i_reg_we(decoder_reg_we), //register file write enable
    .i_branch_sel(decoder_branch_sel),
    .i_inst_type(decoder_inst_type), // for debug
    .i_rs1(decoder_rs1),
    .i_rs2(decoder_rs2),
    .i_rd(decoder_rd),
    .i_wb_source(decoder_wb_src),
    .i_alu_source1(decoder_alu_src1),
    .i_alu_source2(decoder_alu_src2),
    .i_bj_type(decoder_bj_type),
    .i_use_rs(decoder_use_rs),
    .i_illegal(decoder_illegal),   // for debug
    //from ImmGen
    .i_imm(ImmGen_out_imm), // immediate
    //from Regfile
    .i_rs1_data(regfile_out_rs1_data),
    .i_rs2_data(regfile_out_rs2_data),
    .i_exc_valid(IFID_exc_valid),
    .i_exc_mcause(IFID_exc_mcause),
    .i_exc_tval(IFID_exc_tval),
    .i_decode_fault_alive(ctrl_ID_exc_valid_alive),
    .i_decode_fault_cause(decoder_mcause),
    .i_decoder_fault_tval(decoder_mtval),
    .i_flag_csr(decoder_flag_csr),
    .i_csr_we(decoder_csr_we),
    .i_csr_old_data(csrfile_csr_data),
    .i_zimm(decoder_zimm),
    .i_csr_func3(decoder_csr_func3),
    .i_csr_rd(decoder_csr_rd),
    .i_flag_mret(decoder_flag_mret),

    .o_inst(IDEX_inst),  // ouptut instruction
    .o_PC(IDEX_PC),  // output PC
    .o_reg_valid(IDEX_reg_valid),  // register valid
    .o_opcode(IDEX_opcode),
    .o_alu_operation(IDEX_alu_operation),
    .o_loadstore_func3(IDEX_loadstore_func3),
    .o_mem_acc_type(IDEX_mem_acc_type),
    .o_mem_acc_size(IDEX_mem_acc_size),
    .o_reg_we(IDEX_reg_we),
    .o_branch_sel(IDEX_branch_sel),
    .o_inst_type(IDEX_inst_type),
    .o_rs1(IDEX_rs1),
    .o_rs2(IDEX_rs2),
    .o_rd(IDEX_rd),
    .o_wb_source(IDEX_wb_source),
    .o_alu_source1(IDEX_alu_src1),
    .o_alu_source2(IDEX_alu_src2),
    .o_bj_type(IDEX_bj_type),
    .o_use_rs(IDEX_use_rs),
    .o_illegal(IDEX_illegal),
    .o_imm(IDEX_imm),
    .o_rs1_data(IDEX_rs1_data),
    .o_rs2_data(IDEX_rs2_data),
    .o_exc_valid(IDEX_exc_valid),
    .o_exc_mcause(IDEX_exc_mcause),
    .o_exc_tval(IDEX_exc_tval),
    .o_flag_csr(IDEX_flag_csr),
    .o_flag_mret(IDEX_flag_mret),
    .o_csr_we(IDEX_csr_we),
    .o_csr_old_data(IDEX_csr_old_data),
    .o_zimm(IDEX_zimm),
    .o_csr_func3(IDEX_csr_func3),
    .o_csr_rd(IDEX_csr_rd)
);

HDUnit u_HDUnit(
    .i_decoder_rs1(decoder_rs1),
    .i_decoder_rs2(decoder_rs2),
    .i_decoder_use_rs(decoder_use_rs),
    .i_IDEX_rd(IDEX_rd),
    .i_IDEX_mem_acc_type(IDEX_mem_acc_type),
    .i_IDEX_reg_valid(IDEX_reg_valid),
    .i_IFID_reg_valid(IFID_reg_valid),
    .i_EXMEM_rd(EXMEM_rd),
    .i_MEMWB_rd(MEMWB_rd),
    .i_EXMEM_reg_valid(EXMEM_reg_valid),
    .i_MEMWB_reg_valid(MEMWB_reg_valid),
    .i_decoder_csr_use_rs(decoder_csr_use_rs),
    .i_decoder_flag_csr(decoder_flag_csr),
    .i_decoder_csr_rd(decoder_csr_rd),
    .i_IDEX_csr_we(IDEX_csr_we),
    .i_IDEX_reg_we(IDEX_reg_we),
    .i_IDEX_csr_rd(IDEX_csr_rd),
    .i_EXMEM_csr_we(EXMEM_csr_we),
    .i_EXMEM_reg_we(EXMEM_reg_we),
    .i_EXMEM_csr_rd(EXMEM_csr_rd),
    .i_MEMWB_csr_we(MEMWB_csr_we),
    .i_MEMWB_reg_we(MEMWB_reg_we),
    .i_MEMWB_csr_rd(MEMWB_csr_rd),
    .o_load_use_stall(hd_load_use_stall),
    .o_csr_use_stall(hd_csr_use_stall)
);

FWUnit u_FWUnit(
    .i_IDEX_rs1(IDEX_rs1),
    .i_IDEX_rs2(IDEX_rs2),
    //input Use_rs i_IDEX_use_rs,
    .i_IDEX_rs1_data(IDEX_rs1_data),
    .i_IDEX_rs2_data(IDEX_rs2_data),

    .i_EXMEM_reg_valid(EXMEM_reg_valid),
    .i_EXMEM_rd(EXMEM_rd),
    .i_EXMEM_reg_we(EXMEM_reg_we),
    .i_EXMEM_alu_result(EXMEM_alu_result),
    .i_EXMEM_imm(EXMEM_imm),
    .i_EXMEM_PCA4(EXMEM_PCA4),
    .i_EXMEM_csr_old_data(EXMEM_csr_old_data),
    .i_EXMEM_wbsrc(EXMEM_wbsrc),

    .i_MEMWB_reg_valid(MEMWB_reg_valid),
    .i_MEMWB_rd(MEMWB_rd),
    .i_MEMWB_reg_we(MEMWB_reg_we),
    .i_MEMWB_alu_result(MEMWB_alu_result),
    .i_MEMWB_imm(MEMWB_imm),
    .i_MEMWB_PCA4(MEMWB_PCA4),
    .i_MEMWB_mem_rsp(MEMWB_mem_rsp_result),
    .i_MEMWB_csr_old_data(MEMWB_csr_old_data),
    .i_MEMWB_wbsrc(MEMWB_wbsrc),

    .o_forward_rs1(forward_rs1_data),
    .o_forward_rs2(forward_rs2_data)
);

EXUnit u_EXUnit(
    .i_PC(IDEX_PC),   
    .i_reg_valid(IDEX_reg_valid), 
    .i_alu_operation(IDEX_alu_operation),
    .i_branch_sel(IDEX_branch_sel),
    .i_alu_source1(IDEX_alu_src1),
    .i_alu_source2(IDEX_alu_src2),
    .i_bj_type(IDEX_bj_type),
    .i_illegal(IDEX_illegal),   // for debug
    .i_imm(IDEX_imm), 
    .i_rs1_data(forward_rs1_data),
    .i_rs2_data(forward_rs2_data),
    .i_mem_acc_type(IDEX_mem_acc_type),
    .i_mem_acc_size(IDEX_mem_acc_size),

    .o_redirect(ex_redirect),
    .o_redirect_addr(ex_redirect_addr),
    .o_PCA4(ex_PCA4),
    .o_alu_result(ex_alu_result),
    .o_exc_valid(ex_exc_valid),
    .o_mcause(ex_mcause),
    .o_mtval(ex_mtval)
);

CSREXUnit u_CSREXUnit(
    .rs1(IDEX_rs1_data),
    .csr_old_data(IDEX_csr_old_data),
    .zimm(IDEX_zimm),
    .csr_func3(IDEX_csr_func3),
    .flag_csr(IDEX_flag_csr),
    //output logic csr_we,
    .csr_result(csrex_result)
);

EXMEMReg u_EXMEMReg(
    .clk(clk),
    .rst_n(rst_n),
    //from controller
    .i_state(ctrl_EXMEM_state),  //controller control reg's state
    .i_inst(IDEX_inst), 
    .i_PC(IDEX_PC),   // For debug
    .i_PCA4(ex_PCA4),
    .i_reg_valid(IDEX_reg_valid), 

    .i_loadstore_func3(IDEX_loadstore_func3),
    .i_mem_acc_type(IDEX_mem_acc_type), // memory write enable
    .i_mem_acc_size(IDEX_mem_acc_size),
    .i_reg_we(IDEX_reg_we), //register file write enable
    .i_inst_type(IDEX_inst_type), // for debug
    .i_rd(IDEX_rd),
    .i_wb_source(IDEX_wb_source),
    .i_illegal(IDEX_illegal),   // for debug
    .i_imm(IDEX_imm), // immediate
    .i_alu_result(ex_alu_result),
    .i_exc_valid(IDEX_exc_valid),
    .i_exc_mcause(IDEX_exc_mcause),
    .i_exc_tval(IDEX_exc_tval),
    .i_exe_fault_alive(ctrl_EX_exc_valid_alive),
    .i_exe_fault_cause(ex_mcause),
    .i_exe_fault_tval(ex_mtval),
    .i_flag_csr(IDEX_flag_csr),
    .i_csr_we(IDEX_csr_we),
    .i_csr_result(csrex_result),
    .i_csr_old_data(IDEX_csr_old_data),
    .i_csr_rd(IDEX_csr_rd),
    .i_flag_mret(IDEX_flag_mret),
    .i_redirect(ex_redirect),
    .i_redirect_addr(ex_redirect_addr),

    .o_inst(EXMEM_inst),  // ouptut instruction
    .o_PC(EXMEM_PC),  // output PC
    .o_PCA4(EXMEM_PCA4),
    .o_reg_valid(EXMEM_reg_valid),  // register valid

    .o_loadstore_func3(EXMEM_loadstore_func3),
    .o_mem_acc_type(EXMEM_mem_acc_type), // memory write enable
    .o_mem_acc_size(EXMEM_mem_acc_size),
    .o_reg_we(EXMEM_reg_we), //register file write enable
    .o_inst_type(EXMEM_inst_type), // for debug
    .o_rd(EXMEM_rd),
    .o_wb_source(EXMEM_wbsrc),
    .o_illegal(EXMEM_illgal),
    .o_imm(EXMEM_imm),
    .o_alu_result(EXMEM_alu_result),
    .o_exc_valid(EXMEM_exc_valid),
    .o_exc_mcause(EXMEM_mcause),
    .o_exc_tval(EXMEM_tval),
    .o_flag_csr(EXMEM_flag_csr),
    .o_csr_we(EXMEM_csr_we),
    .o_csr_result(EXMEM_csr_result),
    .o_csr_old_data(EXMEM_csr_old_data),
    .o_csr_rd(EXMEM_csr_rd),
    .o_flag_mret(EXMEM_flag_mret),
    .o_redirect(EXMEM_redirect),
    .o_redirect_addr(EXMEM_redirect_addr)
);

LSUnit u_LSUnit(
    .clk(clk),
    .rst_n(rst_n),  

    .i_reg_valid(IDEX_reg_valid), // from ID/EX
    .i_issue_allowed(ctrl_LS_issue_allowed), //from controller, handle exception or ext...
    .i_downstream_ready(MEMWB_downstream_ready), //from MEM/WB reg, indicate downstream can accept data/ack 
    .i_LS_addr(ex_alu_result), 
    .i_loadstore_func3(IDEX_loadstore_func3),
    .i_mem_acc_type(IDEX_mem_acc_type),
    .i_mem_acc_size(IDEX_mem_acc_size),
    .i_store_data(forward_rs2_data),

    .o_stall(ls_stall), //indicate that handshake failed or cache miss, tell controller to hold 
    .o_rsp_valid(ls_rsp_valid), //indicate that transaction done, data is valid
    .o_rsp_data(ls_rsp_data), // respone load data  
    .o_mem_err(ls_mem_err), //indicate error
    .o_exc_valid(ls_exc_valid),
    .o_mcause(ls_mcause),
    .o_mtval(ls_mtval),
    //cache interface
    .i_cpu_req_ready(i_cpu_req_ready_D_cache),  //comb 1 means CPU can send command to cache, 0 means not
    .i_cpu_rsp_load_ack(i_cpu_rsp_load_ack_D_cache), //comb
    .i_cpu_rsp_data(i_cpu_rsp_data_D_cache),
	.i_cpu_rsp_flush_ack(i_cpu_rsp_flush_ack_D_cache), //sequential
	.i_cpu_rsp_store_ack(i_cpu_rsp_store_ack_D_cache), //comb
    .i_cpu_acc_fault(i_cpu_acc_fault_D_cache),
	.i_b_err_bit(i_b_err_bit_D_cache),
    
    .o_cpu_req_LS_valid(o_cpu_req_LS_valid_D_cache),   //comb
    .o_cpu_req_addr(o_cpu_req_addr_D_cache),
	.o_cpu_wdata(o_cpu_wdata_D_cache),	
	.o_cpu_we(o_cpu_we_D_cache),  // 1 means write ,0 means read
	.o_cpu_wstrb(o_cpu_wstrb_D_cache),
	.o_cpu_req_flush(o_cpu_req_flush_D_cache)
);

MEMWBReg u_MEMWBReg(
    .clk(clk),
    .rst_n(rst_n),
    //from controller
    .i_state(ctrl_MEMWB_state),  //controller control reg's state
    //from IFIDReg
    .i_inst(EXMEM_inst), // inst provided by IFID, for debug
    .i_PC(EXMEM_PC),   // For debug
    .i_PCA4(EXMEM_PCA4),
    .i_reg_valid(EXMEM_reg_valid),

    //input LoadStore_func3 i_loadstore_func3,
    //input Mem_acc_type i_mem_acc_type, // memory write enable
    //input Mem_acc_size i_mem_acc_size,
    .i_reg_we(EXMEM_reg_we), //register file write enable
    .i_inst_type(EXMEM_inst_type), // for debug
    .i_rd(EXMEM_rd),
    .i_wb_source(EXMEM_wbsrc),
    .i_illegal(EXMEM_illgal),   // for debug
    .i_imm(EXMEM_imm), // immediate
    .i_alu_result(EXMEM_alu_result),

    .i_mem_rsp_valid(ls_rsp_valid),
    .i_mem_rsp_data(ls_rsp_data),

    .i_exc_valid(EXMEM_exc_valid),
    .i_exc_mcause(EXMEM_mcause),
    .i_exc_tval(EXMEM_tval),
    .i_mem_fault_alive(ctrl_MEM_exc_valid_alive),
    .i_mem_fault_cause(ls_mcause),
    .i_mem_fault_tval(ls_mtval),
    .i_flag_csr(EXMEM_flag_csr),
    .i_csr_we(EXMEM_csr_we),
    .i_csr_result(EXMEM_csr_result),
    .i_csr_old_data(EXMEM_csr_old_data),
    .i_csr_rd(EXMEM_csr_rd),
    .i_flag_mret(EXMEM_flag_mret),
    .i_redirect(EXMEM_redirect),
    .i_redirect_addr(EXMEM_redirect_addr),

    .o_inst(MEMWB_inst),  // ouptut instruction
    .o_PC(MEMWB_PC),  // output PC
    .o_PCA4(MEMWB_PCA4),
    .o_reg_valid(MEMWB_reg_valid),  // register valid

    //output LoadStore_func3 o_loadstore_func3,
    //output Mem_acc_type o_mem_acc_type, // memory write enable
    //output Mem_acc_size o_mem_acc_size,
    .o_reg_we(MEMWB_reg_we), //register file write enable
    .o_inst_type(MEMWB_inst_type), // for debug
    .o_rd(MEMWB_rd),
    .o_wb_source(MEMWB_wbsrc),
    .o_illegal(MEMWB_illegal),
    .o_imm(MEMWB_imm),
    .o_alu_result(MEMWB_alu_result),
    
    .o_downstream_ready(MEMWB_downstream_ready),
    .o_mem_rsp_result(MEMWB_mem_rsp_result),
    .o_exc_valid(MEMWB_exc_valid),
    .o_exc_mcause(MEMWB_exc_mcause),
    .o_exc_tval(MEMWB_exc_tval),
    .o_flag_csr(MEMWB_flag_csr),
    .o_csr_we(MEMWB_csr_we),
    .o_csr_result(MEMWB_csr_result),
    .o_csr_old_data(MEMWB_csr_old_data),
    .o_csr_rd(MEMWB_csr_rd),
    .o_flag_mret(MEMWB_flag_mret),
    .o_redirect(MEMWB_redirect),
    .o_redirect_addr(MEMWB_redirect_addr)

);

WBUnit u_WBUnit(
    //from controller
    .clk(clk),
    .rst_n(rst_n),
    .retire_allowed(ctrl_retire_allowed),
    .trap_allowed(ctrl_trap_allowed),
    .trap_interrupt(ctrl_trap_interrupt),
    .i_PCA4(MEMWB_PCA4),
    .i_reg_valid(MEMWB_reg_valid),
    .i_reg_we(MEMWB_reg_we), //register file write enable
    .i_rd(MEMWB_rd),
    .i_wb_source(MEMWB_wbsrc),
    .i_illegal(MEMWB_illegal),   // for debug
    .i_imm(MEMWB_imm), // immediate
    .i_alu_result(MEMWB_alu_result),
    .i_mem_rsp_data(MEMWB_mem_rsp_result),
    .i_inst_type(MEMWB_inst_type),
    .i_exc_valid(MEMWB_exc_valid),
    .i_flag_csr(MEMWB_flag_csr),
    .i_csr_we(MEMWB_csr_we),
    .i_csr_old_data(MEMWB_csr_old_data),
    .i_PC(MEMWB_PC),
    .i_redirect(MEMWB_redirect),
    .i_redirect_addr(MEMWB_redirect_addr),
    .i_mcause(MEMWB_exc_mcause),
    .i_mtval(MEMWB_exc_tval),
    .i_mepc(csrfile_mepc),
    .i_flag_mret(MEMWB_flag_mret),
    .o_reg_we(wb_reg_we), //register file write enable
    .o_rd(wb_rd),
    .o_wb_data(wb_wb_data),
    .retire_fire(wb_retire_fire),
    .retire_type(wb_retire_type),
    .o_csr_we(wb_csr_we),
    .o_trap(wb_trap),
    .o_mret(wb_mret),
    .o_trap_mepc(wb_trap_mepc),
    .o_trap_mcause(wb_trap_mcause),
    .o_trap_mtval(wb_trap_mtval)
);

endmodule