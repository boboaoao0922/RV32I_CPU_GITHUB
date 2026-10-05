import RISC_V_PKG::*;
module Decoder (
    input logic [31:0] inst,
    output Opcode opcode,
    output ImmSel immsel,
    output ALU_Operation alu_operation,
    output LoadStore_func3 loadstore_func3,
    output Mem_acc_type mem_acc_type, // memory write enable
    output Mem_acc_size mem_acc_size,
    output logic reg_we, //register file write enable
    output Branch_sel branch_sel,
    output Inst_type inst_type, // for debug
    output logic [4:0] rs1,
    output logic [4:0] rs2,
    output logic [4:0] rd,
    output WB_source wb_source,
    output ALU_source alu_source1,
    output ALU_source alu_source2,
    output BJ_type bj_type,
    output Use_rs use_rs,
    output logic illegal,
    output logic exc_valid,
    output Mcause mcause,
    output logic [31:0] mtval,
    output logic flag_csr,
    output logic csr_we,
    output logic [31:0] zimm,
    output logic [2:0] csr_func3,
    output Csr_sel csr_rd,
    output logic flag_mret,
    output logic csr_use_rs
);

logic [2:0] func3;
logic [6:0] func7;
logic csr_addr_err;

//assign opcode = inst[6:0];
assign func3 = inst[14:12];
assign func7 = inst[31:25];

always_comb begin
    case(inst[6:0])
        7'b0000011: opcode = OP_LOAD;
        7'b0001111: opcode = OP_FENCE;
        7'b0010011: opcode = OP_OP_IMM;
        7'b0010111: opcode = OP_AUIPC;
        7'b0100011: opcode = OP_STORE;
        7'b0110011: opcode = OP_OP;
        7'b0110111: opcode = OP_LUI;
        7'b1100011: opcode = OP_BRANCH;
        7'b1100111: opcode = OP_JALR;
        7'b1101111: opcode = OP_JAL;
        7'b1110011: opcode = OP_SYSTEM;
        default: opcode = OP_ERR;
    endcase
end

always_comb begin
    case(func3)
        3'b000: loadstore_func3 = LS_B;
        3'b001: loadstore_func3 = LS_H;
        3'b010: loadstore_func3 = LS_W;
        3'b100: loadstore_func3 = LS_BU;
        3'b101: loadstore_func3 = LS_HU;
        default: loadstore_func3 = LS_ERR;
    endcase
end


always_comb begin
    case(opcode)
        OP_LOAD: immsel = Immsel_I;
        OP_OP_IMM: immsel = Immsel_I;
        OP_AUIPC: immsel = Immsel_U;
        OP_STORE: immsel = Immsel_S;
        OP_LUI: immsel = Immsel_U;
        OP_BRANCH: immsel = Immsel_B;
        OP_JALR: immsel = Immsel_I;
        OP_JAL: immsel = Immsel_J;
        default: immsel = Immsel_None;
    endcase
end

always_comb begin
    case(opcode)
        OP_LOAD: begin
            if(func3 == 3'b000 || func3 == 3'b001 || func3 == 3'b010 || func3 == 3'b100 || func3 == 3'b101)
                alu_operation = ALU_ADD; //LB, LH, LW, LBU, LHU
            else
                alu_operation = ALU_ERR;
        end
        OP_OP_IMM: begin
            case(func3)
                3'b000: alu_operation = ALU_ADD;  //addi
                3'b001: begin
                    if(func7 == 7'd0)
                        alu_operation = ALU_SLL;  //SLLI
                    else
                        alu_operation = ALU_ERR;
                end
                3'b010: alu_operation = ALU_SLT;  //SLTI
                3'b011: alu_operation = ALU_SLTU; //SLTIU
                3'b100: alu_operation = ALU_XOR;  //XORI
                3'b101: begin
                    if(func7 == 7'b0100000)
                        alu_operation = ALU_SRA;  //SRAI
                    else if(func7 == 7'b0000000)
                        alu_operation = ALU_SRL;  //SRLI
                    else
                        alu_operation = ALU_ERR; //ERROR
                end
                3'b110: alu_operation = ALU_OR;   //ORI
                3'b111: alu_operation = ALU_AND;  //ANDI
                default: alu_operation = ALU_ERR;
            endcase
        end
        OP_AUIPC: alu_operation = ALU_ADD;  //AUIPC
        OP_STORE:begin
            if(func3 == 3'b000 || func3 == 3'b001 || func3 == 3'b010)
                alu_operation = ALU_ADD;  //SB, SH, SW
            else
                alu_operation = ALU_ERR;
        end
        OP_OP: begin
            case(func3)
                3'b000: begin
                    if(func7 == 7'b0100000)
                        alu_operation = ALU_SUB; //SUB
                    else if(func7 == 7'b0000000)
                        alu_operation = ALU_ADD; //ADD
                    else
                        alu_operation = ALU_ERR; //ERROR
                end
                3'b001: begin
                    if(func7 == 7'd0)
                        alu_operation = ALU_SLL;  //SLL
                    else
                        alu_operation = ALU_ERR;
                end
                3'b010: begin
                    if(func7 == 7'd0)
                        alu_operation = ALU_SLT;  //SLT
                    else
                        alu_operation = ALU_ERR;
                end
                3'b011: begin
                    if(func7 == 7'd0)
                        alu_operation = ALU_SLTU;  //SLTU
                    else
                        alu_operation = ALU_ERR;
                end
                3'b100: begin 
                    if(func7 == 7'd0)
                        alu_operation = ALU_XOR;  //XOR
                    else
                        alu_operation = ALU_ERR;
                end
                3'b101: begin
                    if(func7 == 7'b0100000)
                        alu_operation = ALU_SRA;  //SRA
                    else if(func7 == 7'b0000000)
                        alu_operation = ALU_SRL;  //SRL
                    else
                        alu_operation = ALU_ERR; //ERROR
                end
                3'b110: begin 
                    if(func7 == 7'd0)
                        alu_operation = ALU_OR;   //OR
                    else
                        alu_operation = ALU_ERR;
                end
                3'b111: begin 
                    if(func7 == 7'd0)
                        alu_operation = ALU_AND;  //AND
                    else
                        alu_operation = ALU_ERR;
                end
                default: alu_operation = ALU_ERR;
            endcase
        end
        OP_LUI: alu_operation = ALU_ADD;  //LUI, do not use ALU
        OP_BRANCH: begin
            if(func3 == 3'b000 || func3 == 3'b001 || func3 == 3'b100 || func3 == 3'b101 || func3 == 3'b110 || func3 == 3'b111)
                alu_operation = ALU_ADD; //Branch,BEQ/BNE/BLT/BGE/BLTU/BGEU, do not use ALU 
            else
                alu_operation = ALU_ERR;
        end
        OP_JALR: begin
            if(func3 == 3'b000)
                alu_operation = ALU_ADD; //JALR, do not use ALU 
            else
                alu_operation = ALU_ERR;
        end
        OP_JAL: alu_operation = ALU_ADD; //JAL, do not use ALU 
        OP_SYSTEM:begin
            //if(func3 == 3'b000 && (inst[31:20] == 12'd0 || inst[31:20] == 12'd1 ) && rs1 == 0 && rd == 0)
                alu_operation = ALU_ADD; //system, do not use ALU
            //else
            //    alu_operation = ALU_ERR;
        end 
        OP_FENCE: begin
            if(func3 == 3'b000)
                alu_operation = ALU_ADD; //fence, do not use ALU
            else
                alu_operation = ALU_ERR;
        end 
        default : alu_operation = ALU_ERR;  // ERROR
    endcase
end


//assign mem_we = (opcode == OP_STORE && inst_type != Inst_ERR);
always_comb begin
    if(illegal)
        mem_acc_type = Mem_none;
    else begin
        if(opcode == OP_LOAD)
            mem_acc_type = Mem_load;
        else if(opcode == OP_STORE)
            mem_acc_type = Mem_store;
        else
            mem_acc_type = Mem_none;
    end
end


always_comb begin
    if ((opcode == OP_OP || 
    opcode == OP_OP_IMM || 
    opcode == OP_LOAD || 
    opcode == OP_JAL || 
    opcode == OP_JALR || 
    opcode == OP_LUI ||
    opcode == OP_AUIPC || flag_csr) && !illegal)
        reg_we = 1;
    else
        reg_we = 0;
end

always_comb begin
    if(illegal) begin
        branch_sel = B_ERR;
    end else begin
        case(func3)
            B_EQ: branch_sel = B_EQ;
            B_BNE: branch_sel = B_BNE;
            B_BLT: branch_sel = B_BLT;
            B_BGE: branch_sel = B_BGE;
            B_BLTU: branch_sel = B_BLTU;
            B_BGEU: branch_sel = B_BGEU;
            default: branch_sel = B_ERR;
        endcase
    end
end

always_comb begin
    case(opcode)
        OP_LOAD: begin //LB, LH, LW, LBU, LHU
            case(func3)
                3'b000: inst_type = Inst_LB;
                3'b001: inst_type = Inst_LH;
                3'b010: inst_type = Inst_LW;
                3'b100: inst_type = Inst_LBU;
                3'b101: inst_type = Inst_LHU;
                default: inst_type = Inst_ERR;
            endcase
        end
        OP_OP_IMM: begin
            case(func3)
                3'b000: inst_type = Inst_ADDI;  //addi
                3'b001: begin 
                    if (func7 == 7'd0)
                        inst_type = Inst_SLLI;  //SLLI
                    else
                        inst_type = Inst_ERR;
                end
                3'b010: inst_type = Inst_SLTI;  //SLTI
                3'b011: inst_type = Inst_SLTIU;
                3'b100: inst_type = Inst_XORI;  //XORI
                3'b101: begin
                    if(func7 == 7'b0100000)
                        inst_type = Inst_SRAI;  //SRAI
                    else if(func7 == 7'b0000000)
                        inst_type = Inst_SRLI;  //SRLI
                    else
                        inst_type = Inst_ERR; //ERROR
                end
                3'b110: inst_type = Inst_ORI;   //ORI
                3'b111: inst_type = Inst_ANDI;  //ANDI
                default : inst_type = Inst_ERR;
            endcase
        end
        OP_AUIPC: inst_type = Inst_AUIPC;  //AUIPC
        OP_STORE: begin  //SB, SH, SW
            case(func3)
                3'b000: inst_type = Inst_SB;
                3'b001: inst_type = Inst_SH;
                3'b010: inst_type = Inst_SW;
                default: inst_type = Inst_ERR;
            endcase
        end
        OP_OP: begin
            case(func3)
                3'b000: begin
                    if(func7 == 7'b0100000)
                        inst_type = Inst_SUB; //SUB
                    else if(func7 == 7'b0000000)
                        inst_type = Inst_ADD; //ADD
                    else
                        inst_type = Inst_ERR; //ERROR
                end
                3'b001: begin 
                    if(func7 == 7'd0)
                        inst_type = Inst_SLL;  //SLL
                    else
                        inst_type = Inst_ERR;
                end
                3'b010: begin 
                    if(func7 == 7'd0)
                        inst_type = Inst_SLT;  //SLT
                    else
                        inst_type = Inst_ERR;
                end 
                3'b011: begin
                    if(func7 == 7'd0)
                        inst_type = Inst_SLTU;
                    else
                        inst_type = Inst_ERR;
                end
                3'b100: begin 
                    if(func7 == 7'd0)
                        inst_type = Inst_XOR;  //XOR
                    else
                        inst_type = Inst_ERR;
                end
                3'b101: begin
                    if(func7 == 7'b0100000)
                        inst_type = Inst_SRA;  //SRA
                    else if(func7 == 7'b0000000)
                        inst_type = Inst_SRL;  //SRL
                    else
                        inst_type = Inst_ERR; //ERROR
                end
                3'b110: begin
                    if(func7 == 7'd0)
                        inst_type = Inst_OR;   //OR
                    else
                        inst_type = Inst_ERR;
                end
                3'b111: begin
                    if(func7 == 7'd0)
                        inst_type = Inst_AND;  //AND
                    else
                        inst_type = Inst_ERR;
                end
                default : inst_type = Inst_ERR;
            endcase
        end
        OP_LUI: inst_type = Inst_LUI;  //LUI, do not use ALU
        OP_BRANCH: begin //Branch,BEQ/BNE/BLT/BGE/BLTU/BGEU, do not use ALU
            case(func3)
                3'b000: inst_type = Inst_BEQ;
                3'b001: inst_type = Inst_BNE;
                3'b100: inst_type = Inst_BLT;
                3'b101: inst_type = Inst_BGE;
                3'b110: inst_type = Inst_BLTU;
                3'b111: inst_type = Inst_BGEU;
                default: inst_type = Inst_ERR; 
            endcase
        end 
        OP_JALR: begin
            if(func3 == 3'b000)
                inst_type = Inst_JALR; //JALR, do not use ALU
            else
                inst_type = Inst_ERR; 
        end
        OP_JAL: inst_type = Inst_JAL; //JAL, do not use ALU 
        OP_SYSTEM: begin //system, do not use ALU
            case(func3)
                3'b000:begin
                    if(rs1 == 0 && rd == 0)begin
                        case(inst[31:20])
                            12'h000: inst_type = Inst_ECALL;
                            12'h001: inst_type = Inst_EBREAK;
                            12'h302: inst_type = Inst_MRET;
                            default: inst_type = Inst_ERR;
                        endcase
                    end else 
                        inst_type = Inst_ERR;
                end
                3'b001: if(csr_addr_err) inst_type = Inst_ERR; else inst_type = Inst_CSRRW;
                3'b010: if(csr_addr_err) inst_type = Inst_ERR; else inst_type = Inst_CSRRS;
                3'b011: if(csr_addr_err) inst_type = Inst_ERR; else inst_type = Inst_CSRRC;
                3'b101: if(csr_addr_err) inst_type = Inst_ERR; else inst_type = Inst_CSRRWI;
                3'b110: if(csr_addr_err) inst_type = Inst_ERR; else inst_type = Inst_CSRRSI;
                3'b111: if(csr_addr_err) inst_type = Inst_ERR; else inst_type = Inst_CSRRCI;
                default: inst_type = Inst_ERR;
            endcase
        end 
        OP_FENCE: begin
            if(func3 == 3'd0) 
                inst_type = Inst_FENCE; //fence, do not use ALU
            else
                inst_type = Inst_ERR;
        end 
        default : inst_type = Inst_ERR;  // ERROR
    endcase
end

assign illegal = inst_type == Inst_ERR;

assign rs1 = inst[19:15];
assign rs2 = inst[24:20];
assign rd = inst[11:7];


always_comb begin
    case(opcode)
        OP_LOAD: wb_source = WB_mem;
        OP_OP_IMM: wb_source = WB_alu;
        OP_OP: wb_source = WB_alu;
        OP_AUIPC: wb_source = WB_alu;
        OP_LUI: wb_source = WB_imm;
        OP_JAL: wb_source = WB_PCA4;
        OP_JALR: wb_source = WB_PCA4;
        OP_SYSTEM: if(flag_csr) wb_source = WB_csr; else wb_source = WB_alu;
        default: wb_source = WB_alu;
    endcase
end

always_comb begin
    if(opcode == OP_AUIPC)
        alu_source1 = ALUsrc_PC;
    else    
        alu_source1 = ALUsrc_rs1;
end

always_comb begin
    case(opcode)
        OP_OP: alu_source2 = ALUsrc_rs2;
        OP_OP_IMM : alu_source2 = ALUsrc_imm;
        OP_LOAD: alu_source2 = ALUsrc_imm;
        OP_STORE: alu_source2 = ALUsrc_imm;
        OP_AUIPC: alu_source2 = ALUsrc_imm;
        OP_JAL: alu_source2 = ALUsrc_4;
        OP_JALR: alu_source2 = ALUsrc_4;
        default: alu_source2 = ALUsrc_0;
    endcase
end

always_comb begin
    if (illegal)
        bj_type = BJ_none;
    else begin
        case(opcode)
            OP_BRANCH : bj_type = BJ_branch;
            OP_JAL: bj_type = BJ_jal;
            OP_JALR: bj_type = BJ_jalr;
            default: bj_type = BJ_none;
        endcase
    end
end

always_comb begin
    if(illegal)
        use_rs = Use_rs_none;
    else begin
        case(opcode)
            OP_OP : use_rs = Use_rs_all;
            OP_OP_IMM: use_rs = Use_rs_rs1;
            OP_LOAD: use_rs = Use_rs_rs1;
            OP_STORE: use_rs = Use_rs_all;
            OP_BRANCH : use_rs = Use_rs_all;
            OP_JAL: use_rs = Use_rs_none;
            OP_JALR: use_rs = Use_rs_rs1;
            default: use_rs = Use_rs_none;
        endcase
    end
end

always_comb begin
    if(illegal)
        mem_acc_size = Mem_acc_size_none;
    else if (opcode == OP_LOAD || opcode == OP_STORE) begin
        case(func3)
            3'b000: mem_acc_size = Mem_acc_size_B;
            3'b001: mem_acc_size = Mem_acc_size_H;
            3'b010: mem_acc_size = Mem_acc_size_W;
            3'b100: mem_acc_size = Mem_acc_size_B;
            3'b101: mem_acc_size = Mem_acc_size_H; 
            default: mem_acc_size = Mem_acc_size_none;
        endcase
    end else 
        mem_acc_size = Mem_acc_size_none;
end

always_comb begin
    if(inst[31:20] != 12'h300 &&  
        inst[31:20] != 12'h304 && 
        inst[31:20] != 12'h305 &&
        inst[31:20] != 12'h341 &&
        inst[31:20] != 12'h342 &&
        inst[31:20] != 12'h343 &&  
        inst[31:20] != 12'h344   
        )
        csr_addr_err = 1;
    else
        csr_addr_err = 0;
end

always_comb begin
    case(inst_type)
        Inst_ECALL: mcause = Mcause_ECALL;
        Inst_EBREAK: mcause = Mcause_EBREAK;
        Inst_ERR: mcause = Mcause_INST_ILLEGAL;
        default: mcause = Mcause_INST_MISALIGNED;
    endcase
end

always_comb begin
    if(illegal || inst_type == Inst_ECALL || inst_type == Inst_EBREAK)
        exc_valid = 1;
    else
        exc_valid = 0;
end

assign mtval = illegal ? inst : 0;

always_comb begin
    if(
        inst_type == Inst_CSRRW ||
        inst_type == Inst_CSRRS ||
        inst_type == Inst_CSRRC ||
        inst_type == Inst_CSRRWI ||
        inst_type == Inst_CSRRSI ||
        inst_type == Inst_CSRRCI
    )
        flag_csr = 1;
    else
        flag_csr = 0;
end

always_comb begin
    if(flag_csr)begin
        if(((inst_type == Inst_CSRRS || inst_type == Inst_CSRRC) && rs1 == 0) ||
            ((inst_type == Inst_CSRRSI || inst_type == Inst_CSRRCI) && zimm == 0) )
            csr_we = 0;
        else
            csr_we = 1;
    end else
        csr_we = 0;
    
end

assign flag_mret = inst_type == Inst_MRET;

assign zimm = {27'd0,inst[19:15]};
assign csr_func3 = func3;

always_comb begin
    case(inst[31:20])
        12'h300: csr_rd = Csr_mstatus;
        12'h304: csr_rd = Csr_mie;
        12'h305: csr_rd = Csr_mtvec;
        12'h341: csr_rd = Csr_mepc;
        12'h342: csr_rd = Csr_mcause;
        12'h343: csr_rd = Csr_mtval;
        12'h344: csr_rd = Csr_mip;
        default: csr_rd = Csr_mip;
    endcase
end

assign csr_use_rs = (inst_type == Inst_CSRRC || inst_type == Inst_CSRRW || inst_type == Inst_CSRRS);

endmodule