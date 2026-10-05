module JumpUnit(
    input logic jump_type, // 0: JAL, 1:JALR
    input [31:0] PC_in,
    input [31:0] rs1,
    input [31:0] imm,
    output [31:0] PC_out,
    output [31:0] Jump_out
);

assign Jump_out = PC_in + 4;
assign PC_out = jump_type ? (rs1 + imm) & 32'hFFFFFFFE : PC_in + imm; 

endmodule