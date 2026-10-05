import RISC_V_PKG::*;
module PATTERN(
    input logic clk,
    output logic rst_n,
    
    input logic commit_fire,
    input logic [31:0] commit_PC, //for debug
    input logic [31:0] commit_inst,
    input logic [4:0] commit_rd,
    input logic commit_we,
    input logic [31:0] commit_wb_data,
    input Commit_type commit_type,

    output logic MEIP
);

`include "DISPLAY_FAIL.sv"
parameter MAX_TIME_OUT = 2000;
parameter INTERRUPT_TRA_NO = 11;

integer POST_RST_WAIT = 6;
integer pat_count;
integer trace_fd;
integer scan_count;
integer reg_fd;
string  header;
integer csr_fd;
logic [31:0] golden_PC;
logic [31:0] golden_inst;
integer      golden_rd;
integer      golden_we;
logic [31:0] golden_wdata;
integer reg_index;
logic [31:0] reg_value;
integer golden_commit_type;
integer timeout_cnt;
integer commit_count;
logic [31:0] csrfile_mepc, csrfile_mtvec;
logic csrfile_mstatus_MPIE, csrfile_mstatus_MIE, csrfile_mie_MEIE, csrfile_mip_MEIP;
string trace_path, reg_path, csr_path;
int unsigned random_seed;

initial begin
    trace_path = "goldenPC_inst.txt";
    reg_path = "goldenReg.txt";
    csr_path = "goldenCsr.txt";
    if ($value$plusargs("TRACE=%s", trace_path)) begin end
    if ($value$plusargs("REG_GOLDEN=%s", reg_path)) begin end
    if ($value$plusargs("CSR_GOLDEN=%s", csr_path)) begin end
    if (!$value$plusargs("RAND_SEED=%d", random_seed)) random_seed = 1;
    $display("[SYSTEM] RAND_SEED=%0d; latency comes from the external AXI DRAM model", random_seed);

    trace_fd = $fopen(trace_path, "r");
    if (trace_fd == 0)
        $fatal(1, "Cannot open %s", trace_path);
    scan_count = $fgets(header, trace_fd);
    reg_fd = $fopen(reg_path, "r");
    if (reg_fd == 0)
        $fatal(1, "Cannot open %s", reg_path);
    csr_fd = $fopen(csr_path, "r");
    if (csr_fd == 0)
        $fatal(1, "Cannot open %s", csr_path);
    // ------------------------------------------------------------------
    // 1. Initialise all outputs
    //    rst_n starts HIGH (de-asserted); all DUT inputs start at 0
    // ------------------------------------------------------------------
    rst_n = 1;
    MEIP = 0;
    commit_count = 0;
    // ------------------------------------------------------------------
    // 2. Reset sequence  (also freezes and releases clk)
    // ------------------------------------------------------------------
    reset_task();
    // ------------------------------------------------------------------
    // 3. Wait a few cycles for DUT to fully stabilise after reset
    // ------------------------------------------------------------------
    //repeat (POST_RST_WAIT) @(posedge clk);
    // ------------------------------------------------------------------
    // 4. direct test
    // ------------------------------------------------------------------
    timeout_cnt = 0;
    while (1) begin
        @(posedge clk);
        if (commit_fire === 1) begin
            commit_checker();
            timeout_cnt = 0;
        end else begin
            timeout_cnt++;
            if (timeout_cnt >= MAX_TIME_OUT) begin
                display_fail("No commit timeout");
                $display("No commit for %0d cycles; seed=%0d", MAX_TIME_OUT, random_seed);
                $finish;
            end
        end
    end
end

task automatic reset_task();
    // Step 1: freeze clock and assert reset
    force clk  = 1'b0;
    #0.5  rst_n = 1'b0;

    // Wait long enough for DUT flops to settle
    #100;

    // Step 2: check CPU-facing response ports are all 0
    if (
        commit_fire !== 0 ||
        commit_we !== 0
    ) begin
        display_fail("some signals are not reset to 0");
        $display("  commit_fire     = %h", commit_fire);
        $display("  commit_we = %h", commit_we);
        $display("Simulation terminated");
		//#(100);
		$finish;
    end
    // Step 3: de-assert reset, release clock
    #1.0  rst_n = 1'b1;
    #3.0  release clk;   // TESTBENCH always block takes over from here
endtask

task automatic commit_checker();
    scan_count = $fscanf(
        trace_fd,
        "%h %h %d %d %h %d",
        golden_PC,
        golden_inst,
        golden_rd,
        golden_we,
        golden_wdata,
        golden_commit_type
    );
    if (scan_count != 6) begin
        display_fail("Golden commit trace ended or malformed");
        $finish;
    end
    if (commit_PC !== golden_PC) begin
        display_fail("commit PC error");
        $display("Your commit PC: %h", commit_PC);
        $display("golden commit PC: %h", golden_PC);
        $finish;
    end

    if (commit_inst !== golden_inst) begin
        display_fail("commit PC error");
        $display("Your commit inst: %h", commit_inst);
        $display("golden commit inst: %h", golden_inst);
        $finish;
    end

    if (commit_we !== golden_we) begin
        display_fail("commit we error");
        $display("Your commit we: %h", commit_we);
        $display("golden commit we: %h", golden_we);
        $finish;
    end else if(commit_we == 1) begin
        if(commit_rd !== golden_rd)begin
            display_fail("commit rd error");
            $display("Your commit rd: %h", commit_rd);
            $display("golden commit rd: %h", golden_rd);
            $finish;
        end else if(commit_wb_data !== golden_wdata)begin
            display_fail("commit wdata error");
            $display("Your commit wdata: %h", commit_wb_data);
            $display("golden commit wdata: %h", golden_wdata);
            $finish;
        end
    end

    if(commit_type !== golden_commit_type)begin
        display_fail("commit type error");
        $display("Your commit type: %h", commit_type);
        $display("golden commit type: %h", golden_commit_type);
        $finish;
    end
    commit_count++;

    if(commit_PC == 32'h0000_ff00)begin
        while($fscanf(reg_fd,"%d %h", reg_index, reg_value) == 2) begin
            if(TESTBENCH.dut.u_cpu.u_RegFile.regs[reg_index] !== reg_value && reg_index !== 0)begin
                display_fail("register file error");
                $display("Your reg[%d] = %h",reg_index,TESTBENCH.dut.u_cpu.u_RegFile.regs[reg_index]);
                $display("Golden reg[%d] = %h",reg_index, reg_value);
                $finish;
            end
        end
        if($fscanf(csr_fd,"%h %h %h %h %h %h", csrfile_mepc, csrfile_mtvec, csrfile_mstatus_MPIE, csrfile_mstatus_MIE, csrfile_mie_MEIE, csrfile_mip_MEIP) == 6)begin
            if(TESTBENCH.dut.u_cpu.u_CSRFile.o_mepc !== csrfile_mepc || 
                TESTBENCH.dut.u_cpu.u_CSRFile.o_mtvec !== csrfile_mtvec ||
                TESTBENCH.dut.u_cpu.u_CSRFile.o_mstatus_MPIE !== csrfile_mstatus_MPIE ||
                TESTBENCH.dut.u_cpu.u_CSRFile.o_mstatus_MIE !== csrfile_mstatus_MIE ||
                TESTBENCH.dut.u_cpu.u_CSRFile.o_mie_MEIE !== csrfile_mie_MEIE ||
                TESTBENCH.dut.u_cpu.u_CSRFile.o_mip_MEIP !== csrfile_mip_MEIP )begin
                    display_fail("csr file error");
                    $display("Your o_mepc : %h", TESTBENCH.dut.u_cpu.u_CSRFile.o_mepc);
                    $display("Golden mepc : %h", csrfile_mepc);
                    $display("Your o_mtvec : %h", TESTBENCH.dut.u_cpu.u_CSRFile.o_mtvec);
                    $display("Golden mtvec : %h", csrfile_mtvec);
                    $display("Your o_mstatus_MPIE : %h", TESTBENCH.dut.u_cpu.u_CSRFile.o_mstatus_MPIE);
                    $display("Golden mstatus_MPIE : %h", csrfile_mstatus_MPIE);
                    $display("Your o_mstatus_MIE : %h", TESTBENCH.dut.u_cpu.u_CSRFile.o_mstatus_MIE);
                    $display("Golden mstatus_MIE : %h", csrfile_mstatus_MIE);
                    $display("Your o_mie_MEIE : %h", TESTBENCH.dut.u_cpu.u_CSRFile.o_mie_MEIE);
                    $display("Golden mie_MEIE : %h", csrfile_mie_MEIE);
                    $display("Your o_mip_MEIP : %h", TESTBENCH.dut.u_cpu.u_CSRFile.o_mip_MEIP);
                    $display("Golden mip_MEIP : %h", csrfile_mip_MEIP);
                    $finish;
            end
        end  else begin
            display_fail("Golden csr file error");
            $finish;
        end
        
        display_pass();
        $display("RANDOM_PASS");
        $finish;
    end else if(commit_PC == 32'h0000_fe00) begin
        display_fail("PC fail");
        $display("PC is at 32'h0000_FE00, test failed");
        $finish;
    end
endtask

task automatic interrupt_ctrl(input logic flag_interrupt,input integer tra_count);
    integer timeout_count;
    if(flag_interrupt)begin
        while(commit_count < tra_count)
            @(negedge clk);
        MEIP = 1;

        timeout_count = 0;
        do begin
            @(posedge clk);
            if(timeout_count >= MAX_TIME_OUT)begin
                display_fail("interrupt time out");
                $display("waiting trap to interrupt handler time out");
                $finish;
            end
            timeout_count++;
        end while(!(TESTBENCH.dut.u_cpu.wb_trap && TESTBENCH.dut.u_cpu.ctrl_trap_interrupt));
        @(negedge clk);
        MEIP = 0;
    end
endtask
   
endmodule
