import RISC_V_PKG::*;
module ImmGen(
    input logic [31:0] inst,
    input ImmSel immsel,
    output logic [31:0] imm
);

always_comb begin
    case(immsel)
        Immsel_I : imm = {{20{inst[31]}},inst[31:20]};
        Immsel_S : imm = {{20{inst[31]}},inst[31:25],inst[11:7]};
        Immsel_B : imm = {{19{inst[31]}},inst[31],inst[7],inst[30:25],inst[11:8],1'b0};
        Immsel_U : imm = {inst[31:12],12'd0};
        Immsel_J : imm = {{11{inst[31]}},inst[31],inst[19:12],inst[20],inst[30:21],1'b0};
        Immsel_None : imm = 32'd0;
        default : imm = 32'd0;
    endcase
end

endmodule