import RISC_V_PKG::*;

module PATTERN(
    input  logic       clk,
    output logic       rst_n,
    input  logic       commit_fire,
    input  logic [31:0] commit_PC,
    input  logic [31:0] commit_inst,
    input  logic [4:0] commit_rd,
    input  logic       commit_we,
    input  logic [31:0] commit_wb_data,
    input  Commit_type commit_type,
    output logic       MEIP
);

`include "DISPLAY_FAIL.sv"

parameter MAX_NO_COMMIT_CYCLES = 4000;
parameter MAX_TOTAL_CYCLES     = 20000;

integer irq_case;
logic [31:0] irq_wait_pc, irq_wait2_pc, irq_load_pc;
logic [31:0] irq_mepc_min, irq_mepc_max;
string reg_path, csr_path, irq_golden_path;

integer reg_fd, csr_fd, irq_fd;
integer scan_count;
integer reg_index;
logic [31:0] reg_value;
logic [31:0] csrfile_mepc, csrfile_mtvec;
logic csrfile_mstatus_MPIE, csrfile_mstatus_MIE;
logic csrfile_mie_MEIE, csrfile_mip_MEIP;

integer expected_traps, expected_mrets;
logic [31:0] expected_mcause, expected_mtval;
integer require_pending, require_drain;
integer require_mem_overlap, require_retrigger;
string irq_header;

integer trap_count, mret_count, total_cycles, no_commit_cycles;
logic irq_asserted, meip_drop_scheduled, meip_deasserted;
logic pending_seen, drain_seen, mem_overlap_seen, retrigger_seen;
logic load_commit_seen;

initial begin
    if (!$value$plusargs("IRQ_CASE=%d", irq_case))
        $fatal(1, "IRQ_CASE plusarg is required");
    if (!$value$plusargs("IRQ_WAIT_PC=%h", irq_wait_pc)) irq_wait_pc = 32'hffff_ffff;
    if (!$value$plusargs("IRQ_WAIT2_PC=%h", irq_wait2_pc)) irq_wait2_pc = 32'hffff_ffff;
    if (!$value$plusargs("IRQ_LOAD_PC=%h", irq_load_pc)) irq_load_pc = 32'hffff_ffff;
    if (!$value$plusargs("IRQ_MEPC_MIN=%h", irq_mepc_min)) irq_mepc_min = 32'd0;
    if (!$value$plusargs("IRQ_MEPC_MAX=%h", irq_mepc_max)) irq_mepc_max = 32'hffff_ffff;

    reg_path = "goldenReg.txt";
    csr_path = "goldenCsr.txt";
    irq_golden_path = "goldenIRQ.txt";
    if ($value$plusargs("REG_GOLDEN=%s", reg_path)) begin end
    if ($value$plusargs("CSR_GOLDEN=%s", csr_path)) begin end
    if ($value$plusargs("IRQ_GOLDEN=%s", irq_golden_path)) begin end

    reg_fd = $fopen(reg_path, "r");
    csr_fd = $fopen(csr_path, "r");
    irq_fd = $fopen(irq_golden_path, "r");
    if (reg_fd == 0) $fatal(1, "Cannot open %s", reg_path);
    if (csr_fd == 0) $fatal(1, "Cannot open %s", csr_path);
    if (irq_fd == 0) $fatal(1, "Cannot open %s", irq_golden_path);

    scan_count = $fgets(irq_header, irq_fd);
    if ($fscanf(irq_fd, "%d %d %h %h %d %d %d %d",
                expected_traps, expected_mrets,
                expected_mcause, expected_mtval,
                require_pending, require_drain,
                require_mem_overlap, require_retrigger) != 8)
        $fatal(1, "Malformed IRQ golden: %s", irq_golden_path);

    rst_n = 1'b1;
    MEIP = 1'b0;
    trap_count = 0;
    mret_count = 0;
    total_cycles = 0;
    no_commit_cycles = 0;
    irq_asserted = 1'b0;
    meip_drop_scheduled = 1'b0;
    meip_deasserted = 1'b0;
    pending_seen = 1'b0;
    drain_seen = 1'b0;
    mem_overlap_seen = 1'b0;
    retrigger_seen = 1'b0;
    load_commit_seen = 1'b0;

    reset_task();
    fork
        irq_driver();
    join_none

    forever begin
        @(posedge clk);
        total_cycles++;

        if (TESTBENCH.dut.u_cpu.u_controller.irq_pending === 1'b1)
            pending_seen = 1'b1;
        if (TESTBENCH.dut.u_cpu.u_controller.irq_drain === 1'b1 ||
            TESTBENCH.dut.u_cpu.u_controller.irq_drain_start === 1'b1)
            drain_seen = 1'b1;
        if (TESTBENCH.dut.u_cpu.u_controller.irq_pending === 1'b1 &&
            TESTBENCH.dut.u_cpu.ls_stall === 1'b1)
            mem_overlap_seen = 1'b1;

        if (commit_fire === 1'b1) begin
            no_commit_cycles = 0;
            if (commit_PC == irq_load_pc)
                load_commit_seen = 1'b1;
            if (commit_PC == 32'h0000_fe00) begin
                display_fail("IRQ assembly reached fail sentinel");
                $finish;
            end
            if (commit_PC == 32'h0000_ff00) begin
                check_final_state();
                display_pass();
                $display("IRQ_REGRESSION_PASS case=%0d traps=%0d mrets=%0d",
                         irq_case, trap_count, mret_count);
                $finish;
            end
        end else begin
            no_commit_cycles++;
        end

        if (TESTBENCH.dut.u_cpu.wb_trap === 1'b1 &&
            TESTBENCH.dut.u_cpu.ctrl_trap_interrupt === 1'b1)
            observe_interrupt_trap();

        if (TESTBENCH.dut.u_cpu.wb_mret === 1'b1) begin
            mret_count++;
            if (irq_case == 3 && mret_count == 1 && MEIP === 1'b1)
                retrigger_seen = 1'b1;
        end

        if (no_commit_cycles >= MAX_NO_COMMIT_CYCLES)
            $fatal(1, "IRQ regression no-commit timeout case=%0d", irq_case);
        if (total_cycles >= MAX_TOTAL_CYCLES)
            $fatal(1, "IRQ regression total timeout case=%0d", irq_case);
    end
end

task automatic reset_task();
    force clk = 1'b0;
    #0.5 rst_n = 1'b0;
    #100;
    if (commit_fire !== 1'b0 || commit_we !== 1'b0)
        $fatal(1, "Commit interface did not reset cleanly");
    #1.0 rst_n = 1'b1;
    #3.0 release clk;
endtask

task automatic irq_driver();
    case (irq_case)
        1, 3: begin
            do @(posedge clk);
            while (!(commit_fire === 1'b1 && commit_PC == irq_wait_pc));
        end
        2: begin
            do @(posedge clk);
            while (!(TESTBENCH.dut.d_axi.ARVALID === 1'b1 &&
                     TESTBENCH.dut.d_axi.ARREADY === 1'b1 &&
                     TESTBENCH.dut.d_axi.ARADDR == 32'h0001_0000));
        end
        default: $fatal(1, "Unsupported IRQ_CASE=%0d", irq_case);
    endcase

    @(negedge clk);
    MEIP = 1'b1;
    irq_asserted = 1'b1;
    $display("[IRQ] MEIP asserted case=%0d time=%0t", irq_case, $time);
endtask

task automatic observe_interrupt_trap();
    integer next_trap_count;
    next_trap_count = trap_count + 1;

    if (TESTBENCH.dut.u_cpu.wb_trap_mcause !== expected_mcause)
        $fatal(1, "IRQ mcause mismatch: got=%h expected=%h",
               TESTBENCH.dut.u_cpu.wb_trap_mcause, expected_mcause);
    if (TESTBENCH.dut.u_cpu.wb_trap_mtval !== expected_mtval)
        $fatal(1, "IRQ mtval mismatch: got=%h expected=%h",
               TESTBENCH.dut.u_cpu.wb_trap_mtval, expected_mtval);

    case (irq_case)
        1: begin
            if (TESTBENCH.dut.u_cpu.wb_trap_mepc != irq_wait_pc &&
                TESTBENCH.dut.u_cpu.wb_trap_mepc != irq_wait_pc + 32'd4)
                $fatal(1, "Single IRQ mepc outside wait loop: %h",
                       TESTBENCH.dut.u_cpu.wb_trap_mepc);
        end
        2: begin
            if (TESTBENCH.dut.u_cpu.wb_trap_mepc < irq_mepc_min ||
                TESTBENCH.dut.u_cpu.wb_trap_mepc > irq_mepc_max ||
                TESTBENCH.dut.u_cpu.wb_trap_mepc[1:0] != 2'b00)
                $fatal(1, "Memory-stall IRQ mepc outside allowed range: %h",
                       TESTBENCH.dut.u_cpu.wb_trap_mepc);
            if (!load_commit_seen)
                $fatal(1, "Interrupt trap occurred before the older load retired");
        end
        3: begin
            if (next_trap_count == 1) begin
                if (TESTBENCH.dut.u_cpu.wb_trap_mepc != irq_wait_pc &&
                    TESTBENCH.dut.u_cpu.wb_trap_mepc != irq_wait_pc + 32'd4)
                    $fatal(1, "First retrigger IRQ mepc outside first loop: %h",
                           TESTBENCH.dut.u_cpu.wb_trap_mepc);
            end else if (next_trap_count == 2) begin
                if (TESTBENCH.dut.u_cpu.wb_trap_mepc != irq_wait2_pc &&
                    TESTBENCH.dut.u_cpu.wb_trap_mepc != irq_wait2_pc + 32'd4)
                    $fatal(1, "Second retrigger IRQ mepc outside second loop: %h",
                           TESTBENCH.dut.u_cpu.wb_trap_mepc);
            end
        end
    endcase

    trap_count = next_trap_count;
    if (trap_count > expected_traps)
        $fatal(1, "Too many interrupt traps: %0d", trap_count);

    if (!meip_drop_scheduled &&
        ((irq_case != 3 && trap_count == 1) ||
         (irq_case == 3 && trap_count == 2))) begin
        meip_drop_scheduled = 1'b1;
        fork
            begin
                @(negedge clk);
                MEIP = 1'b0;
                meip_deasserted = 1'b1;
                $display("[IRQ] MEIP deasserted case=%0d time=%0t", irq_case, $time);
            end
        join_none
    end
endtask

task automatic check_final_state();
    if (!irq_asserted || !meip_deasserted || MEIP !== 1'b0)
        $fatal(1, "MEIP stimulus did not complete cleanly");
    if (trap_count != expected_traps || mret_count != expected_mrets)
        $fatal(1, "IRQ event-count mismatch: traps=%0d/%0d mrets=%0d/%0d",
               trap_count, expected_traps, mret_count, expected_mrets);
    if (require_pending && !pending_seen)
        $fatal(1, "irq_pending was never observed");
    if (require_drain && !drain_seen)
        $fatal(1, "irq_drain/irq_drain_start was never observed");
    if (require_mem_overlap && !mem_overlap_seen)
        $fatal(1, "IRQ pending did not overlap the real D-cache stall");
    if (require_retrigger && !retrigger_seen)
        $fatal(1, "MEIP level was not retained across the first MRET");
    if (TESTBENCH.dut.MEIP_sync !== 1'b0)
        $fatal(1, "Synchronized MEIP did not return low before PASS");
    if (TESTBENCH.dut.u_cpu.u_controller.irq_pending !== 1'b0 ||
        TESTBENCH.dut.u_cpu.u_controller.irq_drain !== 1'b0)
        $fatal(1, "IRQ controller state was not clear at PASS");

    while ($fscanf(reg_fd, "%d %h", reg_index, reg_value) == 2) begin
        if (reg_index != 0 &&
            TESTBENCH.dut.u_cpu.u_RegFile.regs[reg_index] !== reg_value)
            $fatal(1, "GPR x%0d mismatch: got=%h expected=%h", reg_index,
                   TESTBENCH.dut.u_cpu.u_RegFile.regs[reg_index], reg_value);
    end

    if ($fscanf(csr_fd, "%h %h %h %h %h %h",
                csrfile_mepc, csrfile_mtvec,
                csrfile_mstatus_MPIE, csrfile_mstatus_MIE,
                csrfile_mie_MEIE, csrfile_mip_MEIP) != 6)
        $fatal(1, "Malformed CSR golden");

    if (TESTBENCH.dut.u_cpu.u_CSRFile.o_mepc !== csrfile_mepc ||
        TESTBENCH.dut.u_cpu.u_CSRFile.o_mtvec !== csrfile_mtvec ||
        TESTBENCH.dut.u_cpu.u_CSRFile.o_mstatus_MPIE !== csrfile_mstatus_MPIE ||
        TESTBENCH.dut.u_cpu.u_CSRFile.o_mstatus_MIE !== csrfile_mstatus_MIE ||
        TESTBENCH.dut.u_cpu.u_CSRFile.o_mie_MEIE !== csrfile_mie_MEIE ||
        TESTBENCH.dut.u_cpu.u_CSRFile.o_mip_MEIP !== csrfile_mip_MEIP)
        $fatal(1, "CSR golden mismatch");
endtask

endmodule
