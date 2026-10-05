module CPU_perf_monitor (
    input logic        clk,
    input logic        rst_n,
    input logic        commit_fire,
    input logic [31:0] commit_PC,

    input logic        fetch_req_valid,
    input logic        fetch_req_ready,
    input logic        data_req_valid,
    input logic        data_req_ready,
    input logic        ls_stall,
    input logic        load_use_stall,
    input logic        csr_stall,

    input logic        i_arvalid,
    input logic        i_arready,
    input logic        i_rvalid,
    input logic        i_rready,
    input logic        i_rlast,

    input logic        d_arvalid,
    input logic        d_arready,
    input logic        d_rvalid,
    input logic        d_rready,
    input logic        d_rlast,
    input logic        d_awvalid,
    input logic        d_awready,
    input logic        d_wvalid,
    input logic        d_wready,
    input logic        d_wlast,
    input logic        d_bvalid,
    input logic        d_bready,

    input logic        mem_arvalid,
    input logic        mem_arready,
    input logic        mem_rvalid,
    input logic        mem_rready,
    input logic        mem_awvalid,
    input logic        mem_awready,
    input logic        mem_wvalid,
    input logic        mem_wready,
    input logic        mem_bvalid,
    input logic        mem_bready
);

logic        region_enable;
logic        region_active;
logic        region_seen;
logic        region_complete;
logic [31:0] region_start_PC;
logic [31:0] region_end_PC;

longint unsigned total_cycles;
longint unsigned total_commits;
longint unsigned total_no_commit_cycles;
longint unsigned total_fetch_requests;
longint unsigned total_data_requests;
longint unsigned total_fetch_wait_cycles;
longint unsigned total_data_wait_cycles;
longint unsigned total_ls_stall_cycles;
longint unsigned total_load_use_stall_cycles;
longint unsigned total_csr_stall_cycles;
longint unsigned total_i_misses;
longint unsigned total_i_refills;
longint unsigned total_i_r_beats;
longint unsigned total_d_misses;
longint unsigned total_d_refills;
longint unsigned total_d_r_beats;
longint unsigned total_d_writebacks;
longint unsigned total_d_w_beats;
longint unsigned total_d_b_responses;
longint unsigned total_mem_reads;
longint unsigned total_mem_r_beats;
longint unsigned total_mem_writes;
longint unsigned total_mem_w_beats;
longint unsigned total_mem_b_responses;

longint unsigned region_cycles;
longint unsigned region_commits;
longint unsigned region_no_commit_cycles;
longint unsigned region_fetch_requests;
longint unsigned region_data_requests;
longint unsigned region_fetch_wait_cycles;
longint unsigned region_data_wait_cycles;
longint unsigned region_ls_stall_cycles;
longint unsigned region_load_use_stall_cycles;
longint unsigned region_csr_stall_cycles;
longint unsigned region_i_misses;
longint unsigned region_i_refills;
longint unsigned region_i_r_beats;
longint unsigned region_d_misses;
longint unsigned region_d_refills;
longint unsigned region_d_r_beats;
longint unsigned region_d_writebacks;
longint unsigned region_d_w_beats;
longint unsigned region_d_b_responses;
longint unsigned region_mem_reads;
longint unsigned region_mem_r_beats;
longint unsigned region_mem_writes;
longint unsigned region_mem_w_beats;
longint unsigned region_mem_b_responses;

wire commit_event       = (commit_fire === 1'b1);
wire fetch_request      = (fetch_req_valid === 1'b1) && (fetch_req_ready === 1'b1);
wire data_request       = (data_req_valid === 1'b1) && (data_req_ready === 1'b1);
wire fetch_wait_event   = (fetch_req_valid === 1'b1) && (fetch_req_ready === 1'b0);
wire data_wait_event    = (data_req_valid === 1'b1) && (data_req_ready === 1'b0);
wire ls_stall_event     = (ls_stall === 1'b1);
wire load_use_event     = (load_use_stall === 1'b1);
wire csr_stall_event    = (csr_stall === 1'b1);
wire i_ar_event         = (i_arvalid === 1'b1) && (i_arready === 1'b1);
wire i_r_event          = (i_rvalid === 1'b1) && (i_rready === 1'b1);
wire i_refill_event     = i_r_event && (i_rlast === 1'b1);
wire d_ar_event         = (d_arvalid === 1'b1) && (d_arready === 1'b1);
wire d_r_event          = (d_rvalid === 1'b1) && (d_rready === 1'b1);
wire d_refill_event     = d_r_event && (d_rlast === 1'b1);
wire d_aw_event         = (d_awvalid === 1'b1) && (d_awready === 1'b1);
wire d_w_event          = (d_wvalid === 1'b1) && (d_wready === 1'b1);
wire d_b_event          = (d_bvalid === 1'b1) && (d_bready === 1'b1);
wire mem_ar_event       = (mem_arvalid === 1'b1) && (mem_arready === 1'b1);
wire mem_r_event        = (mem_rvalid === 1'b1) && (mem_rready === 1'b1);
wire mem_aw_event       = (mem_awvalid === 1'b1) && (mem_awready === 1'b1);
wire mem_w_event        = (mem_wvalid === 1'b1) && (mem_wready === 1'b1);
wire mem_b_event        = (mem_bvalid === 1'b1) && (mem_bready === 1'b1);

function automatic real safe_ratio(
    input longint unsigned numerator,
    input longint unsigned denominator
);
    if (denominator == 0)
        safe_ratio = 0.0;
    else
        safe_ratio = $itor(int'(numerator)) / $itor(int'(denominator));
endfunction

initial begin
    region_start_PC = '0;
    region_end_PC = '0;
    region_enable = $value$plusargs("PERF_START_PC=%h", region_start_PC) &&
                    $value$plusargs("PERF_END_PC=%h", region_end_PC);
    if (region_enable)
        $display("[PERF] marked region enabled: start=%08h end=%08h",
                 region_start_PC, region_end_PC);
    else
        $display("[PERF] total-run counters enabled; no marked region supplied");
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        total_cycles                 <= 0;
        total_commits                <= 0;
        total_no_commit_cycles       <= 0;
        total_fetch_requests         <= 0;
        total_data_requests          <= 0;
        total_fetch_wait_cycles      <= 0;
        total_data_wait_cycles       <= 0;
        total_ls_stall_cycles        <= 0;
        total_load_use_stall_cycles  <= 0;
        total_csr_stall_cycles       <= 0;
        total_i_misses               <= 0;
        total_i_refills              <= 0;
        total_i_r_beats              <= 0;
        total_d_misses               <= 0;
        total_d_refills              <= 0;
        total_d_r_beats              <= 0;
        total_d_writebacks           <= 0;
        total_d_w_beats              <= 0;
        total_d_b_responses          <= 0;
        total_mem_reads              <= 0;
        total_mem_r_beats            <= 0;
        total_mem_writes             <= 0;
        total_mem_w_beats            <= 0;
        total_mem_b_responses        <= 0;

        region_active                <= 1'b0;
        region_seen                  <= 1'b0;
        region_complete              <= 1'b0;
        region_cycles                <= 0;
        region_commits               <= 0;
        region_no_commit_cycles      <= 0;
        region_fetch_requests        <= 0;
        region_data_requests         <= 0;
        region_fetch_wait_cycles     <= 0;
        region_data_wait_cycles      <= 0;
        region_ls_stall_cycles       <= 0;
        region_load_use_stall_cycles <= 0;
        region_csr_stall_cycles      <= 0;
        region_i_misses              <= 0;
        region_i_refills             <= 0;
        region_i_r_beats             <= 0;
        region_d_misses              <= 0;
        region_d_refills             <= 0;
        region_d_r_beats             <= 0;
        region_d_writebacks          <= 0;
        region_d_w_beats             <= 0;
        region_d_b_responses         <= 0;
        region_mem_reads             <= 0;
        region_mem_r_beats           <= 0;
        region_mem_writes            <= 0;
        region_mem_w_beats           <= 0;
        region_mem_b_responses       <= 0;
    end else begin
        total_cycles <= total_cycles + 1;
        if (commit_event)      total_commits <= total_commits + 1;
        else                   total_no_commit_cycles <= total_no_commit_cycles + 1;
        if (fetch_request)     total_fetch_requests <= total_fetch_requests + 1;
        if (data_request)      total_data_requests <= total_data_requests + 1;
        if (fetch_wait_event)  total_fetch_wait_cycles <= total_fetch_wait_cycles + 1;
        if (data_wait_event)   total_data_wait_cycles <= total_data_wait_cycles + 1;
        if (ls_stall_event)    total_ls_stall_cycles <= total_ls_stall_cycles + 1;
        if (load_use_event)    total_load_use_stall_cycles <= total_load_use_stall_cycles + 1;
        if (csr_stall_event)   total_csr_stall_cycles <= total_csr_stall_cycles + 1;
        if (i_ar_event)        total_i_misses <= total_i_misses + 1;
        if (i_refill_event)    total_i_refills <= total_i_refills + 1;
        if (i_r_event)         total_i_r_beats <= total_i_r_beats + 1;
        if (d_ar_event)        total_d_misses <= total_d_misses + 1;
        if (d_refill_event)    total_d_refills <= total_d_refills + 1;
        if (d_r_event)         total_d_r_beats <= total_d_r_beats + 1;
        if (d_aw_event)        total_d_writebacks <= total_d_writebacks + 1;
        if (d_w_event)         total_d_w_beats <= total_d_w_beats + 1;
        if (d_b_event)         total_d_b_responses <= total_d_b_responses + 1;
        if (mem_ar_event)      total_mem_reads <= total_mem_reads + 1;
        if (mem_r_event)       total_mem_r_beats <= total_mem_r_beats + 1;
        if (mem_aw_event)      total_mem_writes <= total_mem_writes + 1;
        if (mem_w_event)       total_mem_w_beats <= total_mem_w_beats + 1;
        if (mem_b_event)       total_mem_b_responses <= total_mem_b_responses + 1;

        if (region_enable && !region_seen && commit_event &&
            (commit_PC == region_start_PC)) begin
            region_active   <= 1'b1;
            region_seen     <= 1'b1;
            region_complete <= 1'b0;
        end else if (region_active) begin
            region_cycles <= region_cycles + 1;
            if (commit_event)      region_commits <= region_commits + 1;
            else                   region_no_commit_cycles <= region_no_commit_cycles + 1;
            if (fetch_request)     region_fetch_requests <= region_fetch_requests + 1;
            if (data_request)      region_data_requests <= region_data_requests + 1;
            if (fetch_wait_event)  region_fetch_wait_cycles <= region_fetch_wait_cycles + 1;
            if (data_wait_event)   region_data_wait_cycles <= region_data_wait_cycles + 1;
            if (ls_stall_event)    region_ls_stall_cycles <= region_ls_stall_cycles + 1;
            if (load_use_event)    region_load_use_stall_cycles <= region_load_use_stall_cycles + 1;
            if (csr_stall_event)   region_csr_stall_cycles <= region_csr_stall_cycles + 1;
            if (i_ar_event)        region_i_misses <= region_i_misses + 1;
            if (i_refill_event)    region_i_refills <= region_i_refills + 1;
            if (i_r_event)         region_i_r_beats <= region_i_r_beats + 1;
            if (d_ar_event)        region_d_misses <= region_d_misses + 1;
            if (d_refill_event)    region_d_refills <= region_d_refills + 1;
            if (d_r_event)         region_d_r_beats <= region_d_r_beats + 1;
            if (d_aw_event)        region_d_writebacks <= region_d_writebacks + 1;
            if (d_w_event)         region_d_w_beats <= region_d_w_beats + 1;
            if (d_b_event)         region_d_b_responses <= region_d_b_responses + 1;
            if (mem_ar_event)      region_mem_reads <= region_mem_reads + 1;
            if (mem_r_event)       region_mem_r_beats <= region_mem_r_beats + 1;
            if (mem_aw_event)      region_mem_writes <= region_mem_writes + 1;
            if (mem_w_event)       region_mem_w_beats <= region_mem_w_beats + 1;
            if (mem_b_event)       region_mem_b_responses <= region_mem_b_responses + 1;

            if (commit_event && (commit_PC == region_end_PC)) begin
                region_active   <= 1'b0;
                region_complete <= 1'b1;
            end
        end
    end
end

final begin
    $display("");
    $display("================ CPU PERFORMANCE MONITOR ================");
    $display("TOTAL (reset release through simulation end)");
    $display("  cycles=%0d commits=%0d CPI=%0.3f IPC=%0.3f",
             total_cycles, total_commits,
             safe_ratio(total_cycles, total_commits),
             safe_ratio(total_commits, total_cycles));
    $display("  no-commit cycles=%0d (%0.2f%%)", total_no_commit_cycles,
             100.0 * safe_ratio(total_no_commit_cycles, total_cycles));
    $display("  I$: requests=%0d misses=%0d refills=%0d R-beats=%0d miss-rate=%0.2f%% MPKI=%0.2f",
             total_fetch_requests, total_i_misses, total_i_refills, total_i_r_beats,
             100.0 * safe_ratio(total_i_misses, total_fetch_requests),
             1000.0 * safe_ratio(total_i_misses, total_commits));
    $display("  D$: requests=%0d misses=%0d refills=%0d R-beats=%0d miss-rate=%0.2f%% MPKI=%0.2f",
             total_data_requests, total_d_misses, total_d_refills, total_d_r_beats,
             100.0 * safe_ratio(total_d_misses, total_data_requests),
             1000.0 * safe_ratio(total_d_misses, total_commits));
    $display("  stalls: fetch-wait=%0d data-wait=%0d ls=%0d load-use=%0d csr=%0d",
             total_fetch_wait_cycles, total_data_wait_cycles, total_ls_stall_cycles,
             total_load_use_stall_cycles, total_csr_stall_cycles);
    $display("  D$ writeback: AW=%0d W-beats=%0d B=%0d",
             total_d_writebacks, total_d_w_beats, total_d_b_responses);
    $display("  shared AXI: AR=%0d R-beats=%0d AW=%0d W-beats=%0d B=%0d",
             total_mem_reads, total_mem_r_beats, total_mem_writes,
             total_mem_w_beats, total_mem_b_responses);

    if (region_enable && region_complete) begin
        $display("---------------------------------------------------------");
        $display("MARKED WARM REGION start=%08h end=%08h", region_start_PC, region_end_PC);
        $display("  cycles=%0d commits=%0d CPI=%0.3f IPC=%0.3f",
                 region_cycles, region_commits,
                 safe_ratio(region_cycles, region_commits),
                 safe_ratio(region_commits, region_cycles));
        $display("  no-commit cycles=%0d (%0.2f%%)", region_no_commit_cycles,
                 100.0 * safe_ratio(region_no_commit_cycles, region_cycles));
        $display("  I$: requests=%0d misses=%0d refills=%0d R-beats=%0d miss-rate=%0.2f%% MPKI=%0.2f",
                 region_fetch_requests, region_i_misses, region_i_refills, region_i_r_beats,
                 100.0 * safe_ratio(region_i_misses, region_fetch_requests),
                 1000.0 * safe_ratio(region_i_misses, region_commits));
        $display("  D$: requests=%0d misses=%0d refills=%0d R-beats=%0d miss-rate=%0.2f%% MPKI=%0.2f",
                 region_data_requests, region_d_misses, region_d_refills, region_d_r_beats,
                 100.0 * safe_ratio(region_d_misses, region_data_requests),
                 1000.0 * safe_ratio(region_d_misses, region_commits));
        $display("  stalls: fetch-wait=%0d data-wait=%0d ls=%0d load-use=%0d csr=%0d",
                 region_fetch_wait_cycles, region_data_wait_cycles, region_ls_stall_cycles,
                 region_load_use_stall_cycles, region_csr_stall_cycles);
        $display("  D$ writeback: AW=%0d W-beats=%0d B=%0d",
                 region_d_writebacks, region_d_w_beats, region_d_b_responses);
        $display("  shared AXI: AR=%0d R-beats=%0d AW=%0d W-beats=%0d B=%0d",
                 region_mem_reads, region_mem_r_beats, region_mem_writes,
                 region_mem_w_beats, region_mem_b_responses);
    end else if (region_enable) begin
        $display("  WARNING: marked region did not complete (seen=%0d active=%0d)",
                 region_seen, region_active);
    end
    $display("  Note: stall counters may overlap and therefore do not sum to total cycles.");
    $display("=========================================================");
end

endmodule
