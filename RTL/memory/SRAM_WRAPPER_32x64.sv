`ifndef SRAM_WRAPPER_32X64_SV
`define SRAM_WRAPPER_32X64_SV

// Portable 32-entry x 64-bit dual-clock 1R1W SRAM model.
// WEB and REB are active low. Read data is registered on rclk.
module SRAM_WRAPPER_32x64 (
    input  logic        wclk,
    input  logic        WEB,
    input  logic [4:0]  w_addr,
    input  logic [63:0] w_data,

    input  logic        rclk,
    input  logic        REB,
    input  logic [4:0]  r_addr,
    output logic [63:0] r_data
);

    logic [63:0] mem [0:31];

    always_ff @(posedge wclk) begin
        if (!WEB) begin
            mem[w_addr] <= w_data;
        end
    end

    always_ff @(posedge rclk) begin
        if (!REB) begin
            r_data <= mem[r_addr];
        end
    end

endmodule

`endif
