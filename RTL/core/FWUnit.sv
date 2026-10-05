import RISC_V_PKG::*;
module FWUnit (
    input logic [4:0] i_IDEX_rs1,
    input logic [4:0] i_IDEX_rs2,
    //input Use_rs i_IDEX_use_rs,
    input logic [31:0] i_IDEX_rs1_data,
    input logic [31:0] i_IDEX_rs2_data,

    input logic i_EXMEM_reg_valid,
    input logic [4:0] i_EXMEM_rd,
    input logic i_EXMEM_reg_we,
    input logic [31:0] i_EXMEM_alu_result,
    input logic [31:0] i_EXMEM_imm,
    input logic [31:0] i_EXMEM_PCA4,
    input logic [31:0] i_EXMEM_csr_old_data,
    input WB_source i_EXMEM_wbsrc,

    input logic i_MEMWB_reg_valid,
    input logic [4:0] i_MEMWB_rd,
    input logic i_MEMWB_reg_we,
    input logic [31:0] i_MEMWB_alu_result,
    input logic [31:0] i_MEMWB_imm,
    input logic [31:0] i_MEMWB_PCA4,
    input logic [31:0] i_MEMWB_mem_rsp,
    input logic [31:0] i_MEMWB_csr_old_data,
    input WB_source i_MEMWB_wbsrc,

    output logic [31:0] o_forward_rs1,
    output logic [31:0] o_forward_rs2
);

always_comb begin
    if(i_EXMEM_reg_valid && i_EXMEM_reg_we && i_EXMEM_rd != 0 && i_EXMEM_rd == i_IDEX_rs1)begin
        case(i_EXMEM_wbsrc)
            WB_alu: o_forward_rs1 = i_EXMEM_alu_result;
            WB_imm: o_forward_rs1 = i_EXMEM_imm;
            WB_PCA4: o_forward_rs1 = i_EXMEM_PCA4;
            WB_csr: o_forward_rs1 = i_EXMEM_csr_old_data;
            default: o_forward_rs1 = i_IDEX_rs1_data;
        endcase
    end else if(i_MEMWB_reg_valid && i_MEMWB_reg_we && i_MEMWB_rd != 0 && i_MEMWB_rd == i_IDEX_rs1)begin
        case(i_MEMWB_wbsrc)
            WB_alu: o_forward_rs1 = i_MEMWB_alu_result;
            WB_imm: o_forward_rs1 = i_MEMWB_imm;
            WB_PCA4: o_forward_rs1 = i_MEMWB_PCA4;
            WB_mem: o_forward_rs1 = i_MEMWB_mem_rsp;
            WB_csr: o_forward_rs1 = i_MEMWB_csr_old_data;
            default: o_forward_rs1 = i_IDEX_rs1_data;
        endcase
    end else
        o_forward_rs1 = i_IDEX_rs1_data;
end

always_comb begin
    if(i_EXMEM_reg_valid && i_EXMEM_reg_we && i_EXMEM_rd != 0 && i_EXMEM_rd == i_IDEX_rs2)begin
        case(i_EXMEM_wbsrc)
            WB_alu: o_forward_rs2 = i_EXMEM_alu_result;
            WB_imm: o_forward_rs2 = i_EXMEM_imm;
            WB_PCA4: o_forward_rs2 = i_EXMEM_PCA4;
            WB_csr: o_forward_rs2 = i_EXMEM_csr_old_data;
            default: o_forward_rs2 = i_IDEX_rs2_data;
        endcase
    end else if(i_MEMWB_reg_valid && i_MEMWB_reg_we && i_MEMWB_rd != 0 && i_MEMWB_rd == i_IDEX_rs2)begin
        case(i_MEMWB_wbsrc)
            WB_alu: o_forward_rs2 = i_MEMWB_alu_result;
            WB_imm: o_forward_rs2 = i_MEMWB_imm;
            WB_PCA4: o_forward_rs2 = i_MEMWB_PCA4;
            WB_mem: o_forward_rs2 = i_MEMWB_mem_rsp;
            WB_csr: o_forward_rs2 = i_MEMWB_csr_old_data;
            default: o_forward_rs2 = i_IDEX_rs2_data;
        endcase
    end else
        o_forward_rs2 = i_IDEX_rs2_data;
end


endmodule