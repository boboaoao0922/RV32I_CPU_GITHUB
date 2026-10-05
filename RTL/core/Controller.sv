import RISC_V_PKG::*;
module Controller (
    input logic clk,
    input logic rst_n,
    //====special signal==
    //input logic i_decode_illegal,
    //input logic i_mem_err,
    //====================
    input logic i_IF_fetch_valid,
    input logic i_EX_redirect,
    input logic [31:0] i_EX_redirect_addr,
    input logic i_GPR_load_use_stall,
    input logic i_CSR_load_use_stall,
    input logic i_mem_stall,

    input logic i_IFID_reg_valid,
    input logic i_IDEX_reg_valid,
    input logic i_EXMEM_reg_valid,
    input logic i_MEMWB_reg_valid,

    input logic i_fetch_exc_valid,
    input logic i_ID_exc_valid,
    input logic i_EX_exc_valid,
    input logic i_MEM_exc_valid,

    input logic i_IFID_exc_valid,
    input logic i_IDEX_exc_valid,
    input logic i_EXMEM_exc_valid,
    input logic i_MEMWB_exc_valid,

    input logic i_ID_flag_mret,
    input logic i_IDEX_flag_mret,
    input logic i_EXMEM_flag_mret,
    input logic i_MEMWB_flag_mret,

    input logic [31:0] i_mepc,
    input logic i_mstatus_MIE,
    input logic i_mie_MEIE,
    input logic i_mip_MEIP,
    input logic i_trap,
    input logic i_mret,
    input logic [31:0] i_mtvec,
    input logic i_WB_csr_we,
    //input logic i_ext_interrupt, // from external 

    output fetch_state o_fetch_state,  
    output Reg_state o_IFID_state,
    output Reg_state o_IDEX_state,
    output Reg_state o_EXMEM_state,
    output Reg_state o_MEMWB_state,
    output logic o_LS_issue_allowed,
    output logic o_retire_allowed,
    output logic o_trap_allowed,
    output logic o_trap_interrupt,
    output logic [31:0] o_fetch_redirect_addr,
    output logic o_fetch_exc_valid_alive,
    output logic o_ID_exc_valid_alive,
    output logic o_EX_exc_valid_alive,
    output logic o_MEM_exc_valid_alive
);

Con_state state;
logic irq_eligible, irq_pending, irq_drain_start, irq_drain, irq_in_trap;
logic exc_pending, mret_pending;
logic fetch_local_exc_alive, ID_local_exc_alive, EX_local_exc_alive, MEM_local_exc_alive;
logic IFID_exc_alive, IDEX_exc_alive, EXMEM_exc_alive, MEMWB_exc_alive; 
logic EX_redirect_alive;
logic pipeline_exc_alive_exclude_fetch;
logic mret_alive;
logic MEMWB_mret_alive, EXMEM_mret_alive, IDEX_mret_alive, ID_mret_alive;
logic mret_issue_fire; 
logic global_hold, IFID_hold; 
logic flag_in_trap;
logic EX_side_effect_allowed;
logic exc_kill_IFID, exc_kill_IDEX, exc_kill_EXMEM;


always_ff@(posedge clk, negedge rst_n)begin
    if(!rst_n)
        state <= Con_RESET;
    else
        state <= Con_WORK;
end

assign irq_eligible = i_mip_MEIP && i_mie_MEIE && i_mstatus_MIE;
always_ff@(posedge clk, negedge rst_n)begin
    if(!rst_n)
        irq_in_trap <= 0;
    else if(irq_in_trap && i_mret)
        irq_in_trap <= 0;
    else if(o_trap_interrupt)
        irq_in_trap <= 1;    
end 

always_ff@(posedge clk, negedge rst_n)begin
    if(!rst_n)
        irq_pending <= 0;
    else if(o_trap_interrupt)
        irq_pending <= 0;
    else if(irq_eligible && !irq_in_trap && !i_WB_csr_we)
        irq_pending <= 1;
end

assign MEMWB_exc_alive = i_MEMWB_reg_valid && i_MEMWB_exc_valid;
assign MEM_local_exc_alive = i_EXMEM_reg_valid && i_MEM_exc_valid && !MEMWB_exc_alive && !i_EXMEM_exc_valid;
assign EXMEM_exc_alive = i_EXMEM_reg_valid && i_EXMEM_exc_valid && !MEMWB_exc_alive;
assign EX_local_exc_alive = i_IDEX_reg_valid && i_EX_exc_valid && !(MEMWB_exc_alive || MEM_local_exc_alive || EXMEM_exc_alive) && !i_IDEX_exc_valid;
assign EX_redirect_alive = i_IDEX_reg_valid && i_EX_redirect && !(MEMWB_exc_alive || MEM_local_exc_alive || EXMEM_exc_alive || EX_local_exc_alive) && !i_IDEX_exc_valid;
assign IDEX_exc_alive = i_IDEX_reg_valid && i_IDEX_exc_valid && !(MEMWB_exc_alive || MEM_local_exc_alive || EXMEM_exc_alive);
assign ID_local_exc_alive = i_IFID_reg_valid && i_ID_exc_valid && !(MEMWB_exc_alive || MEM_local_exc_alive || EXMEM_exc_alive || EX_local_exc_alive || IDEX_exc_alive || EX_redirect_alive) && !i_IFID_exc_valid;
assign IFID_exc_alive = i_IFID_reg_valid && i_IFID_exc_valid && !(MEMWB_exc_alive || MEM_local_exc_alive || EXMEM_exc_alive || EX_local_exc_alive || IDEX_exc_alive || EX_redirect_alive);

assign o_fetch_exc_valid_alive = fetch_local_exc_alive;
assign o_ID_exc_valid_alive = ID_local_exc_alive;
assign o_EX_exc_valid_alive = EX_local_exc_alive;
assign o_MEM_exc_valid_alive = MEM_local_exc_alive;

assign pipeline_exc_alive_exclude_fetch = IFID_exc_alive || ID_local_exc_alive || IDEX_exc_alive || EX_local_exc_alive || EXMEM_exc_alive || MEM_local_exc_alive || MEMWB_exc_alive;

assign MEMWB_mret_alive = (i_MEMWB_reg_valid && i_MEMWB_flag_mret && !MEMWB_exc_alive);
assign EXMEM_mret_alive = (i_EXMEM_reg_valid && i_EXMEM_flag_mret && !(MEMWB_exc_alive || MEM_local_exc_alive || EXMEM_exc_alive));
assign IDEX_mret_alive = (i_IDEX_reg_valid && i_IDEX_flag_mret && !(MEMWB_exc_alive || MEM_local_exc_alive || EXMEM_exc_alive || EX_local_exc_alive || IDEX_exc_alive || EX_redirect_alive));
assign ID_mret_alive = (i_IFID_reg_valid && i_ID_flag_mret && !(MEMWB_exc_alive || MEM_local_exc_alive || EXMEM_exc_alive || EX_local_exc_alive || IDEX_exc_alive || EX_redirect_alive));

assign mret_alive = MEMWB_mret_alive || EXMEM_mret_alive || IDEX_mret_alive || ID_mret_alive;

assign fetch_local_exc_alive = i_fetch_exc_valid && !(MEMWB_exc_alive || MEM_local_exc_alive || EXMEM_exc_alive || EX_local_exc_alive || IDEX_exc_alive || ID_local_exc_alive || EX_redirect_alive || i_trap || i_mret || mret_alive);


assign irq_drain_start = irq_pending && !irq_drain && !(global_hold || IFID_hold || mret_pending || mret_alive || pipeline_exc_alive_exclude_fetch || flag_in_trap || i_trap || i_mret);

assign global_hold = i_mem_stall;
assign IFID_hold = i_GPR_load_use_stall || i_CSR_load_use_stall;

assign mret_issue_fire = ID_mret_alive && !(global_hold || IFID_hold);
assign EX_side_effect_allowed = !(MEMWB_exc_alive || MEM_local_exc_alive || EXMEM_exc_alive || EX_local_exc_alive || IDEX_exc_alive);

assign exc_kill_EXMEM = MEM_local_exc_alive;
assign exc_kill_IDEX = EX_local_exc_alive || MEM_local_exc_alive;
assign exc_kill_IFID = ID_local_exc_alive || EX_local_exc_alive || MEM_local_exc_alive;

always_ff@(posedge clk, negedge rst_n)begin
    if(!rst_n)
        mret_pending <= 0;
    else if(!mret_alive || i_mret)
        mret_pending <= 0;
    else if(mret_issue_fire || (MEMWB_mret_alive || EXMEM_mret_alive || IDEX_mret_alive))
        mret_pending <= 1;
end

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)
        flag_in_trap <= 0;
    else if(i_mret)
        flag_in_trap <= 0;
    else if(i_trap)
        flag_in_trap <= 1;
end

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)
        irq_drain <= 0;
    else if((irq_drain && pipeline_exc_alive_exclude_fetch) || o_trap_interrupt)
        irq_drain <= 0;
    else if(irq_drain_start)
        irq_drain <= 1;
end

always_comb begin
    if(i_trap)
        o_fetch_redirect_addr = i_mtvec;
    else if(i_mret)
        o_fetch_redirect_addr = i_mepc;
    else if(EX_redirect_alive && EX_side_effect_allowed)
        o_fetch_redirect_addr = i_EX_redirect_addr;
    else
        o_fetch_redirect_addr = 0;
end

always_comb begin
    case(state)
        Con_RESET: o_fetch_state = fetch_clear;
        Con_WORK:begin
            if(global_hold)
                o_fetch_state = fetch_hold;
            else if(i_trap || i_mret)
                o_fetch_state = fetch_redirect;
            else if(pipeline_exc_alive_exclude_fetch || mret_issue_fire || mret_pending || irq_drain || irq_drain_start)
                o_fetch_state = fetch_hold;
            else if(EX_redirect_alive && EX_side_effect_allowed) 
                o_fetch_state = fetch_redirect;
             else if(IFID_hold)
                o_fetch_state = fetch_hold;
            else if(fetch_local_exc_alive)
                o_fetch_state = fetch_capture;
            else
                o_fetch_state = fetch_load;
        end
        default: o_fetch_state = fetch_clear;
    endcase
end

always_comb begin
    case(state)
        Con_RESET: o_IFID_state = Reg_BUBBLE;
        Con_WORK:begin
            if(global_hold)
                o_IFID_state = Reg_HOLD;
            else if(mret_issue_fire || mret_pending || exc_kill_IFID || EX_redirect_alive || irq_drain || irq_drain_start || i_trap || i_mret)
                o_IFID_state = Reg_BUBBLE;
            else if(IFID_hold)
                o_IFID_state = Reg_HOLD;
            else if(!i_IF_fetch_valid)
                o_IFID_state = Reg_BUBBLE;
            else 
                o_IFID_state = Reg_ADVANCE;
        end
        default: o_IFID_state = Reg_BUBBLE;
    endcase
end

always_comb begin
    case(state)
        Con_RESET: o_IDEX_state = Reg_BUBBLE;
        Con_WORK:begin
            if(global_hold)
                o_IDEX_state = Reg_HOLD;
            else if(IFID_hold || EX_redirect_alive || exc_kill_IDEX)
                o_IDEX_state = Reg_BUBBLE;
            else
                o_IDEX_state = Reg_ADVANCE;
        end
        default: o_IDEX_state = Reg_BUBBLE;
    endcase
end

always_comb begin
    case(state)
        Con_RESET: o_EXMEM_state = Reg_BUBBLE;
        Con_WORK:begin
            if(global_hold)
                o_EXMEM_state = Reg_HOLD;
            else if(exc_kill_EXMEM)
                o_EXMEM_state = Reg_BUBBLE;
            else
                o_EXMEM_state = Reg_ADVANCE;
        end
        default: o_EXMEM_state = Reg_BUBBLE;
    endcase
end

always_comb begin
    case(state)
        Con_RESET: o_MEMWB_state = Reg_BUBBLE;
        Con_WORK:begin
            if(global_hold)
                o_MEMWB_state = Reg_HOLD;
            else 
                o_MEMWB_state = Reg_ADVANCE;
        end
        default: o_MEMWB_state = Reg_BUBBLE;
    endcase
end

always_comb begin
    case(state)
        Con_RESET: o_LS_issue_allowed = 0;
        Con_WORK:begin
                if(EX_side_effect_allowed)
                    o_LS_issue_allowed = 1;
                else
                    o_LS_issue_allowed = 0;
        end
        default: o_LS_issue_allowed = 0;
    endcase
end

always_comb begin
    case(state)
        Con_RESET: o_retire_allowed = 0;
        Con_WORK:begin
            if(i_mem_stall)
                o_retire_allowed = 0;
            else 
                o_retire_allowed = 1;
        end
        default: o_retire_allowed = 0;
    endcase
end

assign o_trap_allowed = o_retire_allowed;

assign o_trap_interrupt = irq_pending && irq_drain && !flag_in_trap && !(i_IFID_reg_valid || i_IDEX_reg_valid || i_EXMEM_reg_valid || i_MEMWB_reg_valid) && !global_hold;

endmodule
