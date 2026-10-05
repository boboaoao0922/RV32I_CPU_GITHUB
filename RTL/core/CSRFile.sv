import RISC_V_PKG::*;
module CSRFile(
    input logic clk,
    input logic rst_n,

    input logic i_csr_we,
    
    input Csr_sel i_csr_ID_rd,  // for ID read csr
    input logic [31:0] i_csr_wdata,
    input Csr_sel i_csr_WB_rd, //for WB write csr

    input logic i_trap,
    input logic [31:0] i_trap_mepc,
    input logic [31:0] i_trap_mcause,
    input logic [31:0] i_trap_mtval,

    input logic i_mret,

    input logic i_mip_MEIP,

    output logic [31:0] o_csr_data,
    
    output logic [31:0] o_mepc,
    output logic [31:0] o_mtvec, 
    output logic o_mstatus_MPIE,
    output logic o_mstatus_MIE,
    output logic o_mie_MEIE,
    output logic o_mip_MEIP
);

logic [31:0] mepc, mtvec, mcause, mtval;
logic mstatus_MIE, mstatus_MPIE;
logic mie_MEIE, mip_MEIP;

assign o_mstatus_MIE = mstatus_MIE;
assign o_mstatus_MPIE = mstatus_MPIE;
assign o_mie_MEIE = mie_MEIE;
assign o_mip_MEIP = mip_MEIP;
assign o_mepc = mepc;
assign o_mtvec = mtvec;

always_ff@(posedge clk, negedge rst_n)begin
    if(!rst_n)begin
        mepc <= 0;
        mtvec <= 0;
        mcause <= 0;
        mtval <= 0;
    end else begin
        if(i_trap)begin
            mepc <= {i_trap_mepc[31:2],2'd0};
            mcause <= i_trap_mcause;
            mtval <= i_trap_mtval;
        end else if(i_csr_we && !i_mret)begin
            case(i_csr_WB_rd)
                Csr_mepc: mepc <= {i_csr_wdata[31:2],2'd0};
                Csr_mtvec: mtvec <= {i_csr_wdata[31:2],2'd0};
                Csr_mcause: mcause <= i_csr_wdata;
                Csr_mtval: mtval <= i_csr_wdata;
            endcase
        end
    end
end

assign mip_MEIP = i_mip_MEIP;
/*
always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)
        mip_MEIP <= 0;
    else 
        mip_MEIP <= i_mip_MEIP;
end
*/

always_ff@(posedge clk, negedge rst_n)begin
    if(!rst_n)
        mie_MEIE <= 0;
    else if(i_csr_we && i_csr_WB_rd == Csr_mie && !i_trap && !i_mret)
        mie_MEIE <= i_csr_wdata[11];
end

always_ff@(posedge clk, negedge rst_n)begin
    if(!rst_n)begin
        mstatus_MIE <= 0;
        mstatus_MPIE <= 0;
    end else begin
        if(i_trap)begin
            mstatus_MIE <= 0;
            mstatus_MPIE <= mstatus_MIE;
        end else if(i_mret)begin
            mstatus_MIE <= mstatus_MPIE;
            mstatus_MPIE <= 1;
        end else if(i_csr_we && i_csr_WB_rd == Csr_mstatus)begin
            mstatus_MIE <= i_csr_wdata[3];
            mstatus_MPIE <= i_csr_wdata[7];
        end
    end
end

always_comb begin
    case(i_csr_ID_rd)
        Csr_mstatus: o_csr_data = {19'd0, 2'b11, 3'd0, mstatus_MPIE, 3'd0, mstatus_MIE, 3'd0};
        Csr_mepc: o_csr_data = mepc;
        Csr_mtval: o_csr_data = mtval;
        Csr_mtvec: o_csr_data = mtvec;
        Csr_mcause: o_csr_data = mcause;
        Csr_mip: o_csr_data = {20'd0, mip_MEIP, 11'd0};
        Csr_mie: o_csr_data = {20'd0, mie_MEIE, 11'd0};
        default: o_csr_data = 0;
    endcase
end


endmodule