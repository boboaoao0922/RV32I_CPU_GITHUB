import RISC_V_PKG::*;
module BchCmp (
    input logic [31:0] rs1,
    input logic [31:0] rs2,
    input logic [31:0] immidate,
    input Branch_sel branch_sel,
    input logic [31:0] PC_in,
    output logic [31:0] PC_out,
    output logic taken
);

always_comb begin
    case(branch_sel)
        B_EQ : taken = rs1 == rs2;
        B_BNE: taken = rs1 != rs2;
        B_BLT: taken = $signed(rs1) < $signed(rs2);
        B_BGE: taken = $signed(rs1) >= $signed(rs2);
        B_BLTU: taken = rs1 < rs2;
        B_BGEU: taken = rs1 >= rs2;
        default: taken = 1'b0;
    endcase
end

assign PC_out = PC_in + immidate;

endmodule