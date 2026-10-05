module NDFF #(
    parameter N = 2,
    parameter DATA_WIDTH = 6   
)(
    input clk,
    input rst_n,
    input  [DATA_WIDTH-1:0] D,
    output [DATA_WIDTH-1:0] Q   
);

logic [DATA_WIDTH -1:0] tmp_reg [N-1:0];

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (int i = 0; i < N; i++)
            tmp_reg[i] <= '0;
    end
    else begin
        for (int i = 0; i < N; i++) begin
            if (i == 0)
                tmp_reg[i] <= D;
            else
                tmp_reg[i] <= tmp_reg[i-1];
        end
    end
end

assign Q = tmp_reg[N-1];

endmodule