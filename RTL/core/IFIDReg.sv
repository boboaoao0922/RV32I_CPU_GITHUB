import RISC_V_PKG::*;
module IFIDReg (
    input logic clk,
    input logic rst_n,
    input Reg_state i_state,  //controller control reg's state
    input logic [31:0] i_inst, // inst provided by fetcher
    input logic [31:0] i_PC,   // PC provided by fetcher
    input logic i_fetch_valid, // fetcher valid

    input logic i_fetch_access_fault_alive, // fault must be 0 if access fault while backend redirect / exception cause flush
    input Mcause i_fetch_fault_cause,
    input logic [31:0] i_fetch_fault_tval,

    output logic [31:0] o_inst,  // ouptut instruction
    output logic [31:0] o_PC,  // output PC
    output logic o_reg_valid,  // register valid

    output logic o_exc_valid,
    output Mcause o_exc_mcause,
    output logic [31:0] o_exc_tval
);

always_ff@(posedge clk,negedge rst_n) begin
    if(!rst_n) 
        o_reg_valid <= 0;
    else begin
        case(i_state)
            Reg_BUBBLE: o_reg_valid <= 0;
            Reg_HOLD: o_reg_valid <= o_reg_valid;
            Reg_ADVANCE: begin
                if(i_fetch_valid || i_fetch_access_fault_alive)
                    o_reg_valid <= 1;
                else                    // Although state is advance but fetch unit's outvalid = 0, no new instruction.
                    o_reg_valid <= 0;
            end
            default: o_reg_valid <= 0;
        endcase
    end
end

always_ff@(posedge clk,negedge rst_n) begin
    if(!rst_n) begin
        o_inst <= 0;
        o_PC <= 0;
    end else begin
        if(i_state == Reg_ADVANCE)begin
            if(i_fetch_access_fault_alive)begin
                o_inst <= 32'h0000_0013;  // ADDI x0, x0, 0
                o_PC <= i_PC;
            end else if(i_fetch_valid)begin
                o_inst <= i_inst;
                o_PC <= i_PC;
            end
        end
    end
end

always_ff@(posedge clk,negedge rst_n) begin
    if(!rst_n) 
        o_exc_valid <= 0;
    else begin
        case(i_state)
            Reg_BUBBLE: o_exc_valid <= 0;
            Reg_HOLD: o_exc_valid <= o_exc_valid;
            Reg_ADVANCE: begin
                if(i_fetch_access_fault_alive)
                    o_exc_valid <= 1;
                else                     // Although state is advance but fetch unit's outvalid = 0, no new instruction.
                    o_exc_valid <= 0;
            end
            default: o_exc_valid <= 0;
        endcase
    end
end

always_ff@(posedge clk, negedge rst_n)begin
    if(!rst_n)begin
        o_exc_mcause <= Mcause_INST_MISALIGNED;
        o_exc_tval <= 0;
    end else if(i_state == Reg_ADVANCE && i_fetch_access_fault_alive) begin
        o_exc_mcause <= i_fetch_fault_cause;
        o_exc_tval <= i_fetch_fault_tval;
    end
end


endmodule