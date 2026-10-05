import RISC_V_PKG::*;
module ALU (
    input logic [31:0] operand1,
    input logic [31:0] operand2,
    input ALU_Operation op_sel,
    output logic [31:0] alu_out
);

always_comb begin
    case(op_sel)
        ALU_ADD : alu_out = operand1 + operand2;
        ALU_SUB : alu_out = operand1 - operand2;
        ALU_SLL : alu_out = operand1 << operand2[4:0];
        ALU_SLT : alu_out = $signed(operand1) < $signed(operand2) ? 32'd1 : 32'd0;
        ALU_SLTU : alu_out = operand1 < operand2 ? 32'd1 : 32'd0;
        ALU_XOR : alu_out = operand1 ^ operand2;
        ALU_SRL : alu_out = operand1 >> operand2[4:0];
        ALU_SRA : alu_out = $signed(operand1) >>> operand2[4:0];
        ALU_OR : alu_out = operand1 | operand2;
        ALU_AND : alu_out = operand1 & operand2;
        default : alu_out = 32'd0;
    endcase
end

endmodule