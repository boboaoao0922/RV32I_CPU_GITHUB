import RISC_V_PKG::*;
module HDUnit (
    input logic [4:0] i_decoder_rs1,
    input logic [4:0] i_decoder_rs2,
    input Use_rs i_decoder_use_rs,
    input logic [4:0] i_IDEX_rd,
    input logic [4:0] i_EXMEM_rd,
    input logic [4:0] i_MEMWB_rd,
    input Mem_acc_type i_IDEX_mem_acc_type,
    input logic i_MEMWB_reg_valid,
    input logic i_EXMEM_reg_valid,
    input logic i_IDEX_reg_valid,
    input logic i_IFID_reg_valid,

    input logic i_decoder_flag_csr,
    input logic i_decoder_csr_use_rs,
    input Csr_sel i_decoder_csr_rd,
    
    input logic i_IDEX_csr_we,
    input logic i_IDEX_reg_we,
    input Csr_sel i_IDEX_csr_rd,
    input logic i_EXMEM_csr_we,
    input logic i_EXMEM_reg_we,
    input Csr_sel i_EXMEM_csr_rd,
    input logic i_MEMWB_csr_we,
    input logic i_MEMWB_reg_we,
    input Csr_sel i_MEMWB_csr_rd,


    output logic o_load_use_stall,
    output logic o_csr_use_stall
);

logic rs1_stall, csr_rd_stall;


always_comb begin
    if(i_IFID_reg_valid && i_IDEX_reg_valid && i_IDEX_mem_acc_type == Mem_load)begin
        case(i_decoder_use_rs)
            Use_rs_none: o_load_use_stall = 0;
            Use_rs_rs1: begin
                if(i_IDEX_rd != 0 && i_IDEX_rd == i_decoder_rs1)
                    o_load_use_stall = 1;
                else
                    o_load_use_stall = 0;
            end
            Use_rs_rs2:begin
                if(i_IDEX_rd != 0 && i_IDEX_rd == i_decoder_rs2)
                    o_load_use_stall = 1;
                else
                    o_load_use_stall = 0;
            end
            Use_rs_all:begin
                if(i_IDEX_rd != 0 && (i_IDEX_rd == i_decoder_rs2 || i_IDEX_rd == i_decoder_rs1))
                    o_load_use_stall = 1;
                else
                    o_load_use_stall = 0;
            end
            default: o_load_use_stall = 0;
        endcase
    end else
        o_load_use_stall = 0;
end

always_comb begin
    if(i_IFID_reg_valid && i_decoder_flag_csr && i_decoder_csr_use_rs && i_decoder_rs1 != 0 && 
        ((i_decoder_rs1 == i_IDEX_rd && i_IDEX_reg_we && i_IDEX_reg_valid) ||
        (i_decoder_rs1 == i_EXMEM_rd && i_EXMEM_reg_we && i_EXMEM_reg_valid) ||
        (i_decoder_rs1 == i_MEMWB_rd && i_MEMWB_reg_we && i_MEMWB_reg_valid)))begin
        rs1_stall = 1;
    end else
        rs1_stall = 0;
end

always_comb begin
    if(i_IFID_reg_valid && i_decoder_flag_csr && 
    ((i_decoder_csr_rd == i_IDEX_csr_rd && i_IDEX_csr_we && i_IDEX_reg_valid) ||
     (i_decoder_csr_rd == i_EXMEM_csr_rd && i_EXMEM_csr_we && i_EXMEM_reg_valid) ||
     (i_decoder_csr_rd == i_MEMWB_csr_rd && i_MEMWB_csr_we && i_MEMWB_reg_valid)))
        csr_rd_stall = 1;
    else
        csr_rd_stall = 0;
end

assign o_csr_use_stall = rs1_stall || csr_rd_stall;

endmodule