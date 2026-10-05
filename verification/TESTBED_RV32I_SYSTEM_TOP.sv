`timescale 1ns/1ps

// RTL and verification sources are compiled in dependency order by the VCS
// filelists under scripts/. The non-IRQ and IRQ filelists each select exactly
// one PATTERN implementation.

module TESTBENCH;

parameter CPU_CYCLE = 1.0;
parameter MEM_CYCLE = 1.4;
// Each run script executes simv from a case-specific result directory and
// stages that case's image there as dram.dat.
parameter DRAM_ptr  = "dram.dat";

logic cpu_clk;
logic mem_clk;
logic rst_n;
logic cpu_rst_n;
logic mem_rst_n;
logic MEIP;

logic        commit_fire;
logic [31:0] commit_PC;
logic [31:0] commit_inst;
logic [4:0]  commit_rd;
logic        commit_we;
logic [31:0] commit_wb_data;
RISC_V_PKG::Commit_type commit_type;

INF_AXI mem_axi();

PATTERN pattern (
    .clk            (cpu_clk),
    .rst_n          (rst_n),
    .commit_fire    (commit_fire),
    .commit_PC      (commit_PC),
    .commit_inst    (commit_inst),
    .commit_rd      (commit_rd),
    .commit_we      (commit_we),
    .commit_wb_data (commit_wb_data),
    .commit_type    (commit_type),
    .MEIP           (MEIP)
);

RV32I_SYSTEM_TOP dut (
    .cpu_clk        (cpu_clk),
    .mem_clk        (mem_clk),
    .rst_n          (rst_n),
    .MEIP           (MEIP),
    .cpu_rst_n      (cpu_rst_n),
    .mem_rst_n      (mem_rst_n),
    .commit_fire    (commit_fire),
    .commit_PC      (commit_PC),
    .commit_inst    (commit_inst),
    .commit_rd      (commit_rd),
    .commit_we      (commit_we),
    .commit_wb_data (commit_wb_data),
    .commit_type    (commit_type),
    .mem_axi        (mem_axi)
);

pseudo_DRAM #(
    .DRAM_ptr (DRAM_ptr)
) shared_dram (
    .clk   (mem_clk),
    .rst_n (mem_rst_n),
    .inf   (mem_axi)
);

CPU_perf_monitor perf_monitor (
    .clk             (cpu_clk),
    .rst_n           (cpu_rst_n),
    .commit_fire     (commit_fire),
    .commit_PC       (commit_PC),
    .fetch_req_valid (dut.cpu_req_valid_I_cache),
    .fetch_req_ready (dut.cpu_req_ready_I_cache),
    .data_req_valid  (dut.cpu_req_LS_valid_D_cache),
    .data_req_ready  (dut.cpu_req_ready_D_cache),
    .ls_stall        (dut.u_cpu.ls_stall),
    .load_use_stall  (dut.u_cpu.hd_load_use_stall),
    .csr_stall       (dut.u_cpu.hd_csr_use_stall),
    .i_arvalid       (dut.i_axi.ARVALID),
    .i_arready       (dut.i_axi.ARREADY),
    .i_rvalid        (dut.i_axi.RVALID),
    .i_rready        (dut.i_axi.RREADY),
    .i_rlast         (dut.i_axi.RLAST),
    .d_arvalid       (dut.d_axi.ARVALID),
    .d_arready       (dut.d_axi.ARREADY),
    .d_rvalid        (dut.d_axi.RVALID),
    .d_rready        (dut.d_axi.RREADY),
    .d_rlast         (dut.d_axi.RLAST),
    .d_awvalid       (dut.d_axi.AWVALID),
    .d_awready       (dut.d_axi.AWREADY),
    .d_wvalid        (dut.d_axi.WVALID),
    .d_wready        (dut.d_axi.WREADY),
    .d_wlast         (dut.d_axi.WLAST),
    .d_bvalid        (dut.d_axi.BVALID),
    .d_bready        (dut.d_axi.BREADY),
    // Keep this cpu_clk monitor on the upstream side of the CDC bridge.
    // Sampling the external mem_clk interface here would make its counters
    // CDC-unsafe and could miss or double-count handshakes.
    .mem_arvalid     (dut.arb_axi.ARVALID),
    .mem_arready     (dut.arb_axi.ARREADY),
    .mem_rvalid      (dut.arb_axi.RVALID),
    .mem_rready      (dut.arb_axi.RREADY),
    .mem_awvalid     (dut.arb_axi.AWVALID),
    .mem_awready     (dut.arb_axi.AWREADY),
    .mem_wvalid      (dut.arb_axi.WVALID),
    .mem_wready      (dut.arb_axi.WREADY),
    .mem_bvalid      (dut.arb_axi.BVALID),
    .mem_bready      (dut.arb_axi.BREADY)
);

initial begin
    cpu_clk = 1'b0;
    #10;
    forever #(CPU_CYCLE / 2.0) cpu_clk = ~cpu_clk;
end

// Phase-offset, asynchronous memory clock exercises the CDC bridge in the
// full-system regression instead of accidentally reducing it to a wire.
initial begin
    mem_clk = 1'b0;
    #0.2;
    forever #(MEM_CYCLE / 2.0) mem_clk = ~mem_clk;
end

initial begin
    #1;
    $display("[SYSTEM] DRAM image: %s", shared_dram.DRAM_ptr);
    $display("[SYSTEM] CPU cycle=%0.2f ns, memory cycle=%0.2f ns",
             CPU_CYCLE, MEM_CYCLE);
end

`ifdef ENABLE_SVA_COVERAGE
CPU_checker checker (
    .clk   (cpu_clk),
    .rst_n (cpu_rst_n)
);

CPU_coverage coverage (
    .clk   (cpu_clk),
    .rst_n (cpu_rst_n)
);

`endif

initial begin
`ifdef FSDB
    $fsdbDumpfile("RV32I_SYSTEM_TOP.fsdb");
    $fsdbDumpvars(0, TESTBENCH, "+all");
    $fsdbDumpMDA();
    $fsdbDumpSVA;
`endif
end

endmodule
