module RegFile (
    input logic clk,
    input logic [4:0] rs1_addr,
    input logic [4:0] rs2_addr,
    input logic [4:0] rd_addr,
    input logic rd_wen,
    input logic [31:0] rd_data,
    output logic [31:0] rs1_data,
    output logic [31:0] rs2_data
);

logic [31:0] regs [1:31];

//assign rs1_data = rs1_addr != 5'd0 ? regs[rs1_addr] : 32'd0;
//assign rs2_data = rs2_addr != 5'd0 ? regs[rs2_addr] : 32'd0;

always_comb begin
    if (rs1_addr == 5'd0)
        rs1_data = 32'd0;
    else if (rs1_addr == rd_addr && rd_wen)
        rs1_data = rd_data;
    else
        rs1_data = regs[rs1_addr];
end

always_comb begin
    if (rs2_addr == 5'd0)
        rs2_data = 32'd0;
    else if (rs2_addr == rd_addr && rd_wen)
        rs2_data = rd_data;
    else
        rs2_data = regs[rs2_addr];
end


always_ff@(posedge clk) begin
    if (rd_wen && rd_addr != 5'd0)
        regs[rd_addr] <= rd_data;
end

endmodule