import RISC_V_PKG::*;
module CPU_checker(
    input logic clk,
    input logic rst_n
);

`define DUT TESTBENCH.dut.u_cpu

`define CHK_FAIL(msg) \
    begin \
        TESTBENCH.pattern.display_fail(msg); \
        $fatal(1,"\033[31m%s\033[0m", msg); \
    end

logic [6:0] bus_exc_alive;
assign bus_exc_alive = {`DUT.u_controller.IFID_exc_alive, `DUT.u_controller.ID_local_exc_alive, `DUT.u_controller.IDEX_exc_alive, `DUT.u_controller.EX_local_exc_alive, `DUT.u_controller.EXMEM_exc_alive, `DUT.u_controller.MEM_local_exc_alive, `DUT.u_controller.MEMWB_exc_alive};

property p_spec_mret_trap_no_conflit;
    @(posedge clk) disable iff (!rst_n)
    `DUT.u_controller.i_mret |-> !`DUT.u_controller.i_trap;
endproperty

property p_spec_trap_no_acc_new_inst;
    @(posedge clk) disable iff (!rst_n)
    `DUT.u_controller.i_trap |-> (`DUT.u_IFIDReg.i_state === Reg_BUBBLE);
endproperty

property p_spec_mret_no_acc_new_inst;
    @(posedge clk) disable iff (!rst_n)
    `DUT.u_controller.i_mret |-> (`DUT.u_IFIDReg.i_state === Reg_BUBBLE);
endproperty

property p_spec_trap_no_reg_valid;
    @(posedge clk) disable iff(!rst_n)
    `DUT.u_controller.i_trap |-> (`DUT.u_IFIDReg.o_reg_valid === 0 && `DUT.u_IDEXReg.o_reg_valid === 0 && `DUT.u_EXMEMReg.o_reg_valid === 0);
endproperty

property p_spec_exc_exist_no_new_inst;
    @(posedge clk) disable iff (!rst_n)
    `DUT.u_controller.pipeline_exc_alive_exclude_fetch |-> (`DUT.u_IFIDReg.i_state === Reg_BUBBLE || `DUT.u_IFIDReg.i_state === Reg_HOLD);
endproperty

property p_spec_ex_aliment_no_handshake;
    @(posedge clk) disable iff (!rst_n)
    `DUT.u_controller.o_EX_exc_valid_alive |-> (`DUT.o_cpu_req_LS_valid_D_cache === 0);
endproperty

property p_spec_ex_aliment_no_redirect;
    @(posedge clk) disable iff (!rst_n)
    `DUT.u_controller.o_EX_exc_valid_alive |-> (`DUT.u_controller.o_fetch_state != fetch_redirect && !$isunknown(`DUT.u_controller.o_fetch_state));
endproperty

property p_spec_irq_drain_no_new_inst;
    @(posedge clk) disable iff (!rst_n)
    (`DUT.u_controller.irq_drain || `DUT.u_controller.irq_drain_start) |-> (`DUT.u_IFIDReg.i_state === Reg_BUBBLE || `DUT.u_IFIDReg.i_state === Reg_HOLD);
endproperty

property p_spec_mret_pending_no_new_inst;
    @(posedge clk) disable iff (!rst_n)
    (`DUT.u_controller.mret_pending || `DUT.u_controller.mret_issue_fire) |-> (`DUT.u_IFIDReg.i_state === Reg_BUBBLE || `DUT.u_IFIDReg.i_state === Reg_HOLD);
endproperty

property p_spec_exc_alive_only_one;
    @(posedge clk) disable iff (!rst_n)
    `DUT.u_controller.pipeline_exc_alive_exclude_fetch |-> $onehot(bus_exc_alive);
endproperty

property p_spec_mem_exc_no_handshake_redirect;
    @(posedge clk) disable iff (!rst_n)
    `DUT.u_controller.o_MEM_exc_valid_alive |-> !`DUT.o_cpu_req_LS_valid_D_cache && (`DUT.u_controller.o_fetch_state != fetch_redirect);
endproperty

property p_spec_mem_hold_no_advance;
    @(posedge clk) disable iff (!rst_n)
    `DUT.u_controller.global_hold |-> (`DUT.u_fetchunit.i_state === fetch_hold && `DUT.u_IFIDReg.i_state === Reg_HOLD  && `DUT.u_IDEXReg.i_state === Reg_HOLD && `DUT.u_EXMEMReg.i_state === Reg_HOLD && `DUT.u_MEMWBReg.i_state === Reg_HOLD);
endproperty

property p_spec_mem_hold_no_commit_mret_trap;
    @(posedge clk) disable iff (!rst_n)
    `DUT.u_controller.global_hold |-> !`DUT.commit_fire && !`DUT.u_WBUnit.o_trap && !`DUT.u_WBUnit.o_mret;
endproperty

property p_redirect_no_new_inst;
    @(posedge clk) disable iff (!rst_n)
    `DUT.u_fetchunit.i_state === fetch_redirect |-> (`DUT.u_IFIDReg.i_state === Reg_BUBBLE);
endproperty

property p_spec_irq_take_pipeline_empty;
    @(posedge clk) disable iff (!rst_n)
    `DUT.u_controller.o_trap_interrupt |-> ( !`DUT.u_IFIDReg.o_reg_valid && !`DUT.u_IDEXReg.o_reg_valid && !`DUT.u_EXMEMReg.o_reg_valid && !`DUT.u_MEMWBReg.o_reg_valid);
endproperty

property p_spec_irq_drain_stop_when_exc_alive;
    @(posedge clk) disable iff (!rst_n)
    `DUT.u_controller.pipeline_exc_alive_exclude_fetch |=> !`DUT.u_controller.irq_drain;
endproperty

property p_spec_irq_drain_fetch_fault_no_accept;
    @(posedge clk) disable iff (!rst_n)
    `DUT.u_controller.irq_drain |-> (`DUT.u_IFIDReg.i_state === Reg_BUBBLE || `DUT.u_IFIDReg.i_state === Reg_HOLD) && (`DUT.u_fetchunit.i_state != fetch_capture);
endproperty

property p_spec_MEM_fault_kill_youger;
    @(posedge clk) disable iff (!rst_n)
    (`DUT.u_controller.o_MEM_exc_valid_alive && !`DUT.u_controller.global_hold) |-> !(`DUT.o_cpu_req_LS_valid_D_cache && `DUT.i_cpu_req_ready_D_cache) && `DUT.u_IFIDReg.i_state === Reg_BUBBLE && `DUT.u_IDEXReg.i_state === Reg_BUBBLE && `DUT.u_EXMEMReg.i_state === Reg_BUBBLE && `DUT.u_MEMWBReg.i_state === Reg_ADVANCE && `DUT.u_fetchunit.i_state === fetch_hold;
endproperty

property p_spec_exc_inst_no_we;
    @(posedge clk) disable iff (!rst_n)
    `DUT.u_MEMWBReg.o_exc_valid |-> !`DUT.u_RegFile.rd_wen && !`DUT.u_CSRFile.i_csr_we;
endproperty

property p_spec_exc_inst_no_commit_exclude_ECALL_BREAK;
    @(posedge clk) disable iff (!rst_n)
    `DUT.u_MEMWBReg.o_exc_valid && (`DUT.u_MEMWBReg.o_inst_type !== Inst_ECALL && `DUT.u_MEMWBReg.o_inst_type !== Inst_EBREAK)
    |-> !`DUT.commit_fire;
endproperty

property p_spec_inst_acc_fault_at_hold_no_discard;
    @(posedge clk) disable iff (!rst_n)
    `DUT.i_cpu_acc_fault_I_cache && `DUT.u_fetchunit.i_state === fetch_hold |=> `DUT.u_fetchunit.exc_pending;
endproperty

property p_spec_fetch_capture_discard_exc;
    @(posedge clk) disable iff (!rst_n)
    `DUT.u_fetchunit.i_state === fetch_capture |=> !`DUT.u_fetchunit.exc_pending;
endproperty

property p_spec_fetch_capture_IFID_receive;
    @(posedge clk) disable iff (!rst_n)
    `DUT.u_fetchunit.i_state === fetch_capture |=> `DUT.u_IFIDReg.o_reg_valid && 
    `DUT.u_IFIDReg.o_exc_valid && 
    (`DUT.u_IFIDReg.o_exc_mcause === $past(`DUT.u_fetchunit.o_mcause)) && 
    (`DUT.u_IFIDReg.o_exc_tval === $past(`DUT.u_fetchunit.o_mtval)) &&
    (`DUT.u_IFIDReg.o_PC === $past(`DUT.u_fetchunit.o_PC)) &&
    (`DUT.u_IFIDReg.o_inst === 32'h0000_0013);
endproperty

property p_spec_fetch_capture_exc_discard;
    @(posedge clk) disable iff (!rst_n)
    `DUT.u_fetchunit.i_state === fetch_redirect |=> !`DUT.u_fetchunit.exc_pending;
endproperty

/*
property p_spec_each_req_handshake_once;
    @(posedge clk) disable iff (!rst_n)
    `DUT.i_cpu_req_ready_D_cache && `DUT.o_cpu_req_LS_valid_D_cache |=> $changed(`DUT.u_IDEXReg.i_PC);
endproperty
*/
// pipeline register  state assertion

// hold assertion
property p_spec_IFID_hold_no_change;
    @(posedge clk) disable iff (!rst_n)
    `DUT.u_IFIDReg.i_state === Reg_HOLD |=> $stable(`DUT.u_IFIDReg.o_reg_valid) && $stable(`DUT.u_IFIDReg.o_exc_valid) &&  $stable(`DUT.u_IFIDReg.o_PC) && $stable(`DUT.u_IFIDReg.o_inst);
endproperty

property p_spec_IDEX_hold_no_change;
    @(posedge clk) disable iff (!rst_n)
    `DUT.u_IDEXReg.i_state === Reg_HOLD |=> $stable(`DUT.u_IDEXReg.o_reg_valid) && $stable(`DUT.u_IDEXReg.o_exc_valid) &&  $stable(`DUT.u_IDEXReg.o_PC) && $stable(`DUT.u_IDEXReg.o_inst);
endproperty

property p_spec_EXMEM_hold_no_change;
    @(posedge clk) disable iff (!rst_n)
    `DUT.u_EXMEMReg.i_state === Reg_HOLD |=> $stable(`DUT.u_EXMEMReg.o_reg_valid) && $stable(`DUT.u_EXMEMReg.o_exc_valid) &&  $stable(`DUT.u_EXMEMReg.o_PC) && $stable(`DUT.u_EXMEMReg.o_inst);
endproperty

property p_spec_MEMWB_hold_no_change;
    @(posedge clk) disable iff (!rst_n)
    `DUT.u_MEMWBReg.i_state === Reg_HOLD |=> $stable(`DUT.u_MEMWBReg.o_reg_valid) && $stable(`DUT.u_MEMWBReg.o_exc_valid) &&  $stable(`DUT.u_MEMWBReg.o_PC) && $stable(`DUT.u_MEMWBReg.o_inst);
endproperty

// advance assertion

property p_spec_IFID_advance_acc_fetch;
    @(posedge clk) disable iff (!rst_n)
    `DUT.u_IFIDReg.i_state === Reg_ADVANCE && `DUT.u_fetchunit.o_out_valid  && !`DUT.u_IFIDReg.i_fetch_access_fault_alive |=> `DUT.u_IFIDReg.o_inst === $past(`DUT.u_fetchunit.o_inst) && `DUT.u_IFIDReg.o_PC === $past(`DUT.u_fetchunit.o_PC);
endproperty

property p_spec_IFID_advance_acc_fault;
    @(posedge clk) disable iff (!rst_n)
    `DUT.u_IFIDReg.i_state === Reg_ADVANCE && `DUT.u_IFIDReg.i_fetch_access_fault_alive |=> `DUT.u_IFIDReg.o_exc_valid && (`DUT.u_IFIDReg.o_exc_mcause === $past(`DUT.u_fetchunit.o_mcause));
endproperty

property p_spec_IDEX_advance_acc_IFID;
    @(posedge clk) disable iff (!rst_n)
    `DUT.u_IDEXReg.i_state === Reg_ADVANCE |=> `DUT.u_IDEXReg.o_inst === $past(`DUT.u_IFIDReg.o_inst) && `DUT.u_IDEXReg.o_PC === $past(`DUT.u_IFIDReg.o_PC);
endproperty

property p_spec_EXMEM_advance_acc_IDEX;
    @(posedge clk) disable iff (!rst_n)
    `DUT.u_EXMEMReg.i_state === Reg_ADVANCE |=> `DUT.u_EXMEMReg.o_inst === $past(`DUT.u_IDEXReg.o_inst) && `DUT.u_EXMEMReg.o_PC === $past(`DUT.u_IDEXReg.o_PC);
endproperty

property p_spec_MEMWB_advance_acc_IDEX;
    @(posedge clk) disable iff (!rst_n)
    `DUT.u_MEMWBReg.i_state === Reg_ADVANCE |=> `DUT.u_MEMWBReg.o_inst === $past(`DUT.u_EXMEMReg.o_inst) && `DUT.u_MEMWBReg.o_PC === $past(`DUT.u_EXMEMReg.o_PC);
endproperty

// bubble assertion

property p_spec_IFID_bubble_no_valid;
    @(posedge clk) disable iff (!rst_n)
    `DUT.u_IFIDReg.i_state === Reg_BUBBLE |=> !`DUT.u_IFIDReg.o_reg_valid;
endproperty

property p_spec_IDEX_bubble_no_valid;
    @(posedge clk) disable iff (!rst_n)
    `DUT.u_IDEXReg.i_state === Reg_BUBBLE |=> !`DUT.u_IDEXReg.o_reg_valid;
endproperty

property p_spec_EXMEM_bubble_no_valid;
    @(posedge clk) disable iff (!rst_n)
    `DUT.u_EXMEMReg.i_state === Reg_BUBBLE |=> !`DUT.u_EXMEMReg.o_reg_valid;
endproperty

property p_spec_MEMWB_bubble_no_valid;
    @(posedge clk) disable iff (!rst_n)
    `DUT.u_MEMWBReg.i_state === Reg_BUBBLE |=> !`DUT.u_MEMWBReg.o_reg_valid;
endproperty

// csr state when trap / mret
property p_spec_exc_trap_csr_stage;
    @(posedge clk) disable iff (!rst_n)
    `DUT.u_controller.i_trap && ! `DUT.u_controller.o_trap_interrupt |=> 
    (`DUT.u_CSRFile.mepc === $past(`DUT.u_WBUnit.o_trap_mepc)) && 
    (`DUT.u_CSRFile.mcause === $past(`DUT.u_WBUnit.o_trap_mcause)) && 
    (`DUT.u_CSRFile.mtval === $past(`DUT.u_WBUnit.o_trap_mtval)) && 
    (`DUT.u_CSRFile.mstatus_MPIE === $past(`DUT.u_CSRFile.mstatus_MIE)) &&
    (`DUT.u_CSRFile.mstatus_MIE === 0); 
endproperty

property p_spec_mret_csr_stage;
     @(posedge clk) disable iff (!rst_n)
     `DUT.u_controller.i_mret |=>
     (`DUT.u_CSRFile.mstatus_MPIE === 1) && 
     (`DUT.u_CSRFile.mstatus_MIE === $past(`DUT.u_CSRFile.mstatus_MPIE)); 
endproperty

property p_spec_irq_trap_csr_stage;
    @(posedge clk) disable iff (!rst_n)
    `DUT.u_controller.i_trap && `DUT.u_controller.o_trap_interrupt |=>
    (`DUT.u_CSRFile.mepc === $past(`DUT.u_WBUnit.o_trap_mepc)) &&
    (`DUT.u_CSRFile.mcause === Mcause_EXT_INTERRUPT) &&
    (`DUT.u_CSRFile.mtval === 0) &&
    (`DUT.u_CSRFile.mstatus_MPIE === $past(`DUT.u_CSRFile.mstatus_MIE)) &&
    (`DUT.u_CSRFile.mstatus_MIE === 0);
endproperty






CHK_spec_mret_trap_no_conflit: assert property(p_spec_mret_trap_no_conflit) 
    else `CHK_FAIL("[SPEC-FAIL] mret and trap can not excute at the same time");
CHK_spec_trap_no_acc_new_inst: assert property(p_spec_trap_no_acc_new_inst)
    else `CHK_FAIL("[SPEC-FAIL] when trap, IFID cannot accept new inst");
CHK_spec_mret_no_acc_new_inst: assert property(p_spec_mret_no_acc_new_inst)
    else `CHK_FAIL("[SPEC-FAIL] when mret, IFID cannot accept new inst");
CHK_spec_trap_no_reg_valid: assert property(p_spec_trap_no_reg_valid)
    else `CHK_FAIL("[SPEC-FAIL] when trap, IFID / IDEX / EXMEM reg can not be valid");
CHK_spec_exc_exist_no_new_inst: assert property(p_spec_exc_exist_no_new_inst)
    else `CHK_FAIL("[SPEC-FAIL] when there is exception alive, IFID cannot accept new inst");
CHK_spec_ex_aliment_no_handshake: assert property(p_spec_ex_aliment_no_handshake)
    else `CHK_FAIL("[SPEC-FAIL] when there is exception alive at EX stage, LSUnit cannot handshake new request");
CHK_spec_ex_aliment_no_redirect: assert property(p_spec_ex_aliment_no_redirect)
    else `CHK_FAIL("[SPEC-FAIL] when there is exception alive at EX stage, fetch unit cannot redirect");
CHK_spec_irq_drain_no_new_inst: assert property(p_spec_irq_drain_no_new_inst)
    else `CHK_FAIL("[SPEC-FAIL] when irq draining / start to drain, IFID cannot accept new inst");
CHK_spec_mret_pending_no_new_inst: assert property(p_spec_mret_pending_no_new_inst)
    else `CHK_FAIL("[SPEC-FAIL] when there is mret pending, IFID cannot accept new inst");
CHK_spec_exc_alive_only_one: assert property(p_spec_exc_alive_only_one)
    else `CHK_FAIL("[SPEC-FAIL] only the oldest pipeline exception may be alive");
CHK_spec_mem_exc_no_handshake_redirect: assert property(p_spec_mem_exc_no_handshake_redirect)
    else `CHK_FAIL("[SPEC-FAIL] surviving MEM exception must block younger LS request and redirect");
CHK_spec_mem_hold_no_advance: assert property(p_spec_mem_hold_no_advance)
    else `CHK_FAIL("[SPEC-FAIL] memory stall must hold fetch and all pipeline registers");
CHK_spec_mem_hold_no_commit_mret_trap: assert property(p_spec_mem_hold_no_commit_mret_trap)
    else `CHK_FAIL("[SPEC-FAIL] memory stall must block commit, trap, and mret");
CHK_redirect_no_new_inst: assert property(p_redirect_no_new_inst)
    else `CHK_FAIL("[SPEC-FAIL] fetch redirect must bubble IFID");
CHK_spec_irq_take_pipeline_empty: assert property(p_spec_irq_take_pipeline_empty)
    else `CHK_FAIL("[SPEC-FAIL] interrupt take requires an empty pipeline");
CHK_spec_irq_drain_stop_when_exc_alive: assert property(p_spec_irq_drain_stop_when_exc_alive)
    else `CHK_FAIL("[SPEC-FAIL] synchronous exception must stop IRQ drain");
CHK_spec_irq_drain_fetch_fault_no_accept: assert property(p_spec_irq_drain_fetch_fault_no_accept)
    else `CHK_FAIL("[SPEC-FAIL] IRQ drain must not accept a fetch fault");
CHK_spec_MEM_fault_kill_youger: assert property(p_spec_MEM_fault_kill_youger)
    else `CHK_FAIL("[SPEC-FAIL] surviving MEM fault must kill younger pipeline effects");
CHK_spec_exc_inst_no_we: assert property(p_spec_exc_inst_no_we)
    else `CHK_FAIL("[SPEC-FAIL] faulting instruction must not write GPR or CSR");
CHK_spec_exc_inst_no_commit_exclude_ECALL_BREAK: assert property(p_spec_exc_inst_no_commit_exclude_ECALL_BREAK)
    else `CHK_FAIL("[SPEC-FAIL] non-ECALL/EBREAK faulting instruction must not commit");
CHK_spec_inst_acc_fault_at_hold_no_discard: assert property(p_spec_inst_acc_fault_at_hold_no_discard)
    else `CHK_FAIL("[SPEC-FAIL] held instruction access fault must remain pending");
CHK_spec_fetch_capture_discard_exc: assert property(p_spec_fetch_capture_discard_exc)
    else `CHK_FAIL("[SPEC-FAIL] fetch capture must clear its pending fault");
CHK_spec_fetch_capture_IFID_receive: assert property(p_spec_fetch_capture_IFID_receive)
    else `CHK_FAIL("[SPEC-FAIL] IFID must receive captured fetch fault metadata");
CHK_spec_fetch_capture_exc_discard: assert property(p_spec_fetch_capture_exc_discard)
    else `CHK_FAIL("[SPEC-FAIL] fetch redirect must discard pending fault");
CHK_spec_IFID_hold_no_change: assert property(p_spec_IFID_hold_no_change)
    else `CHK_FAIL("[SPEC-FAIL] IFID changed while held");
CHK_spec_IDEX_hold_no_change: assert property(p_spec_IDEX_hold_no_change)
    else `CHK_FAIL("[SPEC-FAIL] IDEX changed while held");
CHK_spec_EXMEM_hold_no_change: assert property(p_spec_EXMEM_hold_no_change)
    else `CHK_FAIL("[SPEC-FAIL] EXMEM changed while held");
CHK_spec_MEMWB_hold_no_change: assert property(p_spec_MEMWB_hold_no_change)
    else `CHK_FAIL("[SPEC-FAIL] MEMWB changed while held");
CHK_spec_IFID_advance_acc_fetch: assert property(p_spec_IFID_advance_acc_fetch)
    else `CHK_FAIL("[SPEC-FAIL] IFID did not capture a valid fetch response");
CHK_spec_IFID_advance_acc_fault: assert property(p_spec_IFID_advance_acc_fault)
    else `CHK_FAIL("[SPEC-FAIL] IFID did not capture a surviving fetch fault");
CHK_spec_IDEX_advance_acc_IFID: assert property(p_spec_IDEX_advance_acc_IFID)
    else `CHK_FAIL("[SPEC-FAIL] IDEX did not advance IFID payload");
CHK_spec_EXMEM_advance_acc_IDEX: assert property(p_spec_EXMEM_advance_acc_IDEX)
    else `CHK_FAIL("[SPEC-FAIL] EXMEM did not advance IDEX payload");
CHK_spec_MEMWB_advance_acc_IDEX: assert property(p_spec_MEMWB_advance_acc_IDEX)
    else `CHK_FAIL("[SPEC-FAIL] MEMWB did not advance EXMEM payload");
CHK_spec_IFID_bubble_no_valid: assert property(p_spec_IFID_bubble_no_valid)
    else `CHK_FAIL("[SPEC-FAIL] IFID valid survived a bubble");
CHK_spec_IDEX_bubble_no_valid: assert property(p_spec_IDEX_bubble_no_valid)
    else `CHK_FAIL("[SPEC-FAIL] IDEX valid survived a bubble");
CHK_spec_EXMEM_bubble_no_valid: assert property(p_spec_EXMEM_bubble_no_valid)
    else `CHK_FAIL("[SPEC-FAIL] EXMEM valid survived a bubble");
CHK_spec_MEMWB_bubble_no_valid: assert property(p_spec_MEMWB_bubble_no_valid)
    else `CHK_FAIL("[SPEC-FAIL] MEMWB valid survived a bubble");
CHK_spec_exc_trap_csr_stage: assert property(p_spec_exc_trap_csr_stage)
    else `CHK_FAIL("[SPEC-FAIL] CSR file updated incorrectly when excepetion trap");
CHK_spec_mret_csr_stage: assert property(p_spec_mret_csr_stage)
    else `CHK_FAIL("[SPEC-FAIL] CSR file updated incorrectly when mret");
CHK_spec_irq_trap_csr_stage: assert property(p_spec_irq_trap_csr_stage)
    else `CHK_FAIL("[SPEC-FAIL] CSR file updated incorrectly when interrupt trap");

`undef CHK_FAIL
`undef DUT

endmodule
