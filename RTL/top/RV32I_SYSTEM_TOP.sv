import RISC_V_PKG::*;

// Synthesizable system integration boundary.
//
// Clock domains:
//   cpu_clk : CPU, I-cache, D-cache, AXI arbiter, bridge upstream side
//   mem_clk : bridge downstream side and the external AXI memory subsystem
//
// rst_n is an asynchronous chip-level reset.  Each clock domain receives an
// async-assert/sync-deassert reset generated locally below.
module RV32I_SYSTEM_TOP #(
    parameter I_CACHE_SRAM_IDLE_GATING = 1'b1,
    parameter D_CACHE_SRAM_IDLE_GATING = 1'b1
) (
    input  logic       cpu_clk,
    input  logic       mem_clk,
    input  logic       rst_n,
    input  logic       MEIP,

    output logic       cpu_rst_n,
    output logic       mem_rst_n,

    output logic       commit_fire,
    output logic [31:0] commit_PC,
    output logic [31:0] commit_inst,
    output logic [4:0]  commit_rd,
    output logic       commit_we,
    output logic [31:0] commit_wb_data,
    output Commit_type commit_type,

    // AXI master port in the mem_clk domain.  The DRAM/controller is outside
    // this synthesis top and consumes this interface as an AXI slave.
    INF_AXI.PATTERN mem_axi
);

// CPU <-> I-cache
logic        cpu_req_ready_I_cache;
logic        cpu_rsp_valid_I_cache;
logic [31:0] cpu_rsp_data_I_cache;
logic        cpu_acc_fault_I_cache;
logic        cpu_req_valid_I_cache;
logic [31:0] cpu_req_addr_I_cache;
logic        i_cache_b_err_bit;

// CPU <-> D-cache
logic        cpu_req_ready_D_cache;
logic        cpu_rsp_load_ack_D_cache;
logic [31:0] cpu_rsp_data_D_cache;
logic        cpu_rsp_flush_ack_D_cache;
logic        cpu_rsp_store_ack_D_cache;
logic        cpu_acc_fault_D_cache;
logic        b_err_bit_D_cache;
logic        cpu_req_LS_valid_D_cache;
logic [31:0] cpu_req_addr_D_cache;
logic [31:0] cpu_wdata_D_cache;
logic        cpu_we_D_cache;
logic [3:0]  cpu_wstrb_D_cache;
logic        cpu_req_flush_D_cache;

// AXI links in the CPU clock domain.
INF_AXI i_axi();
INF_AXI d_axi();
INF_AXI arb_axi();
logic MEIP_sync;

RSTSYNC u_cpu_reset_sync (
    .clk        (cpu_clk),
    .rst_n      (rst_n),
    .rst_n_sync (cpu_rst_n)
);

RSTSYNC u_mem_reset_sync (
    .clk        (mem_clk),
    .rst_n      (rst_n),
    .rst_n_sync (mem_rst_n)
);

// MEIP is an external level interrupt; synchronize it into the CPU domain.
NDFF #(.N(2), .DATA_WIDTH(1)) u_MEIP_sync (
    .clk   (cpu_clk),
    .rst_n (cpu_rst_n),
    .D     (MEIP),
    .Q     (MEIP_sync)
);

CPU u_cpu (
    .clk                              (cpu_clk),
    .rst_n                            (cpu_rst_n),
    .MEIP                             (MEIP_sync),
    .commit_fire                      (commit_fire),
    .commit_PC                        (commit_PC),
    .commit_inst                      (commit_inst),
    .commit_rd                        (commit_rd),
    .commit_we                        (commit_we),
    .commit_wb_data                   (commit_wb_data),
    .commit_type                      (commit_type),
    .i_cpu_req_ready_I_cache          (cpu_req_ready_I_cache),
    .i_cpu_rsp_valid_I_cache          (cpu_rsp_valid_I_cache),
    .i_cpu_acc_fault_I_cache          (cpu_acc_fault_I_cache),
    .i_cpu_rsp_data_I_cache           (cpu_rsp_data_I_cache),
    .o_cpu_req_valid_I_cache          (cpu_req_valid_I_cache),
    .o_cpu_req_addr_I_cache           (cpu_req_addr_I_cache),
    .i_cpu_req_ready_D_cache          (cpu_req_ready_D_cache),
    .i_cpu_rsp_load_ack_D_cache       (cpu_rsp_load_ack_D_cache),
    .i_cpu_rsp_data_D_cache           (cpu_rsp_data_D_cache),
    .i_cpu_rsp_flush_ack_D_cache      (cpu_rsp_flush_ack_D_cache),
    .i_cpu_rsp_store_ack_D_cache      (cpu_rsp_store_ack_D_cache),
    .i_cpu_acc_fault_D_cache          (cpu_acc_fault_D_cache),
    .i_b_err_bit_D_cache              (b_err_bit_D_cache),
    .o_cpu_req_LS_valid_D_cache       (cpu_req_LS_valid_D_cache),
    .o_cpu_req_addr_D_cache           (cpu_req_addr_D_cache),
    .o_cpu_wdata_D_cache              (cpu_wdata_D_cache),
    .o_cpu_we_D_cache                 (cpu_we_D_cache),
    .o_cpu_wstrb_D_cache              (cpu_wstrb_D_cache),
    .o_cpu_req_flush_D_cache          (cpu_req_flush_D_cache)
);

CACHE_INST #(
    .SRAM_IDLE_GATING (I_CACHE_SRAM_IDLE_GATING)
) u_i_cache (
    .clk            (cpu_clk),
    .rst_n          (cpu_rst_n),
    .cpu_req_valid  (cpu_req_valid_I_cache),
    .cpu_req_addr   (cpu_req_addr_I_cache),
    .cpu_req_ready  (cpu_req_ready_I_cache),
    .cpu_rsp_valid  (cpu_rsp_valid_I_cache),
    .cpu_rsp_data   (cpu_rsp_data_I_cache),
    .cpu_acc_fault  (cpu_acc_fault_I_cache),
    .b_err_bit      (i_cache_b_err_bit),
    .inf_axi        (i_axi)
);

CACHE_DATA #(
    .SRAM_IDLE_GATING (D_CACHE_SRAM_IDLE_GATING)
) u_d_cache (
    .clk               (cpu_clk),
    .rst_n             (cpu_rst_n),
    .cpu_req_LS_valid  (cpu_req_LS_valid_D_cache),
    .cpu_req_addr      (cpu_req_addr_D_cache),
    .cpu_wdata         (cpu_wdata_D_cache),
    .cpu_we            (cpu_we_D_cache),
    .cpu_wstrb         (cpu_wstrb_D_cache),
    .cpu_req_flush     (cpu_req_flush_D_cache),
    .cpu_req_ready     (cpu_req_ready_D_cache),
    .cpu_rsp_load_ack  (cpu_rsp_load_ack_D_cache),
    .cpu_rsp_data      (cpu_rsp_data_D_cache),
    .cpu_rsp_flush_ack (cpu_rsp_flush_ack_D_cache),
    .cpu_rsp_store_ack (cpu_rsp_store_ack_D_cache),
    .cpu_acc_fault     (cpu_acc_fault_D_cache),
    .b_err_bit         (b_err_bit_D_cache),
    .inf_axi           (d_axi)
);

Arbiter u_arbiter (
    .clk             (cpu_clk),
    .rst_n           (cpu_rst_n),
    .inf_axi_master0 (i_axi),
    .inf_axi_master1 (d_axi),
    .inf_axi_MEM     (arb_axi)
);

AXI4_CDC_BRIDGE u_axi_cdc_bridge (
    .master_clk   (cpu_clk),
    .master_rst_n (cpu_rst_n),
    .slave_clk    (mem_clk),
    .slave_rst_n  (mem_rst_n),
    .inf_axi_master (arb_axi),
    .inf_axi_slave  (mem_axi)
);

endmodule
