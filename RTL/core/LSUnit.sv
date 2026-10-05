import RISC_V_PKG::*;
module LSUnit (
    input  logic         clk,
    input  logic         rst_n,  

    input logic i_reg_valid, // from ID/EX
    input logic i_issue_allowed, //from controller, handle exception or ext...
    input logic i_downstream_ready, //from MEM/WB reg, indicate downstream can accept data/ack 
    input logic [31:0] i_LS_addr, 
    input LoadStore_func3 i_loadstore_func3,
    input Mem_acc_type i_mem_acc_type,
    input Mem_acc_size i_mem_acc_size,
    input logic [31:0] i_store_data,

    output logic o_stall, //indicate that handshake failed or cache miss, tell controller to hold 
    output logic o_rsp_valid, //indicate that transaction done, data is valid
    output logic [31:0] o_rsp_data, // respone load data  
    output logic o_mem_err, //indicate error

    output logic o_exc_valid,
    output Mcause o_mcause,
    output logic [31:0] o_mtval,
    //cache interface
    input logic         i_cpu_req_ready,  //comb 1 means CPU can send command to cache, 0 means not
    input logic         i_cpu_rsp_load_ack, //comb
    input logic [31:0]  i_cpu_rsp_data,
	input logic         i_cpu_rsp_flush_ack, //sequential
	input logic 		i_cpu_rsp_store_ack, //comb
	input logic 		i_b_err_bit,
    input logic         i_cpu_acc_fault,
    
    output  logic         o_cpu_req_LS_valid,   //comb
    output  logic [31:0]  o_cpu_req_addr,
	output  logic [31:0]  o_cpu_wdata,	
	output  logic 		  o_cpu_we,  // 1 means write ,0 means read
	output  logic [3:0]   o_cpu_wstrb,
	output  logic 		  o_cpu_req_flush
);
Mem_acc_type mem_acc_type_rsp; //memory access type of response transaction 
Mem_acc_size mem_acc_size_rsp; //memory access size of response transaction
logic load_signed;
logic [1:0] response_addr_byte_sel;
logic [31:0] response_buffer;
logic response_buffer_valid;
logic handshake_miss;
logic response_miss;
logic wait_response;
logic [7:0] response_data_byte;
logic [15:0] response_data_halfword;
logic [31:0] response_data_extend;
logic [7:0] require_data_byte;
logic [15:0] require_data_halfword;
logic [31:0] response_addr;
logic fault_buffer_valid;

always_comb begin
    if(i_reg_valid && i_issue_allowed && (i_mem_acc_type == Mem_store || i_mem_acc_type == Mem_load))
        o_cpu_req_LS_valid = 1;
    else
        o_cpu_req_LS_valid = 0;
end

always_comb begin
    if(i_reg_valid && i_issue_allowed && (i_mem_acc_type == Mem_store))
        o_cpu_we = 1;
    else
        o_cpu_we = 0;
end


assign o_cpu_req_addr = {i_LS_addr[31:2],2'b0};
assign o_cpu_req_flush = 0; // 1st version, don't flush
//assign o_cpu_wdata = i_store_data;
always_comb begin
    if(i_mem_acc_type == Mem_store) begin
        case(i_mem_acc_size)
            Mem_acc_size_B: begin
                case(i_LS_addr[1:0])
                    2'b00: o_cpu_wdata = {24'd0, require_data_byte};
                    2'b01: o_cpu_wdata = {16'd0, require_data_byte, 8'd0};
                    2'b10: o_cpu_wdata = {8'd0, require_data_byte, 16'd0};
                    2'b11: o_cpu_wdata = {require_data_byte, 24'd0};
                    default:  o_cpu_wdata = 0;
                endcase
            end
            Mem_acc_size_H: begin
                case(i_LS_addr[1:0])
                    2'b00: o_cpu_wdata = {16'd0, require_data_halfword};
                    2'b10: o_cpu_wdata = {require_data_halfword, 16'd0};
                    default:  o_cpu_wdata = 0;
                endcase
            end
            Mem_acc_size_W: o_cpu_wdata = i_store_data;
            default: o_cpu_wdata = 0;
        endcase
    end else
        o_cpu_wdata = 0;
end

always_comb begin
    if(i_mem_acc_type == Mem_store) begin
        case(i_mem_acc_size)
            Mem_acc_size_B: o_cpu_wstrb = 4'b0001 << i_LS_addr[1:0];
            Mem_acc_size_H: o_cpu_wstrb = 4'b0011 << i_LS_addr[1:0];
            Mem_acc_size_W: o_cpu_wstrb = 4'b1111;
            default: o_cpu_wstrb = 4'b0;
        endcase
    end else
        o_cpu_wstrb = 4'b0;
end



always_comb begin
    if( i_b_err_bit || (i_reg_valid && ((i_mem_acc_type == Mem_load || i_mem_acc_type == Mem_store) 
        && ((i_mem_acc_size ==  Mem_acc_size_H && i_LS_addr[0]) || (i_mem_acc_size ==  Mem_acc_size_W && i_LS_addr[1:0])) )) )
        o_mem_err = 1;
    else
        o_mem_err = 0;
end

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)begin
        mem_acc_type_rsp <= Mem_none;
        mem_acc_size_rsp <= Mem_acc_size_none;
    end else if(o_cpu_req_LS_valid && i_cpu_req_ready) begin
        mem_acc_type_rsp <= i_mem_acc_type;
        mem_acc_size_rsp <= i_mem_acc_size;
    end    
end

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)begin
        load_signed <= 1;
    end else if(o_cpu_req_LS_valid && i_cpu_req_ready && i_mem_acc_type == Mem_load) begin
        if(i_loadstore_func3 == LS_BU || i_loadstore_func3 == LS_HU)
            load_signed <= 0;
        else
            load_signed <= 1;
    end    
end


always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)begin
        response_buffer <= 0;
    end else if(i_cpu_rsp_load_ack)
        response_buffer <= response_data_extend;
end

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)
        response_buffer_valid <= 0;
    else if((i_cpu_rsp_load_ack || i_cpu_rsp_store_ack || i_cpu_acc_fault) && (o_rsp_valid && ~i_downstream_ready))
        response_buffer_valid <= 1;
    else if(o_rsp_valid && i_downstream_ready)
        response_buffer_valid <= 0;
end

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)
        fault_buffer_valid <= 0;
    else if((o_exc_valid) && (o_rsp_valid && ~i_downstream_ready))
        fault_buffer_valid <= 1;
    else if(o_rsp_valid && i_downstream_ready)
        fault_buffer_valid <= 0;
end

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)begin
        wait_response <= 0;
    end else if(o_cpu_req_LS_valid && i_cpu_req_ready)
        wait_response <= 1;
    else if(wait_response && (i_cpu_rsp_load_ack || i_cpu_rsp_store_ack || i_cpu_acc_fault))
        wait_response <= 0;
end

assign handshake_miss = o_cpu_req_LS_valid && ~i_cpu_req_ready;
assign response_miss = wait_response && !(i_cpu_rsp_load_ack || i_cpu_rsp_store_ack || i_cpu_acc_fault);
assign o_stall = handshake_miss || response_miss;

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)
        response_addr_byte_sel <= 0;
    else if(o_cpu_req_LS_valid && i_cpu_req_ready)
        response_addr_byte_sel <= i_LS_addr[1:0];
end

always_comb begin
    case(response_addr_byte_sel)
        2'b00: response_data_byte = i_cpu_rsp_data[7:0];
        2'b01: response_data_byte = i_cpu_rsp_data[15:8];
        2'b10: response_data_byte = i_cpu_rsp_data[23:16];
        2'b11: response_data_byte = i_cpu_rsp_data[31:24];
        default: response_data_byte = 8'd0;
    endcase
end

always_comb begin
    case(response_addr_byte_sel)
        2'b00: response_data_halfword = i_cpu_rsp_data[15:0];
        2'b10: response_data_halfword= i_cpu_rsp_data[31:16];
        default: response_data_halfword = 16'd0;
    endcase
end

always_comb begin
    if(mem_acc_type_rsp == Mem_load) begin
        case(mem_acc_size_rsp)
            Mem_acc_size_B: begin
                if(load_signed)
                    response_data_extend = {{24{response_data_byte[7]}},response_data_byte};
                else
                    response_data_extend = {24'd0,response_data_byte};
            end
            Mem_acc_size_H: begin
                if(load_signed)
                    response_data_extend = {{16{response_data_halfword[15]}},response_data_halfword};
                else
                    response_data_extend = {16'd0,response_data_halfword};
            end
            Mem_acc_size_W: response_data_extend = i_cpu_rsp_data;
            default: response_data_extend = 0;
        endcase
    end else
        response_data_extend = 0;
end

always_comb begin
    if(response_buffer_valid)
        o_rsp_data = response_buffer;
    else
        o_rsp_data = response_data_extend;
end

assign o_rsp_valid = i_cpu_rsp_load_ack || i_cpu_rsp_store_ack || response_buffer_valid || i_cpu_acc_fault;

assign require_data_byte = i_store_data[7:0];
assign require_data_halfword = i_store_data[15:0];

assign o_exc_valid = i_cpu_acc_fault || fault_buffer_valid;
always_comb begin
    if(o_exc_valid)begin
        if(mem_acc_type_rsp == Mem_load)
            o_mcause = Mcause_LOAD_ACCFAULT;
        else    
            o_mcause = Mcause_STORE_ACCFAULT;
    end else
        o_mcause = Mcause_INST_MISALIGNED;
end

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)
        response_addr <= 0;
    else if(o_cpu_req_LS_valid && i_cpu_req_ready)
        response_addr <= i_LS_addr[31:0];
end

always_comb begin
    if(o_exc_valid)
        o_mtval = response_addr;
    else
        o_mtval = 0;
end

endmodule