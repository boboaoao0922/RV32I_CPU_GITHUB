module RSTSYNC(
    input logic clk,
    input logic rst_n,
    (* async_reg = "true" *) output logic rst_n_sync
);

(* async_reg = "true" *) logic tmp;

always_ff@(posedge clk, negedge rst_n)begin
    if(!rst_n)begin
        tmp <= 0;
        rst_n_sync <= 0;
    end else begin
        tmp <= 1;
        rst_n_sync <= tmp;
    end
end

endmodule