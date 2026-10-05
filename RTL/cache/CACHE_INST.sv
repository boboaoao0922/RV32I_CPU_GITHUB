module CACHE_INST (
    input  logic         clk,
    input  logic         rst_n,     
    input  logic         cpu_req_valid,   //comb
    input  logic [31:0]  cpu_req_addr,  
    output logic         cpu_req_ready,  //comb
    output logic         cpu_rsp_valid, //comb
    output logic [31:0]  cpu_rsp_data,
    output logic         cpu_acc_fault,
    output logic         b_err_bit,
    INF_AXI.PATTERN inf_axi
);
import CACHE_PKG::*;
parameter SRAM_IDLE_GATING = 1'b1;
//=======================================================
//                   Reg/Wire
//=======================================================
cache_inst_state state,state_next;

logic [31:0]addr;
logic [5:0] index;
cache_set_t tag_SRAM_rdata_comb;
cache_set_t tag_SRAM_rdata_ff;
logic [15:0] tag_SRAM_byte_mask;
logic tag_SRAM_wen;
logic [5:0]SRAM_addr;
cacheline cacheline_data [3:0];
cacheline cacheline_data_hit;
word word_out;
cache_set_t tag_SRAM_wdata,tag_SRAM_wdata_ff;
logic [2:0]LRU[63:0];
logic [2:0]LRU_one_set_comb,LRU_one_set_ff;
logic [3:0]LRU_replace_target;
logic [3:0] replace_target;
logic [5:0] cnt_init;

logic tag_equal[3:0];
logic [3:0]tag_valid_and_equal;
logic hit;

logic [3:0]data_SRAM_wen;
logic [127:0] data_SRAM_wdata;

logic sram_idle_gating;
logic [3:0] data_SRAM_cen;
logic tag_SRAM_cen;

//=======================================================
//                   AXI Reg/Wire
//=======================================================
logic AR_Handshake;
logic [1:0]cnt_read;
logic [31:0]RDATA_buffer[3:0];
logic [2:0]ARID_local;

//=======================================================
//                   FSM
//=======================================================

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)
        state <= INIT;
    else
        state <= state_next;
end

always_comb begin
    case(state)
        INIT :  if(cnt_init == 63)
                    state_next = WAIT;
                else
                    state_next = INIT;
        WAIT:   if(cpu_req_valid && cpu_req_ready)
                    state_next = LOOKUP;
                else
                    state_next = WAIT;
        LOOKUP: if(cpu_req_valid && cpu_req_ready) 
                    state_next = LOOKUP;
                else if(!hit && !cpu_acc_fault)
                    state_next = AXI_READ;
                else
                    state_next = WAIT;
        AXI_READ: 
                if(inf_axi.RVALID && inf_axi.RREADY && (inf_axi.RRESP != 2'b00))
                    state_next = ERROR;
                else if(inf_axi.RVALID && inf_axi.RREADY && inf_axi.RLAST)
                    state_next =  REFILL;
                else    
                    state_next = AXI_READ; 
        REFILL: begin
            state_next = RETRIEVE;
        end
		RETRIEVE : begin
			state_next = LOOKUP;
		end
        ERROR: begin
            state_next = ERROR;
            //$display("                    INST CACHE ERROR                   ");
            //$finish;
        end
        default : state_next = state;
    endcase
end

//=======================================================
//                   Initialization
//=======================================================
always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)
        cnt_init <= 0;
    else if(state == INIT)
        cnt_init <= cnt_init + 1;
end

//=======================================================
//                   outputs
//=======================================================
/*always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)
        cpu_req_ready <= 0;
    else begin
        case(state)
            INIT :  if(state_next == WAIT)
                        cpu_req_ready <= 1;
                    else
                        cpu_req_ready <= 0;
            WAIT :  if(state_next)
        endcase
    end
end*/

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)
        cpu_acc_fault <= 0;
    else if(cpu_req_valid && cpu_req_ready && cpu_req_addr > 32'h0000_FFFC)
        cpu_acc_fault <= 1;
    else
        cpu_acc_fault <= 0;
end

always_comb begin
    case(state)
        INIT :  cpu_req_ready = 0;
        WAIT :  cpu_req_ready = 1;
        LOOKUP : cpu_req_ready = hit || cpu_acc_fault;
        default: cpu_req_ready = 0;
    endcase
    
end

always_comb begin
    case(state)
        LOOKUP : cpu_rsp_valid = hit && !cpu_acc_fault;
        default : cpu_rsp_valid = 0;
    endcase
end

assign cpu_rsp_data = word_out;


//=======================================================
//                   miss determination
//=======================================================
always_comb begin
    tag_equal[0] = (addr[31:10] == tag_SRAM_rdata_comb.way0.tag[21:0]);
    tag_equal[1] = (addr[31:10] == tag_SRAM_rdata_comb.way1.tag[21:0]);
    tag_equal[2] = (addr[31:10] == tag_SRAM_rdata_comb.way2.tag[21:0]);
    tag_equal[3] = (addr[31:10] == tag_SRAM_rdata_comb.way3.tag[21:0]);
end

always_comb begin
    tag_valid_and_equal[0] = tag_equal[0] && (tag_SRAM_rdata_comb.way0.state != INVALID);
    tag_valid_and_equal[1] = tag_equal[1] && (tag_SRAM_rdata_comb.way1.state != INVALID);
    tag_valid_and_equal[2] = tag_equal[2] && (tag_SRAM_rdata_comb.way2.state != INVALID);
    tag_valid_and_equal[3] = tag_equal[3] && (tag_SRAM_rdata_comb.way3.state != INVALID);
end

always_comb begin
    hit = tag_valid_and_equal[0] | tag_valid_and_equal[1] | tag_valid_and_equal[2] | tag_valid_and_equal[3];
end

//=======================================================
//                   cache line MUX
//=======================================================
always_comb begin
    case(tag_valid_and_equal)
        4'b1000 : cacheline_data_hit = cacheline_data[3];
        4'b0100 : cacheline_data_hit = cacheline_data[2];
        4'b0010 : cacheline_data_hit = cacheline_data[1];
        4'b0001 : cacheline_data_hit = cacheline_data[0];
        default : cacheline_data_hit = 128'd0;
    endcase
end

always_comb begin
    case(addr[3:2])
        2'b00 : word_out = cacheline_data_hit.word0;
        2'b01 : word_out = cacheline_data_hit.word1;
        2'b10 : word_out = cacheline_data_hit.word2;
        2'b11 : word_out = cacheline_data_hit.word3;
    endcase
end

assign index = addr[9:4];



//=======================================================
//                   LRU implementation
//=======================================================
always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)begin
        for(int i = 0; i < 64;i++)
            LRU[i] <= 3'd0;       
    end else begin
        case(state)
            LOOKUP : begin
                if(hit && !cpu_acc_fault)
                    LRU[addr[9:4]] <= LRU_one_set_comb;
            end
			REFILL: LRU[addr[9:4]] <= LRU_one_set_comb;
            default : LRU <= LRU;
        endcase
    end
end

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)begin
        LRU_one_set_ff <= 0;    
    end else begin
        LRU_one_set_ff <= LRU[addr[9:4]];
    end
end

always_comb begin
    case(state)
        LOOKUP : begin
            if(hit)
                case(tag_valid_and_equal)
                    4'b1000 : begin
                        LRU_one_set_comb[0] = 1'b1;             //access way3
                        LRU_one_set_comb[1] = LRU_one_set_ff[1];
                        LRU_one_set_comb[2] = 1'b1;
                    end
                    4'b0100 : begin
                        LRU_one_set_comb[0] = 1'b1;             //access way2
                        LRU_one_set_comb[1] = LRU_one_set_ff[1];
                        LRU_one_set_comb[2] = 1'b0;
                    end
                    4'b0010 : begin
                        LRU_one_set_comb[0] = 1'b0;             //access way1
                        LRU_one_set_comb[1] = 1'b1;
                        LRU_one_set_comb[2] = LRU_one_set_ff[2];
                    end
                    4'b0001 : begin
                        LRU_one_set_comb[0] = 1'b0;             //access way0
                        LRU_one_set_comb[1] = 1'b0;
                        LRU_one_set_comb[2] = LRU_one_set_ff[2];
                    end
                    default : LRU_one_set_comb = LRU_one_set_ff;
                endcase
            else
                LRU_one_set_comb = LRU[addr[9:4]];
        end
        REFILL:begin
            /*LRU_one_set_comb[0] = ~LRU_one_set_ff[0];
            if(~LRU_one_set_ff[0])begin
                LRU_one_set_comb[1] = LRU_one_set_ff[1];
                LRU_one_set_comb[2] = ~LRU_one_set_ff[2];
            end else begin
                LRU_one_set_comb[1] = ~LRU_one_set_ff[1];
                LRU_one_set_comb[2] = LRU_one_set_ff[2];
            end*/
			if(tag_SRAM_rdata_ff.way0.state == INVALID)begin
				LRU_one_set_comb[0] = 1'b0;             //access way0
				LRU_one_set_comb[1] = 1'b0;
				LRU_one_set_comb[2] = LRU_one_set_ff[2];
			end else if(tag_SRAM_rdata_ff.way1.state == INVALID) begin
				LRU_one_set_comb[0] = 1'b0;             //access way1
				LRU_one_set_comb[1] = 1'b1;
				LRU_one_set_comb[2] = LRU_one_set_ff[2];
			end else if(tag_SRAM_rdata_ff.way2.state == INVALID) begin
				LRU_one_set_comb[0] = 1'b1;             //access way2
				LRU_one_set_comb[1] = LRU_one_set_ff[1];
				LRU_one_set_comb[2] = 1'b0;
			end	else if(tag_SRAM_rdata_ff.way3.state == INVALID) begin
				LRU_one_set_comb[0] = 1'b1;             //access way3
				LRU_one_set_comb[1] = LRU_one_set_ff[1];
				LRU_one_set_comb[2] = 1'b1;
			end else begin
				LRU_one_set_comb[0] = ~LRU_one_set_ff[0];
				if(~LRU_one_set_ff[0])begin
					LRU_one_set_comb[1] = LRU_one_set_ff[1];
					LRU_one_set_comb[2] = ~LRU_one_set_ff[2];
				end else begin
					LRU_one_set_comb[1] = ~LRU_one_set_ff[1];
					LRU_one_set_comb[2] = LRU_one_set_ff[2];
				end
			end
				
        end
        default : LRU_one_set_comb = LRU_one_set_ff;
    endcase
end

always_comb begin
    if(~LRU_one_set_ff[0])begin
        if(~LRU_one_set_ff[2])
            LRU_replace_target = 4'b1000;
        else
            LRU_replace_target = 4'b0100;
    end else begin
        if(~LRU_one_set_ff[1])
            LRU_replace_target = 4'b0010;
        else
            LRU_replace_target = 4'b0001;
    end
end

always_comb begin
    if(tag_SRAM_rdata_ff.way0.state == INVALID)
        replace_target = 4'b0001;
    else if(tag_SRAM_rdata_ff.way1.state == INVALID)
        replace_target = 4'b0010;
    else if(tag_SRAM_rdata_ff.way2.state == INVALID)
        replace_target = 4'b0100;
    else if(tag_SRAM_rdata_ff.way3.state == INVALID)
        replace_target = 4'b1000;
    else    
        replace_target = LRU_replace_target;
end



//=======================================================
//                   AXI-READ
//=======================================================
assign inf_axi.AWID = 0;
assign inf_axi.AWLEN = 0;
assign inf_axi.AWSIZE = 0;
//assign inf_axi.rst_n = rst_n;
assign inf_axi.AWADDR = 0;
assign inf_axi.AWBURST = 2'b01;
assign inf_axi.AWVALID = 0;
assign inf_axi.WDATA = 0;
assign inf_axi.WVALID = 0;
assign inf_axi.WSTRB = 0;
assign inf_axi.WLAST = 0;
assign inf_axi.BREADY = 0;
assign inf_axi.ARID = {1'b0,ARID_local};
assign inf_axi.ARSIZE = 3'd2;
assign inf_axi.ARLEN = 8'd3;
assign inf_axi.ARBURST = 2'b01;

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)begin
        inf_axi.ARADDR <= 0; 
    end else begin
        if(state == AXI_READ)
            inf_axi.ARADDR <= {addr[31:4],4'h0};
    end
end

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)begin
        inf_axi.ARVALID <= 0; 
    end else begin
        if(!AR_Handshake && !(inf_axi.ARVALID && inf_axi.ARREADY) && state == AXI_READ)
            inf_axi.ARVALID <= 1;
        else
            inf_axi.ARVALID <= 0;
    end
end

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)begin
        AR_Handshake <= 0; 
    end else begin
        if(inf_axi.RLAST && inf_axi.RVALID && inf_axi.RREADY)
            AR_Handshake <= 0;
        else if(inf_axi.ARVALID && inf_axi.ARREADY)
            AR_Handshake <= 1;    
    end
end

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)
        ARID_local <= 0;
    else if(inf_axi.RLAST && inf_axi.RVALID && inf_axi.RREADY)
        ARID_local <= ARID_local + 1;
end

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)begin
        cnt_read <= 0; 
    end else begin
        if(inf_axi.RLAST && inf_axi.RVALID && inf_axi.RREADY)
            cnt_read <= 0;
        else if(inf_axi.RVALID && inf_axi.RREADY) 
            cnt_read <= cnt_read + 1; 
    end
end

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)begin
        for(int i=0;i<4;i++)
            RDATA_buffer[i] <= 0; 
    end else begin
        if(inf_axi.RVALID && inf_axi.RREADY) 
            RDATA_buffer[cnt_read] <= inf_axi.RDATA; 
    end
end

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)begin
        inf_axi.RREADY <= 0;
    end else begin
        if(state == AXI_READ)
            inf_axi.RREADY <= 1; 
    end
end

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)
        b_err_bit <= 1'd0;       
    else begin
		if(inf_axi.RVALID && inf_axi.RREADY && (inf_axi.RID != ARID_local))
			b_err_bit <= 1'd1;
	end	
end
//=======================================================
//                   SRAM control
//=======================================================
//tag_SRAM 's address

assign sram_idle_gating = SRAM_IDLE_GATING;

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)begin
        addr <= 32'd0;       
    end else begin
        if(cpu_req_valid && cpu_req_ready && !(cpu_req_addr > 32'h0000_FFFC))
            addr <= cpu_req_addr;
    end
end

always_comb begin
    case(state)
        INIT: SRAM_addr = cnt_init;
        WAIT: SRAM_addr = cpu_req_addr[9:4];
        LOOKUP: begin
            if(cpu_req_valid && cpu_req_ready)begin
                if(cpu_req_addr > 32'h0000_FFFC)
                    SRAM_addr = addr[9:4];
                else
                    SRAM_addr = cpu_req_addr[9:4];
            end else
                SRAM_addr = addr[9:4];
        end
        default: SRAM_addr = addr[9:4];
    endcase
end

always_comb begin
    case(state)
        INIT: tag_SRAM_wen = 1'b0;
        REFILL :tag_SRAM_wen = 1'b0;
        default : tag_SRAM_wen = 1'b1;
    endcase
end

always_comb begin
    case(state)
        INIT: tag_SRAM_byte_mask = 16'hFFFF;
        REFILL: tag_SRAM_byte_mask = {{4{replace_target[3]}},{4{replace_target[2]}},{4{replace_target[1]}},{4{replace_target[0]}}};
        default : tag_SRAM_byte_mask = 16'h0000;
    endcase
end

always_comb begin
    case(state)
        INIT : begin
            tag_SRAM_wdata.way0.state = INVALID;
            tag_SRAM_wdata.way0.tag = 24'h000;
            tag_SRAM_wdata.way1.state = INVALID;
            tag_SRAM_wdata.way1.tag = 24'h000;
            tag_SRAM_wdata.way2.state = INVALID;
            tag_SRAM_wdata.way2.tag = 24'h000;
            tag_SRAM_wdata.way3.state = INVALID;
            tag_SRAM_wdata.way3.tag = 24'h000;
        end
        REFILL:begin
            // The byte mask selects the target way, so every way input may
            // carry the same updated tag and state without extra input muxing.
            tag_SRAM_wdata.way0.state = EXCLUSIVE;
            tag_SRAM_wdata.way0.tag   = {2'b00,addr[31:10]};
            
            tag_SRAM_wdata.way1.state = EXCLUSIVE;
            tag_SRAM_wdata.way1.tag   = {2'b00,addr[31:10]};
            
            tag_SRAM_wdata.way2.state = EXCLUSIVE;
            tag_SRAM_wdata.way2.tag   = {2'b00,addr[31:10]};
            
            tag_SRAM_wdata.way3.state = EXCLUSIVE;
            tag_SRAM_wdata.way3.tag   = {2'b00,addr[31:10]};
        end
        default : tag_SRAM_wdata = 128'd0;
        //default : tag_SRAM_wdata = tag_SRAM_wdata_ff;
    endcase
end



always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)begin
        tag_SRAM_rdata_ff <= 128'd0;       
    end else begin
        if(state == LOOKUP)
            tag_SRAM_rdata_ff <= tag_SRAM_rdata_comb;
    end
end

always_comb begin
    if(sram_idle_gating)begin
        if(state == INIT || state == REFILL || state_next == LOOKUP)
            tag_SRAM_cen = 1'b0;
        else
            tag_SRAM_cen = 1'b1;
    end else begin
        tag_SRAM_cen = 1'b0;
    end
end

assign data_SRAM_wdata = {RDATA_buffer[3],RDATA_buffer[2],RDATA_buffer[1],RDATA_buffer[0]};

assign data_SRAM_wen = (state == REFILL) ? ~replace_target : 4'b1111;
always_comb begin
    if(sram_idle_gating)begin
        if(state_next == LOOKUP)
            data_SRAM_cen = 4'b0000;
        else if(state == REFILL)
            data_SRAM_cen = data_SRAM_wen;
        else
            data_SRAM_cen = 4'b1111;
    end else begin
        data_SRAM_cen = 4'b0000;
    end
end

//=======================================================
//                   SRAM
//=======================================================

SRAM_WRAPPER_64x128 tag_SRAM(.clk(clk),.cen(tag_SRAM_cen),.wen(tag_SRAM_wen),.byte_mask(tag_SRAM_byte_mask),.addr(SRAM_addr),.wdata(tag_SRAM_wdata),.rdata(tag_SRAM_rdata_comb));
SRAM_WRAPPER_64x128 way0_SRAM(.clk(clk),.cen(data_SRAM_cen[0]),.wen(data_SRAM_wen[0]),.byte_mask(16'hFFFF),.addr(SRAM_addr),.wdata(data_SRAM_wdata),.rdata(cacheline_data[0]));
SRAM_WRAPPER_64x128 way1_SRAM(.clk(clk),.cen(data_SRAM_cen[1]),.wen(data_SRAM_wen[1]),.byte_mask(16'hFFFF),.addr(SRAM_addr),.wdata(data_SRAM_wdata),.rdata(cacheline_data[1]));
SRAM_WRAPPER_64x128 way2_SRAM(.clk(clk),.cen(data_SRAM_cen[2]),.wen(data_SRAM_wen[2]),.byte_mask(16'hFFFF),.addr(SRAM_addr),.wdata(data_SRAM_wdata),.rdata(cacheline_data[2]));
SRAM_WRAPPER_64x128 way3_SRAM(.clk(clk),.cen(data_SRAM_cen[3]),.wen(data_SRAM_wen[3]),.byte_mask(16'hFFFF),.addr(SRAM_addr),.wdata(data_SRAM_wdata),.rdata(cacheline_data[3]));

endmodule
