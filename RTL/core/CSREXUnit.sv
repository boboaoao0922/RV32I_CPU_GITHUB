import RISC_V_PKG::*;
module CSREXUnit(
    input logic [31:0] rs1,
    input logic [31:0] csr_old_data,
    input logic [31:0] zimm,
    input logic [2:0] csr_func3,
    input logic flag_csr,
    //output logic csr_we,
    output logic [31:0] csr_result
);

//assign csr_we = flag_csr;
always_comb begin
    case(csr_func3)
        3'b001: csr_result = rs1;
        3'b010: csr_result = csr_old_data | rs1;
        3'b011: csr_result = csr_old_data & ~rs1;
        3'b101: csr_result = zimm;
        3'b110: csr_result = csr_old_data | zimm;
        3'b111: csr_result = csr_old_data & ~zimm;
        default: csr_result = 0;
    endcase
end

endmodule