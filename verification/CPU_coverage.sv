import RISC_V_PKG::*;
module CPU_coverage(
    input clk,
    input rst_n
);

`define DUT TESTBENCH.dut.u_cpu

covergroup cg_inst_commit @(posedge clk);
    option.per_instance = 1;
    option.comment = "coverage of commit instruction";
    cp_inst : coverpoint `DUT.u_WBUnit.i_inst_type iff (`DUT.commit_fire) {
        bins bin_Inst_ADD = {Inst_ADD};
        bins bin_Inst_SUB = {Inst_SUB};
        bins bin_Inst_SLL = {Inst_SLL};
        bins bin_Inst_SLT = {Inst_SLT};
        bins bin_Inst_SLTU = {Inst_SLTU};
        bins bin_Inst_XOR = {Inst_XOR};
        bins bin_Inst_SRL = {Inst_SRL};
        bins bin_Inst_SRA = {Inst_SRA};
        bins bin_Inst_OR = {Inst_OR};
        bins bin_Inst_AND = {Inst_AND};
        bins bin_Inst_ADDI = {Inst_ADDI};
        bins bin_Inst_SLTI = {Inst_SLTI};
        bins bin_Inst_SLTIU = {Inst_SLTIU};
        bins bin_Inst_XORI = {Inst_XORI};
        bins bin_Inst_ORI = {Inst_ORI};
        bins bin_Inst_ANDI = {Inst_ANDI};
        bins bin_Inst_SLLI = {Inst_SLLI};
        bins bin_Inst_SRLI = {Inst_SRLI};
        bins bin_Inst_SRAI = {Inst_SRAI};
        bins bin_Inst_LB = {Inst_LB};
        bins bin_Inst_LH = {Inst_LH};
        bins bin_Inst_LW = {Inst_LW};
        bins bin_Inst_LBU = {Inst_LBU};
        bins bin_Inst_LHU = {Inst_LHU};
        bins bin_Inst_SB = {Inst_SB};
        bins bin_Inst_SH = {Inst_SH};
        bins bin_Inst_SW = {Inst_SW};
        bins bin_Inst_BEQ = {Inst_BEQ};
        bins bin_Inst_BNE = {Inst_BNE};
        bins bin_Inst_BLT = {Inst_BLT};
        bins bin_Inst_BGE = {Inst_BGE};
        bins bin_Inst_BLTU = {Inst_BLTU};
        bins bin_Inst_BGEU = {Inst_BGEU};
        bins bin_Inst_JAL = {Inst_JAL};
        bins bin_Inst_JALR = {Inst_JALR};
        bins bin_Inst_LUI = {Inst_LUI};
        bins bin_Inst_AUIPC = {Inst_AUIPC};
        bins bin_Inst_FENCE = {Inst_FENCE};
        bins bin_Inst_ECALL = {Inst_ECALL};
        bins bin_Inst_EBREAK = {Inst_EBREAK};
        bins bin_Inst_CSRRW = {Inst_CSRRW};
        bins bin_Inst_CSRRS = {Inst_CSRRS};
        bins bin_Inst_CSRRC = {Inst_CSRRC};
        bins bin_Inst_CSRRWI = {Inst_CSRRWI};
        bins bin_Inst_CSRRSI = {Inst_CSRRSI};
        bins bin_Inst_CSRRCI = {Inst_CSRRCI};
        bins bin_Inst_MRET = {Inst_MRET};
        illegal_bins bin_Inst_ERR = {Inst_ERR};
    }
endgroup

covergroup cg_branch_taken @(posedge clk);
    option.per_instance = 1;
    option.comment = "vary branch type taken";
    cp_redirect_taken : coverpoint `DUT.u_controller.EX_redirect_alive iff (`DUT.u_IDEXReg.o_bj_type == BJ_branch && !`DUT.u_controller.global_hold && `DUT.u_IDEXReg.o_reg_valid && `DUT.u_controller.EX_side_effect_allowed){
        bins bin_taken = {1};
        bins bin_not_taken = {0};
    }
    cp_branch_type : coverpoint `DUT.u_IDEXReg.o_branch_sel iff (!`DUT.u_controller.global_hold && `DUT.u_IDEXReg.o_reg_valid && `DUT.u_IDEXReg.o_opcode == OP_BRANCH) {
        bins bin_beq = {B_EQ};
        bins bin_bne = {B_BNE};
        bins bin_blt = {B_BLT};
        bins bin_bge = {B_BGE};
        bins bin_bltu = {B_BLTU};
        bins bin_bgeu = {B_BGEU};
        illegal_bins bin_berr = {B_ERR};
    }
    cx_btype_taken : cross  cp_redirect_taken, cp_branch_type;

endgroup

covergroup cg_mem_acc @(posedge clk);
    option.per_instance = 1;
    option.comment = "vary memory access (no fault)";
    cp_mem_acc_type : coverpoint `DUT.u_EXMEMReg.o_mem_acc_type  iff(`DUT.u_MEMWBReg.o_downstream_ready && `DUT.u_MEMWBReg.i_mem_rsp_valid && `DUT.u_EXMEMReg.o_reg_valid && !`DUT.u_controller.MEM_local_exc_alive){
        bins bin_load = {Mem_load};
        bins bin_store = {Mem_store};
        ignore_bins bin_flush = {Mem_flush};
        ignore_bins bin_none = {Mem_none};
    }

    cp_mem_acc_size : coverpoint `DUT.u_EXMEMReg.o_mem_acc_size  iff(`DUT.u_MEMWBReg.o_downstream_ready && `DUT.u_MEMWBReg.i_mem_rsp_valid && `DUT.u_EXMEMReg.o_reg_valid && !`DUT.u_controller.MEM_local_exc_alive){
        bins bin_b = {Mem_acc_size_B};
        bins bin_h = {Mem_acc_size_H};
        bins bin_w = {Mem_acc_size_W};
        ignore_bins bin_none = {Mem_acc_size_none};
    }
    cx_mem_acc : cross cp_mem_acc_type , cp_mem_acc_size;
endgroup

covergroup cg_fetch_state @(posedge clk);
    option.per_instance = 1;
    option.comment = "vary fetch_state";
    cp_fetch_state : coverpoint `DUT.u_fetchunit.i_state {
        bins bin_fetch_load = {fetch_load};
        bins bin_fetch_hold = {fetch_hold};
        bins bin_fetch_clear = {fetch_clear};
        bins bin_fetch_redirect = {fetch_redirect};
        bins bin_fetch_capture = {fetch_capture};
    }
    cp_fetch_transition : coverpoint `DUT.u_fetchunit.i_state {
        bins bin_clear_to_load = (fetch_clear => fetch_load);
        bins bin_load_to_redirect = (fetch_load => fetch_redirect);
        bins bin_load_to_hold = (fetch_load => fetch_hold);
        bins bin_load_to_capture = (fetch_load => fetch_capture);
        bins bin_hold_to_redirect = (fetch_hold => fetch_redirect);
        bins bin_hold_to_load = (fetch_hold => fetch_load);
        bins bin_hold_to_capture = (fetch_hold => fetch_capture);
        bins bin_capture_to_hold = (fetch_capture => fetch_hold);
        bins bin_capture_to_load = (fetch_capture => fetch_load);
        bins bin_capture_to_redirect = (fetch_capture => fetch_redirect);
    }
endgroup

covergroup cg_IFID_state @(posedge clk);
    option.per_instance = 1;
    option.comment = "vary IFID reg state";
    cp_IFID_state : coverpoint `DUT.u_IFIDReg.i_state {
        bins bin_bubble = {Reg_BUBBLE};
        bins bin_hold = {Reg_HOLD};
        bins bin_advance = {Reg_ADVANCE};
    }
    cp_IFID_transition : coverpoint `DUT.u_IFIDReg.i_state {
        bins bin_bubble_to_advance = (Reg_BUBBLE => Reg_ADVANCE);
        bins bin_bubble_to_hold = (Reg_BUBBLE => Reg_HOLD);
        bins bin_hold_to_advance = (Reg_HOLD => Reg_ADVANCE);
        bins bin_hold_to_bubble = (Reg_HOLD => Reg_BUBBLE);
        bins bin_advance_to_hold = (Reg_ADVANCE => Reg_HOLD);
        bins bin_advance_to_bubble = (Reg_ADVANCE => Reg_BUBBLE);
    }
endgroup

covergroup cg_IDEX_state @(posedge clk);
    option.per_instance = 1;
    option.comment = "vary IDEX reg state";
    cp_IDEX_state : coverpoint `DUT.u_IDEXReg.i_state {
        bins bin_bubble = {Reg_BUBBLE};
        bins bin_hold = {Reg_HOLD};
        bins bin_advance = {Reg_ADVANCE};
    }
    cp_IDEX_transition : coverpoint `DUT.u_IDEXReg.i_state {
        bins bin_bubble_to_advance = (Reg_BUBBLE => Reg_ADVANCE);
        bins bin_bubble_to_hold = (Reg_BUBBLE => Reg_HOLD);
        bins bin_hold_to_advance = (Reg_HOLD => Reg_ADVANCE);
        bins bin_hold_to_bubble = (Reg_HOLD => Reg_BUBBLE);
        bins bin_advance_to_hold = (Reg_ADVANCE => Reg_HOLD);
        bins bin_advance_to_bubble = (Reg_ADVANCE => Reg_BUBBLE);
    }
endgroup

covergroup cg_EXMEM_state @(posedge clk);
    option.per_instance = 1;
    option.comment = "vary EXMEM reg state";
    cp_EXMEM_state : coverpoint `DUT.u_EXMEMReg.i_state {
        bins bin_bubble = {Reg_BUBBLE};
        bins bin_hold = {Reg_HOLD};
        bins bin_advance = {Reg_ADVANCE};
    }
    cp_EXMEM_transition : coverpoint `DUT.u_EXMEMReg.i_state {
        bins bin_bubble_to_advance = (Reg_BUBBLE => Reg_ADVANCE);
        bins bin_bubble_to_hold = (Reg_BUBBLE => Reg_HOLD);
        bins bin_hold_to_advance = (Reg_HOLD => Reg_ADVANCE);
        bins bin_hold_to_bubble = (Reg_HOLD => Reg_BUBBLE);
        bins bin_advance_to_hold = (Reg_ADVANCE => Reg_HOLD);
        bins bin_advance_to_bubble = (Reg_ADVANCE => Reg_BUBBLE);
    }
endgroup

covergroup cg_MEMWB_state @(posedge clk);
    option.per_instance = 1;
    option.comment = "vary EXMEM reg state";
    cp_MEMWB_state : coverpoint `DUT.u_MEMWBReg.i_state {
        bins bin_bubble = {Reg_BUBBLE};
        bins bin_hold = {Reg_HOLD};
        bins bin_advance = {Reg_ADVANCE};
    }
    cp_MEMWB_transition : coverpoint `DUT.u_MEMWBReg.i_state {
        bins bin_bubble_to_advance = (Reg_BUBBLE => Reg_ADVANCE);
        bins bin_bubble_to_hold = (Reg_BUBBLE => Reg_HOLD);
        bins bin_hold_to_advance = (Reg_HOLD => Reg_ADVANCE);
        bins bin_hold_to_bubble = (Reg_HOLD => Reg_BUBBLE);
        bins bin_advance_to_hold = (Reg_ADVANCE => Reg_HOLD);
        bins bin_advance_to_bubble = (Reg_ADVANCE => Reg_BUBBLE);
    }
endgroup

covergroup cg_irq_event @(posedge clk);
    option.per_instance = 1;
    option.comment = "interrupt event";
    cp_MEIP_transiton : coverpoint `DUT.MEIP {
        bins bin_high_to_low = (1=>0);
        bins bin_low_to_high = (0=>1);
    }

    cp_irq_take: coverpoint `DUT.u_controller.o_trap_interrupt;
endgroup

covergroup cg_exc_event @(posedge clk);
    option.per_instance = 1;
    option.comment = "exception event";
    cp_mcause : coverpoint `DUT.u_CSRFile.i_trap_mcause iff (`DUT.u_WBUnit.o_trap) {
        bins bin_inst_misaligned = {Mcause_INST_MISALIGNED};
        bins bin_inst_acc_fault = {Mcause_INST_ACCFAULT};
        bins bin_inst_illegal = {Mcause_INST_ILLEGAL};
        bins bin_ebreak = {Mcause_EBREAK};
        bins bin_load_misaligned = {Mcause_LOAD_MISALIGNED};
        bins bin_load_acc_fault = {Mcause_LOAD_ACCFAULT};
        bins bin_store_misaligned = {Mcause_STORE_MISALIGNED};
        bins bin_store_acc_fault = {Mcause_STORE_ACCFAULT};
        bins bin_ecall = {Mcause_ECALL};
        bins bin_ext_irq = {Mcause_EXT_INTERRUPT};
    }
endgroup

covergroup cg_stall @(posedge clk);
    option.per_instance = 1;
    option.comment = "stall event";
    cp_global_stall : coverpoint `DUT.u_controller.global_hold;
    cp_load_use_stall : coverpoint `DUT.u_controller.i_GPR_load_use_stall iff (!`DUT.u_controller.global_hold && `DUT.u_controller.o_IDEX_state == Reg_BUBBLE && `DUT.u_controller.o_IFID_state == Reg_HOLD);
    cp_csr_use_stall : coverpoint `DUT.u_controller.i_CSR_load_use_stall iff (!`DUT.u_controller.global_hold && `DUT.u_controller.o_IDEX_state == Reg_BUBBLE && `DUT.u_controller.o_IFID_state == Reg_HOLD);

endgroup

covergroup cg_exc_kill @(posedge clk);
    option.per_instance = 1;
    option.comment = "Exception kill younger event";
    cp_mem_fault_kill_EX_redirect : coverpoint (`DUT.u_controller.i_EX_redirect && !`DUT.u_controller.EX_side_effect_allowed) iff (!`DUT.u_controller.global_hold && `DUT.u_controller.MEM_local_exc_alive && `DUT.u_controller.i_IDEX_reg_valid);
    cp_mem_fault_kill_LS_handshake : coverpoint ((`DUT.u_LSUnit.i_mem_acc_type == Mem_store || `DUT.u_LSUnit.i_mem_acc_type == Mem_load) && !`DUT.u_controller.EX_side_effect_allowed) iff (!`DUT.u_controller.global_hold && `DUT.u_controller.MEM_local_exc_alive && `DUT.u_controller.i_IDEX_reg_valid);
    cp_mem_fault_kill_ID_exc : coverpoint (`DUT.u_controller.i_ID_exc_valid && !`DUT.u_controller.ID_local_exc_alive) iff (!`DUT.u_controller.global_hold && `DUT.u_controller.MEM_local_exc_alive && `DUT.u_controller.i_IFID_reg_valid);
endgroup

covergroup cq_irq_race @(posedge clk);
    option.per_instance = 1;
    option.comment = "interrupt race condition";
    cp_irq_drain_exc : coverpoint ((`DUT.u_controller.irq_drain || `DUT.u_controller.irq_drain_start) && `DUT.u_controller.pipeline_exc_alive_exclude_fetch);
    //cp_irq_drain_mret :  coverpoint ((`DUT.u_controller.irq_drain || `DUT.u_controller.irq_drain_start) && (`DUT.u_controller.mret_pending || `DUT.u_controller.mret_issue_fire) && `DUT.u_controller.mret_alive);
    cp_irq_drain_redirect : coverpoint ((`DUT.u_controller.irq_drain || `DUT.u_controller.irq_drain_start)  && `DUT.u_controller.i_EX_redirect && `DUT.u_controller.i_IDEX_reg_valid && !`DUT.u_controller.global_hold && !`DUT.u_controller.pipeline_exc_alive_exclude_fetch);
    cp_irq_pending_exc :  coverpoint (`DUT.u_controller.irq_pending && !(`DUT.u_controller.irq_drain || `DUT.u_controller.irq_drain_start) && `DUT.u_controller.pipeline_exc_alive_exclude_fetch);
    cp_irq_pending_mret :  coverpoint (`DUT.u_controller.irq_pending && !(`DUT.u_controller.irq_drain || `DUT.u_controller.irq_drain_start) && (`DUT.u_controller.mret_pending || `DUT.u_controller.mret_issue_fire) && `DUT.u_controller.mret_alive);
    cp_irq_pending_redirect : coverpoint (`DUT.u_controller.irq_pending && !(`DUT.u_controller.irq_drain || `DUT.u_controller.irq_drain_start)  && `DUT.u_controller.i_EX_redirect && `DUT.u_controller.i_IDEX_reg_valid && !`DUT.u_controller.global_hold && !`DUT.u_controller.pipeline_exc_alive_exclude_fetch);
endgroup


covergroup cg_fetch_fault_hold @(posedge clk);
    option.per_instance = 1;
    option.comment = "fetch fault hold";
    cp_fetch_fault_global_hold :  coverpoint (`DUT.u_fetchunit.o_exc_valid && `DUT.u_fetchunit.i_state == fetch_hold && `DUT.u_controller.global_hold);
    cp_fetch_fault_data_hazard_hold : coverpoint (`DUT.u_fetchunit.o_exc_valid && `DUT.u_fetchunit.i_state == fetch_hold && `DUT.u_IFIDReg.i_state == Reg_HOLD && `DUT.u_IDEXReg.i_state == Reg_BUBBLE);
    cp_fetch_fault_data_irq_drain_hold : coverpoint (`DUT.u_fetchunit.o_exc_valid && `DUT.u_fetchunit.i_state == fetch_hold && (`DUT.u_controller.irq_drain || `DUT.u_controller.irq_drain_start) && !`DUT.u_controller.pipeline_exc_alive_exclude_fetch);
endgroup

covergroup cg_fetch_fault_discard @(posedge clk);
    option.per_instance = 1;
    option.comment = "fetch fault discard";
    cp_fetch_fault_redirect_discard : coverpoint (`DUT.u_fetchunit.o_exc_valid  && `DUT.u_fetchunit.i_state == fetch_redirect && `DUT.u_controller.EX_redirect_alive);
    cp_fetch_fault_trap_discard : coverpoint (`DUT.u_fetchunit.o_exc_valid  && `DUT.u_fetchunit.i_state == fetch_redirect && `DUT.u_controller.i_trap);
    cp_fetch_fault_mret_discard : coverpoint (`DUT.u_fetchunit.o_exc_valid  && `DUT.u_fetchunit.i_state == fetch_redirect && `DUT.u_controller.i_mret);

endgroup

cg_inst_commit       u_inst_commit        = new();
cg_branch_taken      u_branch_taken       = new();
cg_mem_acc           u_mem_acc            = new();
cg_fetch_state       u_fetch_state        = new();
cg_IFID_state        u_IFID_state         = new();
cg_IDEX_state        u_IDEX_state         = new();
cg_EXMEM_state       u_EXMEM_state        = new();
cg_MEMWB_state       u_MEMWB_state        = new();
cg_irq_event         u_irq_event          = new();
cg_exc_event         u_exc_event          = new();
cg_stall             u_stall              = new();
cg_exc_kill          u_exc_kill           = new();
cq_irq_race          u_irq_race           = new();
cg_fetch_fault_hold  u_fetch_fault_hold   = new();
cg_fetch_fault_discard u_fetch_fault_discard = new();

final begin
    $display("");
    $display("================ CPU FUNCTIONAL COVERAGE ================");
    $display("cg_inst_commit        : %6.2f%%", u_inst_commit.get_coverage());
    $display("cg_branch_taken       : %6.2f%%", u_branch_taken.get_coverage());
    $display("cg_mem_acc            : %6.2f%%", u_mem_acc.get_coverage());
    $display("cg_fetch_state        : %6.2f%%", u_fetch_state.get_coverage());
    $display("cg_IFID_state         : %6.2f%%", u_IFID_state.get_coverage());
    $display("cg_IDEX_state         : %6.2f%%", u_IDEX_state.get_coverage());
    $display("cg_EXMEM_state        : %6.2f%%", u_EXMEM_state.get_coverage());
    $display("cg_MEMWB_state        : %6.2f%%", u_MEMWB_state.get_coverage());
    $display("cg_irq_event          : %6.2f%%", u_irq_event.get_coverage());
    $display("cg_exc_event          : %6.2f%%", u_exc_event.get_coverage());
    $display("cg_stall              : %6.2f%%", u_stall.get_coverage());
    $display("cg_exc_kill           : %6.2f%%", u_exc_kill.get_coverage());
    $display("cq_irq_race           : %6.2f%%", u_irq_race.get_coverage());
    $display("cg_fetch_fault_hold   : %6.2f%%", u_fetch_fault_hold.get_coverage());
    $display("cg_fetch_fault_discard: %6.2f%%", u_fetch_fault_discard.get_coverage());
    $display("Overall               : %6.2f%%", $get_coverage());
    $display("=========================================================");
    $display("");
end

`undef DUT

endmodule
