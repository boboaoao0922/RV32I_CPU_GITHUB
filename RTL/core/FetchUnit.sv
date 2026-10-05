import RISC_V_PKG::*;
module FetchUnit (
    input logic clk,
    input logic rst_n,
    input fetch_state i_state,
   // input logic i_redirect,
    input logic [31:0] i_redirect_addr,
    input logic i_cpu_req_ready,
    input logic i_cpu_rsp_valid,
    input logic [31:0]  i_cpu_rsp_data,
    input logic i_cpu_acc_fault,
    output logic [31:0] o_inst,
    output logic o_cpu_req_valid,
    output logic [31:0]  o_cpu_req_addr,
    output logic [31:0] o_PC,
    output logic o_out_valid,
    output logic o_exc_valid,
    output Mcause o_mcause,
    output logic [31:0] o_mtval
);

logic [31:0] PC,PC_comb,PC_wait;  
//PC is the program counter that is successfully handshaked with cache. 
//PC_comb is the combinational wire that will send to o_cpu_req_addr
//PC_wait is the pending PC that is waiting for handshake

logic [31:0] inst_buffer; // receive inst at reponse
logic flag_buffer_has_inst_at_hold; //indicate that response of cache is returned in fetch_hold state
//logic [31:0] redirect_addr_buffer; // store the
logic flag_redirect_done; // indicate that redirect is done
logic flag_pending; // indicate that there is a PC waiting for handshake

logic exc_pending;

//logic HS_preInst;
always_ff@(posedge clk, negedge rst_n) begin
    if (!rst_n) 
        PC <= 0;
    else begin
        if (i_state == fetch_clear)
            PC <= 0;
        else if (i_cpu_req_ready && o_cpu_req_valid)
            PC <= o_cpu_req_addr;
    end
end

always_ff@(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
        inst_buffer <= 0;
    end else begin
        if (i_state == fetch_clear)
            inst_buffer <= 0;
        else if (i_cpu_rsp_valid )
            inst_buffer <= i_cpu_rsp_data;
    end
end

always_ff@(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
        PC_wait <= 0;
    end else begin
        if ( ~i_cpu_req_ready && o_cpu_req_valid)
            PC_wait <= o_cpu_req_addr;
    end
end


always_ff@(posedge clk, negedge rst_n) begin
    if (!rst_n) 
        flag_redirect_done <= 1;
    else begin
        if (i_state == fetch_redirect && !(i_cpu_req_ready && o_cpu_req_valid))
            flag_redirect_done <= 0;
        else if (!flag_redirect_done && i_cpu_req_ready && o_cpu_req_valid)
            flag_redirect_done <= 1;
    end
end

always_ff@(posedge clk, negedge rst_n) begin
    if (!rst_n) 
        flag_pending <= 1;
    else begin
        if (i_state == fetch_clear || (~i_cpu_req_ready && o_cpu_req_valid))
            flag_pending <= 1;
        else if(i_cpu_req_ready && o_cpu_req_valid)
            flag_pending <= 0;
    end
end


always_ff@(posedge clk,negedge rst_n) begin
    if (!rst_n)
        flag_buffer_has_inst_at_hold <= 0;
    else begin
        if (i_state == fetch_load || i_state == fetch_redirect || i_state == fetch_clear || i_state == fetch_capture)
            flag_buffer_has_inst_at_hold <= 0;
        else if (i_state == fetch_hold && i_cpu_rsp_valid)
            flag_buffer_has_inst_at_hold <= 1;
    end
end

always_comb begin
    case(i_state)
        fetch_load : begin
            if (flag_pending)
                PC_comb = PC_wait;
            else
                PC_comb = PC + 4;    
        end
        fetch_redirect: begin
                PC_comb = i_redirect_addr;
        end
        fetch_hold : begin
            PC_comb = PC;
        end
        fetch_clear: PC_comb = 0;
        fetch_capture: PC_comb = PC;
        default : PC_comb = PC;
    endcase
end

always_comb begin
    case (i_state)
        fetch_load : begin
                //if (flag_redirect_done)
                    o_cpu_req_addr = PC_comb;
                //else
                    //o_cpu_req_addr = redirect_addr_buffer;
        end
        fetch_redirect: begin 
                o_cpu_req_addr = i_redirect_addr;
        end
        default: o_cpu_req_addr = PC;
    endcase
end

always_comb begin
    case (i_state)
        fetch_load : begin
            o_cpu_req_valid = 1;
        end
        fetch_hold : begin
            o_cpu_req_valid = 0;
        end
        fetch_clear : begin
            o_cpu_req_valid = 0;
        end
        fetch_redirect :begin
            o_cpu_req_valid = 1;
        end
        fetch_capture:begin
            o_cpu_req_valid = 0;
        end
        default : o_cpu_req_valid = 0;
    endcase
end

always_comb begin
    case(i_state)
        fetch_load : begin
            if((flag_buffer_has_inst_at_hold || i_cpu_rsp_valid)  && flag_redirect_done)
                o_out_valid = 1;
            else
                o_out_valid = 0;
        end
        fetch_redirect : begin
            o_out_valid = 0;
        end
        fetch_capture : begin
            o_out_valid = 1;
        end
        default : o_out_valid = 0;
    endcase
end

always_comb begin
    o_PC = PC;
end

always_comb begin
    if(flag_buffer_has_inst_at_hold && flag_redirect_done)
        o_inst = inst_buffer;
    else if (i_cpu_rsp_valid && flag_redirect_done)
        o_inst = i_cpu_rsp_data;
    else
        o_inst = 0;
end

always_ff@(posedge clk, negedge rst_n)begin
    if(!rst_n)
        exc_pending <= 0;
    else begin
        if(i_state == fetch_capture || i_state == fetch_clear || i_state == fetch_redirect)
            exc_pending <= 0;
        else if(i_cpu_acc_fault || exc_pending)
            exc_pending <= 1;
    end
end

assign o_exc_valid =  exc_pending || i_cpu_acc_fault;
//assign o_mcause = o_exc_valid ? Mcause_INST_ACCFAULT : Mcause_INST_MISALIGNED;
always_comb begin
    if(o_exc_valid)
        o_mcause = Mcause_INST_ACCFAULT;
    else
        o_mcause = Mcause_INST_MISALIGNED;
end
assign o_mtval = PC;

endmodule