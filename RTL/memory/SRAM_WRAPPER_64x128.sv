`ifndef SRAM_WRAPPER_64X128_SV
`define SRAM_WRAPPER_64X128_SV

// Portable 64-entry x 128-bit synchronous single-port SRAM model.
// cen and wen are active low. byte_mask is active high per byte.
module SRAM_WRAPPER_64x128 (
    input  logic         clk,
    input  logic         cen,
    input  logic         wen,
    input  logic [15:0]  byte_mask,
    input  logic [5:0]   addr,
    input  logic [127:0] wdata,
    output logic [127:0] rdata
);

    logic [127:0] mem [0:63];
    integer byte_idx;

    always_ff @(posedge clk) begin
        if (!cen) begin
            if (!wen) begin
                for (byte_idx = 0; byte_idx < 16; byte_idx = byte_idx + 1) begin
                    if (byte_mask[byte_idx]) begin
                        mem[addr][byte_idx*8 +: 8] <= wdata[byte_idx*8 +: 8];
                    end
                end
            end
            else begin
                rdata <= mem[addr];
            end
        end
    end

endmodule

`endif
