module CACHE_DATA (
    input  logic         clk,
    input  logic         rst_n,     
    input  logic         cpu_req_LS_valid,   //comb
    input  logic [31:0]  cpu_req_addr,
	input  logic [31:0]  cpu_wdata,	
	input  logic 		 cpu_we,  // 1 means write ,0 means read
	input  logic [3:0] 	 cpu_wstrb,
	input  logic 		 cpu_req_flush,
    output logic         cpu_req_ready,  //comb 1 means CPU can send command to cache, 0 means not
    output logic         cpu_rsp_load_ack, //comb
    output logic [31:0]  cpu_rsp_data,
	output logic         cpu_rsp_flush_ack, //sequential
	output logic 		 cpu_rsp_store_ack, //comb
	output logic 		 cpu_acc_fault,
	output logic 		 b_err_bit,
    INF_AXI.PATTERN inf_axi
);
import CACHE_PKG::*;

parameter VB_DEPTH = 2;
parameter SRAM_IDLE_GATING = 1'b1;
//=======================================================

//                   Reg/Wire
//=======================================================

cache_data_state state,state_next;
logic [5:0] index;
cache_set_D_tag tag_SRAM_rdata_comb;
cache_set_D_tag tag_SRAM_rdata_ff;
logic [15:0] tag_SRAM_byte_mask;
logic tag_SRAM_wen;
logic [5:0]SRAM_addr;
cacheline cacheline_data [3:0];
cacheline cacheline_data_hit;
logic [31:0] target_cache_word; 
word word_out;
cache_set_D_tag tag_SRAM_wdata,tag_SRAM_wdata_ff;
logic [2:0]LRU[63:0];
logic [2:0]LRU_current_next,LRU_current;
logic [3:0]LRU_replace_target;
logic [3:0] replace_target;
logic [21:0] replace_target_tag;
mesi_state_D_tag replace_target_state;
cacheline replace_target_cacheline;

logic [5:0] cnt_init;

logic tag_equal[3:0];
logic [3:0]tag_valid_and_equal;
logic sram_hit;
logic hit,hit_ff;

logic [3:0]data_SRAM_wen;
logic [127:0] data_SRAM_wdata;
logic [15:0]data_SRAM_bytemask;

logic sram_idle_gating;
logic [3:0] data_SRAM_cen;
logic tag_SRAM_cen;


logic cpu_we_ff;

logic transaction_not_done; //indicate transaction have not done 
//=======================================================
//                   tag valid bits 
//=======================================================
mesi_state_D_tag mesi_state_ff[63:0][3:0];
mesi_state_D_tag mesi_state_comb[63:0][3:0];
//=======================================================
//                   from cpu input  
//=======================================================

logic [31:0] addr;
logic [31:0] wdata;
logic [3:0] wstrb;
logic we;


//=======================================================
//                   FLUSH 
//=======================================================
logic flush;
logic [8:0] cnt_flush;
cacheline cacheline_flush;
logic [31:0] addr_flush;
logic [5:0] index_flush;
cache_set_D_tag cache_set_flush;
mesi_state_D_tag mesi_state_flush;
logic flush_current_cacheline;
logic flush_entry_done;

//=======================================================
//                   Victim buffer  depth = 2
//=======================================================
Victim_Buffer vb[VB_DEPTH-1:0];

logic [1:0] vb_tptr,vb_awptr,vb_wptr,vb_bptr;  //tail pointer (for cache writing data to vb),AW pointer, W pointer, B pointer
logic vb_full,vb_empty;
logic vb_hit;
logic [1:0]vb_equal;
logic vb_push;  //determine if pushing the data to victim buffer 

//=======================================================
//                   Store buffer  depth = 4
//=======================================================
Store_Buffer sb[3:0];
Store_Buffer sb_pop_current;
logic [3:0] sb_pop_way;
logic [31:0] sb_pop_addr;
logic [3:0] sb_pop_wstrb;
word sb_pop_data; 
logic [2:0] sb_wptr,sb_rptr;
logic [31:0] sb_addr;
logic sb_full,sb_empty;
logic sb_hit;
logic [3:0]sb_equal;
logic [31:0] sb_hit_data;
logic [3:0]  sb_hit_wstrb;
logic sb_push;
logic sb_pop;
logic sb_overwrite;

//=======================================================
//                   AXI Reg/Wire
//=======================================================
logic AR_Handshake;
logic [1:0]cnt_read,cnt_write,cnt_write_comb;
logic [31:0]RDATA_buffer[3:0];
logic [31:0]WDATA_wire;
logic [3:0] cnt_WID;
logic [2:0] ARID_local;

//logic AWVALID;

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
        WAIT:   if(cpu_req_flush && cpu_req_ready)
					state_next = FLUSH;
				else if(cpu_req_LS_valid && cpu_req_ready)
                    state_next = LOOKUP;
                else
                    state_next = WAIT;
        LOOKUP: 
				if(sb_full) begin
					state_next = STORE;
				end 
				else if (transaction_not_done) begin
					// Busy path: finish the active CPU transaction before returning idle.
					if(hit || cpu_acc_fault) begin
						if(cpu_req_flush && cpu_req_ready)
							state_next = FLUSH;
						else
							state_next = LOOKUP;
					end else begin
						if(sb_empty) state_next = KICK_VICTIM;
						else         state_next = STORE;
					end
				end 
				else begin
					// Idle path with fast wake-up for a newly accepted request.
					if(cpu_req_flush && cpu_req_ready)
						state_next = FLUSH;
					else if (cpu_req_LS_valid && cpu_req_ready) begin
						// Stay in LOOKUP so the new request can be processed next cycle.
						state_next = LOOKUP;
					end 
					else if(!sb_empty) begin
						// Drain buffered stores when no foreground request is active.
						state_next = STORE;
					end 
					else begin
						// No foreground or background work remains.
						state_next = WAIT;
					end
				end
				/*
				if(sb_full)
					state_next = STORE;
				else begin
					if(hit)begin
						if(!cpu_req_LS_valid && cpu_req_ready)
							if(sb_empty)
								state_next = WAIT;
							else
								state_next = STORE;
						else
							state_next = LOOKUP;
					end else begin
						if(transaction_not_done)begin
							if(sb_empty)
								state_next = KICK_VICTIM;
							else
								state_next = STORE;
						end else begin
							state_next = WAIT;
						end
					end
				end 
				*/				
				/*
				 * transaction_not_done prevents stale registered request fields from
				 * starting a new miss after the current transaction has completed.
				 * It also avoids a ghost miss if a future coherence or DMA invalidation
				 * changes the cached line while the input registers retain the old address.
				 */
				
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
		STORE:begin
			//if(cpu_req_LS_valid && cpu_req_ready)
				//state_next = LOOKUP;
			if(!sb_empty)
				state_next = STORE;
			else if(flush)
				state_next = FLUSH;
			else
				state_next = RETRIEVE;
		end
        ERROR: begin
            state_next = ERROR;
            //$display("                    DATA CACHE ERROR                   ");
            //$finish;
        end
		KICK_VICTIM: begin
			if(!vb_full)
				state_next = AXI_READ;
			else
				state_next = KICK_VICTIM;
		end
		FLUSH:begin
			if(!sb_empty)
				state_next = STORE;
			else if(cnt_flush == 256 && vb_empty)
				state_next = WAIT;
			else if(cnt_flush != 256)
				state_next = FLUSH_SRAM;
			else                        // vb is not empty and cnt_flush = 256,waiting vb writing data to DRAM
				state_next = FLUSH;
		end
		FLUSH_SRAM:begin
			if((cnt_flush == 256) || (flush_entry_done && (cnt_flush[1:0] == 2'b11)))
				state_next = FLUSH;
			else
				state_next = FLUSH_SRAM;
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
//                   input DFF
//=======================================================

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)begin
        addr <= 32'd0;
		wdata <= 32'd0;
		wstrb <= 4'd0;
		we <= 0;
    end else begin
        if(cpu_req_LS_valid && cpu_req_ready && !(cpu_req_addr < 32'h0001_0000 || cpu_req_addr > 32'h0001_FFFC))begin
            addr <= cpu_req_addr;
			wdata <= cpu_wdata;
			wstrb <= cpu_wstrb;
			we <= cpu_we;
		end
    end
end

//=======================================================
//                   indicate transaction done
//=======================================================
always_ff@(posedge clk,negedge rst_n)begin
	if(!rst_n)begin
		transaction_not_done <= 0;
	end else begin
		if(cpu_req_LS_valid && cpu_req_ready)
			transaction_not_done <=1;
		else begin
			if(transaction_not_done)begin
				if((we && (sb_push || sb_overwrite)) || (!we && hit && (state == LOOKUP)) || cpu_acc_fault) 
					transaction_not_done <= 0;
			end			
		end
	end
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
    else if(cpu_req_LS_valid && cpu_req_ready && (cpu_req_addr < 32'h0001_0000 || cpu_req_addr > 32'h0001_FFFC))
        cpu_acc_fault <= 1;
    else
        cpu_acc_fault <= 0;
end



always_comb begin
    case(state)
        INIT :  cpu_req_ready = 0;
        WAIT :  cpu_req_ready = 1;
        LOOKUP :begin
				/*
				if(sb_full || (we && vb_hit))
					cpu_req_ready = 0;
				else 
					cpu_req_ready = hit;
				*/
				if(sb_full || (we && vb_hit)) begin
					// A full store buffer or victim-buffer conflict must stall the request.
					cpu_req_ready = 0;
				end 
				else if (transaction_not_done) begin
					// While busy, accept the next request only on a hit or access fault.
					cpu_req_ready = hit || cpu_acc_fault; 
				end 
				else begin
					// When idle, the cache can immediately accept a new request.
					cpu_req_ready = 1; 
				end
			end
        default: cpu_req_ready = 0;
    endcase
    
end


always_comb begin
    case(state)
        LOOKUP : cpu_rsp_load_ack = (!we & hit & transaction_not_done) && !cpu_acc_fault ;
        default : cpu_rsp_load_ack = 0;
    endcase
end
/*
always_ff@(posedge clk,negedge rst_n)begin
	if(!rst_n)
		cpu_rsp_store_ack <= 0;
	else if(sb_push || sb_overwrite)
		cpu_rsp_store_ack <= 1;
	else
		cpu_rsp_store_ack <= 0;
end 
*/
assign cpu_rsp_store_ack = (sb_push | sb_overwrite) && !cpu_acc_fault;

assign cpu_rsp_data = word_out;

assign word_out[7:0]   = (sb_hit && sb_hit_wstrb[0]) ? sb_hit_data[7:0]   : target_cache_word[7:0];
assign word_out[15:8]  = (sb_hit && sb_hit_wstrb[1]) ? sb_hit_data[15:8]  : target_cache_word[15:8];
assign word_out[23:16] = (sb_hit && sb_hit_wstrb[2]) ? sb_hit_data[23:16] : target_cache_word[23:16];
assign word_out[31:24] = (sb_hit && sb_hit_wstrb[3]) ? sb_hit_data[31:24] : target_cache_word[31:24];

//assign cpu_rsp_flush_ack = ((state == FLUSH) &&
always_ff@(posedge clk,negedge rst_n)begin
	if(!rst_n)
		cpu_rsp_flush_ack <= 0;
	else if((state == FLUSH) && (state_next == WAIT))
		cpu_rsp_flush_ack <= 1;
	else
		cpu_rsp_flush_ack <= 0;
end 

//=======================================================
//                   tag mesi state
//=======================================================
always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)begin
        for(int i=0;i<64;i++)
			for(int j=0;j<4;j++)
				mesi_state_ff[i][j] <= DATA_INVALID;
    end else begin
        case(state)
			LOOKUP:begin
				if ((sram_hit | sb_hit) && we && transaction_not_done && !cpu_acc_fault) begin
                    if (tag_valid_and_equal[0]) mesi_state_ff[addr[9:4]][0] <= DATA_MODIFIED;
                    if (tag_valid_and_equal[1]) mesi_state_ff[addr[9:4]][1] <= DATA_MODIFIED;
                    if (tag_valid_and_equal[2]) mesi_state_ff[addr[9:4]][2] <= DATA_MODIFIED;
                    if (tag_valid_and_equal[3]) mesi_state_ff[addr[9:4]][3] <= DATA_MODIFIED;
                end
			end
			REFILL:begin
				
				if (replace_target[3]) mesi_state_ff[addr[9:4]][3] <= DATA_EXCLUSIVE;
				if (replace_target[2]) mesi_state_ff[addr[9:4]][2] <= DATA_EXCLUSIVE;
				if (replace_target[1]) mesi_state_ff[addr[9:4]][1] <= DATA_EXCLUSIVE;
				if (replace_target[0]) mesi_state_ff[addr[9:4]][0] <= DATA_EXCLUSIVE;

			end
			FLUSH_SRAM:begin
				if (cnt_flush != 256 && (vb_push || !flush_current_cacheline )) begin
					mesi_state_ff[cnt_flush[7:2]][cnt_flush[1:0]] <= DATA_INVALID;
				end
			end
		endcase
    end
end


/*
always_comb begin
	case(state)
			REFILL:begin
				mesi_state_comb = mesi_state_ff;
				case(replace_target)
					4'b1000: mesi_state_comb[addr[9:4]][3] = DATA_EXCLUSIVE;
					4'b0100: mesi_state_comb[addr[9:4]][2] = DATA_EXCLUSIVE;
					4'b0010: mesi_state_comb[addr[9:4]][1] = DATA_EXCLUSIVE;
					4'b0001: mesi_state_comb[addr[9:4]][0] = DATA_EXCLUSIVE;
				endcase
			end
		default : mesi_state_comb = mesi_state_ff;
	endcase
end
*/
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
    tag_valid_and_equal[0] = (state == LOOKUP) && tag_equal[0] && (mesi_state_ff[addr[9:4]][0] != DATA_INVALID);
    tag_valid_and_equal[1] = (state == LOOKUP) && tag_equal[1] && (mesi_state_ff[addr[9:4]][1] != DATA_INVALID);
    tag_valid_and_equal[2] = (state == LOOKUP) && tag_equal[2] && (mesi_state_ff[addr[9:4]][2] != DATA_INVALID);
    tag_valid_and_equal[3] = (state == LOOKUP) && tag_equal[3] && (mesi_state_ff[addr[9:4]][3] != DATA_INVALID);
end


assign sram_hit = tag_valid_and_equal[0] | tag_valid_and_equal[1] | tag_valid_and_equal[2] | tag_valid_and_equal[3];
assign hit = (sram_hit | vb_hit | sb_hit) && !cpu_acc_fault;



always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)
        hit_ff <= 0;
    else if(state == LOOKUP)
		hit_ff <= hit;
end

//=======================================================
//                   cache line MUX
//=======================================================
always_comb begin
	if(vb_hit)begin
		case(vb_equal)
			4'b10 : cacheline_data_hit = vb[1].data;
			4'b01 : cacheline_data_hit = vb[0].data;
			default : cacheline_data_hit = 128'd0;
		endcase
	end else begin
		case(tag_valid_and_equal)
			4'b1000 : cacheline_data_hit = cacheline_data[3];
			4'b0100 : cacheline_data_hit = cacheline_data[2];
			4'b0010 : cacheline_data_hit = cacheline_data[1];
			4'b0001 : cacheline_data_hit = cacheline_data[0];
			default : cacheline_data_hit = 128'd0;
		endcase
	end
end

always_comb begin
    case(addr[3:2])
        2'b00 : target_cache_word = cacheline_data_hit.word0;
        2'b01 : target_cache_word = cacheline_data_hit.word1;
        2'b10 : target_cache_word = cacheline_data_hit.word2;
        2'b11 : target_cache_word = cacheline_data_hit.word3;
		default : target_cache_word = 'd0;
    endcase
end

assign index = addr[9:4];

/*always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)begin
        cpu_we_ff <= 0;       
    end else begin
        if(cpu_req_LS_valid && cpu_req_ready)
			cpu_we_ff <= 0;
    end
end
*/
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
				if(sram_hit && transaction_not_done && !cpu_acc_fault)
                    LRU[addr[9:4]] <= LRU_current_next;
            end
			REFILL: LRU[addr[9:4]] <= LRU_current_next;
            default : LRU <= LRU;
        endcase
    end
end


assign LRU_current = LRU[addr[9:4]];
    

always_comb begin
    case(state)
        LOOKUP : begin
            if(sram_hit && transaction_not_done)
                case(tag_valid_and_equal)
                    4'b1000 : begin
                        LRU_current_next[0] = 1'b1;             //access way3
                        LRU_current_next[1] = LRU_current[1];
                        LRU_current_next[2] = 1'b1;
                    end
                    4'b0100 : begin
                        LRU_current_next[0] = 1'b1;             //access way2
                        LRU_current_next[1] = LRU_current[1];
                        LRU_current_next[2] = 1'b0;
                    end
                    4'b0010 : begin
                        LRU_current_next[0] = 1'b0;             //access way1
                        LRU_current_next[1] = 1'b1;
                        LRU_current_next[2] = LRU_current[2];
                    end
                    4'b0001 : begin
                        LRU_current_next[0] = 1'b0;             //access way0
                        LRU_current_next[1] = 1'b0;
                        LRU_current_next[2] = LRU_current[2];
                    end
                    default : LRU_current_next = LRU_current;
                endcase
            else
                LRU_current_next = LRU_current;
        end
        REFILL:begin
            /*LRU_current_next[0] = ~LRU_current[0];
            if(~LRU_current[0])begin
                LRU_current_next[1] = LRU_current[1];
                LRU_current_next[2] = ~LRU_current[2];
            end else begin
                LRU_current_next[1] = ~LRU_current[1];
                LRU_current_next[2] = LRU_current[2];
            end*/
			if(mesi_state_ff[addr[9:4]][0] == DATA_INVALID)begin
				LRU_current_next[0] = 1'b0;             //access way0
				LRU_current_next[1] = 1'b0;
				LRU_current_next[2] = LRU_current[2];
			end else if(mesi_state_ff[addr[9:4]][1] == DATA_INVALID) begin
				LRU_current_next[0] = 1'b0;             //access way1
				LRU_current_next[1] = 1'b1;
				LRU_current_next[2] = LRU_current[2];
			end else if(mesi_state_ff[addr[9:4]][2] == DATA_INVALID) begin
				LRU_current_next[0] = 1'b1;             //access way2
				LRU_current_next[1] = LRU_current[1];
				LRU_current_next[2] = 1'b0;
			end	else if(mesi_state_ff[addr[9:4]][3] == DATA_INVALID) begin
				LRU_current_next[0] = 1'b1;             //access way3
				LRU_current_next[1] = LRU_current[1];
				LRU_current_next[2] = 1'b1;
			end else begin
				case(replace_target)
                    4'b1000 : begin LRU_current_next[0] = 1'b1; LRU_current_next[1] = LRU_current[1]; LRU_current_next[2] = 1'b1; end
                    4'b0100 : begin LRU_current_next[0] = 1'b1; LRU_current_next[1] = LRU_current[1]; LRU_current_next[2] = 1'b0; end
                    4'b0010 : begin LRU_current_next[0] = 1'b0; LRU_current_next[1] = 1'b1; LRU_current_next[2] = LRU_current[2]; end
                    4'b0001 : begin LRU_current_next[0] = 1'b0; LRU_current_next[1] = 1'b0; LRU_current_next[2] = LRU_current[2]; end
					default : LRU_current_next = LRU_current;
                endcase
				/*
				LRU_current_next[0] = ~LRU_current[0];
				if(~LRU_current[0])begin
					LRU_current_next[1] = LRU_current[1];
					LRU_current_next[2] = ~LRU_current[2];
				end else begin
					LRU_current_next[1] = ~LRU_current[1];
					LRU_current_next[2] = LRU_current[2];
				end*/
			end
				
        end
        default : LRU_current_next = LRU_current;
    endcase
end

always_comb begin
    if(~LRU_current[0])begin
        if(~LRU_current[2])
            LRU_replace_target = 4'b1000;
        else
            LRU_replace_target = 4'b0100;
    end else begin
        if(~LRU_current[1])
            LRU_replace_target = 4'b0010;
        else
            LRU_replace_target = 4'b0001;
    end
end

always_comb begin
    if(mesi_state_ff[addr[9:4]][0] == DATA_INVALID)
        replace_target = 4'b0001;
    else if(mesi_state_ff[addr[9:4]][1] == DATA_INVALID)
        replace_target = 4'b0010;
    else if(mesi_state_ff[addr[9:4]][2] == DATA_INVALID)
        replace_target = 4'b0100;
    else if(mesi_state_ff[addr[9:4]][3] == DATA_INVALID)
        replace_target = 4'b1000;
    else    
        replace_target = LRU_replace_target;
end

always_comb begin
    case(replace_target)
		4'b1000 : replace_target_tag = tag_SRAM_rdata_comb.way3.tag[21:0];
		4'b0100 : replace_target_tag = tag_SRAM_rdata_comb.way2.tag[21:0];
		4'b0010 : replace_target_tag = tag_SRAM_rdata_comb.way1.tag[21:0];
		4'b0001 : replace_target_tag = tag_SRAM_rdata_comb.way0.tag[21:0];
		default : replace_target_tag = 22'd0;
	endcase
end

always_comb begin
    case(replace_target)
		4'b1000 : replace_target_state = mesi_state_ff[addr[9:4]][3];
		4'b0100 : replace_target_state = mesi_state_ff[addr[9:4]][2];
		4'b0010 : replace_target_state = mesi_state_ff[addr[9:4]][1];
		4'b0001 : replace_target_state = mesi_state_ff[addr[9:4]][0];
		default : replace_target_state = DATA_INVALID;
	endcase
end

always_comb begin
    case(replace_target)
		4'b1000 : replace_target_cacheline = cacheline_data[3];
		4'b0100 : replace_target_cacheline = cacheline_data[2];
		4'b0010 : replace_target_cacheline = cacheline_data[1];
		4'b0001 : replace_target_cacheline = cacheline_data[0];
		default : replace_target_cacheline = 128'd0;
	endcase
end

//=======================================================
//                   Flush logics
//=======================================================
assign flush_entry_done = (state == FLUSH_SRAM) && (vb_push || !flush_current_cacheline);
always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)begin
        flush <= 0;
    end else begin
		if(cpu_rsp_flush_ack)
			flush <= 0;
        else if(cpu_req_flush && cpu_req_ready)begin
            flush <= 1;
		end
    end
end

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)begin
        cnt_flush <= 0;
    end else begin
        if((cpu_req_flush && cpu_req_ready) || (state == FLUSH && state_next == WAIT))
			cnt_flush <= 0;
		else if((state == FLUSH_SRAM) && (vb_push || !flush_current_cacheline ))
			cnt_flush <= cnt_flush + 1;
    end
end


assign mesi_state_flush = mesi_state_ff[cnt_flush[7:2]][cnt_flush[1:0]];
assign index_flush = cnt_flush[7:2];
assign cache_set_flush = tag_SRAM_rdata_comb;
assign flush_current_cacheline = (state == FLUSH_SRAM) && (mesi_state_flush == DATA_MODIFIED) && (cnt_flush != 256);
always_comb begin
	case(cnt_flush[1:0])
		2'd0 : addr_flush = {cache_set_flush.way0.tag[21:0],index_flush,4'd0};
		2'd1 : addr_flush = {cache_set_flush.way1.tag[21:0],index_flush,4'd0};
		2'd2 : addr_flush = {cache_set_flush.way2.tag[21:0],index_flush,4'd0};
		2'd3 : addr_flush = {cache_set_flush.way3.tag[21:0],index_flush,4'd0};
	endcase
end

assign cacheline_flush = cacheline_data[cnt_flush[1:0]];


//=======================================================
//                   Store-buffer
//=======================================================
assign sb_full = ((sb_wptr[2]!= sb_rptr[2]) && (sb_wptr[1:0] == sb_rptr[1:0]));
assign sb_empty = (sb_wptr == sb_rptr);
assign sb_hit = (|sb_equal);
assign sb_push = !sb_full && sram_hit && (state==LOOKUP) && we && !sb_hit && transaction_not_done && !cpu_acc_fault;
assign sb_overwrite = (state == LOOKUP) && we && sb_hit && transaction_not_done && !cpu_acc_fault;
assign sb_pop = (state == STORE) && !sb_empty;

assign sb_pop_current = sb[sb_rptr[1:0]];
assign sb_pop_way = sb_pop_current.way;
assign sb_pop_addr = sb_pop_current.addr;
assign sb_pop_data = sb_pop_current.data;
assign sb_pop_wstrb = sb_pop_current.wstrb;

always_comb begin
	for(int i = 0;i < 4 ;i++)
		sb_equal[i] = (sb[i].addr == addr) && sb[i].valid_bit;
end

always_comb begin
	case(sb_equal)
        4'b0001: begin sb_hit_data = sb[0].data; sb_hit_wstrb = sb[0].wstrb; end
        4'b0010: begin sb_hit_data = sb[1].data; sb_hit_wstrb = sb[1].wstrb; end
        4'b0100: begin sb_hit_data = sb[2].data; sb_hit_wstrb = sb[2].wstrb; end
        4'b1000: begin sb_hit_data = sb[3].data; sb_hit_wstrb = sb[3].wstrb; end
        default: begin sb_hit_data = 32'd0;      sb_hit_wstrb = 4'd0;        end
    endcase
end

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)begin
        sb_wptr <= 0;    
    end else begin
        if(sb_push)
			sb_wptr <= sb_wptr + 1;
    end
end

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)begin
        sb_rptr <= 0;    
    end else begin
        if(sb_pop)
			sb_rptr <= sb_rptr + 1;
    end
end

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)begin
        for(int i=0;i<4;i++)
			sb[i] <= {BUFFER_INVALID,4'd0,4'd0,32'd0,32'd0};
    end else begin
			if(sb_push)
				sb[sb_wptr[1:0]] <= {BUFFER_VALID,tag_valid_and_equal,wstrb,addr,wdata};
			else if(sb_pop)
				sb[sb_rptr[1:0]] <= {BUFFER_INVALID,4'd0,4'd0,32'd0,32'd0};
			else if(sb_overwrite)
				case(sb_equal)
					4'b0001 :begin 
							sb[0].wstrb <= sb[0].wstrb | wstrb; 
							if (wstrb[0]) sb[0].data[7:0]   <= wdata[7:0];
							if (wstrb[1]) sb[0].data[15:8]  <= wdata[15:8];
							if (wstrb[2]) sb[0].data[23:16] <= wdata[23:16];
							if (wstrb[3]) sb[0].data[31:24] <= wdata[31:24];
						end 
					4'b0010 :begin 
							sb[1].wstrb <= sb[1].wstrb | wstrb; 
							if (wstrb[0]) sb[1].data[7:0]   <= wdata[7:0];
							if (wstrb[1]) sb[1].data[15:8]  <= wdata[15:8];
							if (wstrb[2]) sb[1].data[23:16] <= wdata[23:16];
							if (wstrb[3]) sb[1].data[31:24] <= wdata[31:24];
						end 
					4'b0100 :begin 
							sb[2].wstrb <= sb[2].wstrb | wstrb; 
							if (wstrb[0]) sb[2].data[7:0]   <= wdata[7:0];
							if (wstrb[1]) sb[2].data[15:8]  <= wdata[15:8];
							if (wstrb[2]) sb[2].data[23:16] <= wdata[23:16];
							if (wstrb[3]) sb[2].data[31:24] <= wdata[31:24];
						end 
					4'b1000 :begin 
							sb[3].wstrb <= sb[3].wstrb | wstrb; 
							if (wstrb[0]) sb[3].data[7:0]   <= wdata[7:0];
							if (wstrb[1]) sb[3].data[15:8]  <= wdata[15:8];
							if (wstrb[2]) sb[3].data[23:16] <= wdata[23:16];
							if (wstrb[3]) sb[3].data[31:24] <= wdata[31:24];
						end 
				endcase
    end
end


//=======================================================
//                   Victim-buffer
//=======================================================

assign vb_full = (vb_tptr[1] != vb_bptr[1] && vb_tptr[0] == vb_bptr[0]);
assign vb_empty = (vb_tptr == vb_bptr);
assign vb_hit = ((| vb_equal));
assign vb_push = (!hit_ff && !vb_full && (replace_target_state == DATA_MODIFIED) && (state == KICK_VICTIM)) || ((flush_current_cacheline && !vb_full));

always_comb begin
	for(int i = 0;i < VB_DEPTH ;i++)
		vb_equal[i] = (vb[i].addr == addr[31:4]) && vb[i].valid_bit;
end

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)begin
        vb_tptr <= 0;    
    end else begin
        if(vb_push && ((state == KICK_VICTIM) || state == FLUSH_SRAM))
			vb_tptr <= vb_tptr + 1;
    end
end

/*always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)begin
        for(int i=0;i<VB_DEPTH;i++)
			vb_state[i] <= NOT_HANDSHAKE;   
    end else begin
        
    end
end*/



always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)begin
        for(int i=0;i<VB_DEPTH;i++)
			vb[i] <= {BUFFER_INVALID,3'd0,28'd0,128'd0};
    end else begin
			if(state == KICK_VICTIM && vb_push)
				vb[vb_tptr[0]] <= {BUFFER_VALID,1'b0,vb_awptr,replace_target_tag,addr[9:4],replace_target_cacheline};
			else if(state == FLUSH_SRAM && vb_push)
				vb[vb_tptr[0]] <= {BUFFER_VALID,1'b0,vb_awptr,addr_flush[31:4],cacheline_flush};
			if(inf_axi.BVALID && inf_axi.BREADY)
				vb[vb_bptr[0]] <= {BUFFER_INVALID,159'd0};
    end
end

//=======================================================
//                   AXI-READ
//=======================================================
assign inf_axi.ARSIZE = 3'd2;
assign inf_axi.ARLEN = 8'd3;
assign inf_axi.ARBURST = 2'b01;
assign inf_axi.ARID = {1'b0,ARID_local};

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
		else 
			inf_axi.RREADY <= 0;
    end
end

//=======================================================
//                   AXI-WRITE
//=======================================================
// Constant fields — driven by assign, no need for FF
assign inf_axi.AWLEN   = 8'd3;
assign inf_axi.AWSIZE  = 3'd2;
assign inf_axi.AWBURST = 2'b01;
assign inf_axi.WSTRB   = 4'b1111;

// AW channel's control 
always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)
        inf_axi.AWVALID <= 1'd0;       
    else begin
		if(inf_axi.AWVALID && inf_axi.AWREADY)
			inf_axi.AWVALID <= 0;
		else if(!inf_axi.AWVALID && (vb_tptr != vb_awptr)) 
            inf_axi.AWVALID <= 1;
	end	
end

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)
        vb_awptr <= 2'd0;       
    else begin
		if(inf_axi.AWVALID && inf_axi.AWREADY)
			vb_awptr <= vb_awptr + 1;
	end	
end

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)
        inf_axi.AWADDR <= 'd0;       
    else begin
		if(!inf_axi.AWVALID && (vb_tptr != vb_awptr)) 
			inf_axi.AWADDR <= {vb[vb_awptr[0]].addr,4'd0};
	end	
end

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)
        inf_axi.AWID <= 'd0;       
    else begin
		if(!inf_axi.AWVALID && (vb_tptr != vb_awptr)) 
			inf_axi.AWID <= {1'b0,vb[vb_awptr[0]].ID};
	end	
end



// W channel's control 

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)
        vb_wptr <= 2'd0;       
    else begin
		if(inf_axi.WVALID && inf_axi.WREADY && inf_axi.WLAST)
			vb_wptr <= vb_wptr + 1;
	end	
end

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)
        inf_axi.WVALID <= 1'd0;       
    else begin
		if(inf_axi.WVALID && inf_axi.WREADY && inf_axi.WLAST)
			inf_axi.WVALID <= 0;
		else if(!inf_axi.WVALID && (vb_tptr != vb_wptr))
			inf_axi.WVALID <= 1;
	end	
end

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)
        inf_axi.WDATA <= 1'd0;       
    else begin
		inf_axi.WDATA <= WDATA_wire;
	end	
end

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)
        cnt_write <= 2'd0;       
    else begin
		cnt_write <= cnt_write_comb;
	end	
end

always_comb begin
	if(inf_axi.WVALID && inf_axi.WREADY)
		cnt_write_comb = cnt_write + 1;
	else if(!inf_axi.WVALID && (vb_tptr != vb_wptr))
		cnt_write_comb = 0;
	else
		cnt_write_comb = cnt_write;
end

always_comb begin
	case(cnt_write_comb)
		2'd0: WDATA_wire = vb[vb_wptr[0]].data.word0;
		2'd1: WDATA_wire = vb[vb_wptr[0]].data.word1;
		2'd2: WDATA_wire = vb[vb_wptr[0]].data.word2;
		2'd3: WDATA_wire = vb[vb_wptr[0]].data.word3;
	endcase
end

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)
        inf_axi.WLAST <= 1'd0;       
    else begin
		if(inf_axi.WVALID && inf_axi.WREADY && inf_axi.WLAST)
			inf_axi.WLAST <= 0;
		else if(inf_axi.WVALID && inf_axi.WREADY && (cnt_write == 2))
			inf_axi.WLAST <= 1;
	end	
end

// B channel's control 

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)
        inf_axi.BREADY <= 1'd0;       
    else begin
		if(inf_axi.BVALID && inf_axi.BREADY)
			inf_axi.BREADY <= 0;
		else if(!inf_axi.BREADY && (vb_tptr != vb_bptr))
			inf_axi.BREADY <= 1;
	end	
end

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)
        vb_bptr <= 2'd0;       
    else begin
		if(inf_axi.BVALID && inf_axi.BREADY)
			vb_bptr <= vb_bptr + 1;
	end	
end

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)
        b_err_bit <= 1'd0;       
    else begin
		if( (inf_axi.BVALID && inf_axi.BREADY && ((inf_axi.BRESP != 2'b00) || (inf_axi.BID != {1'b0,vb[vb_bptr[0]].ID}))) ||
			(inf_axi.RVALID && inf_axi.RREADY && (inf_axi.RID != ARID_local)))
			b_err_bit <= 1'd1;
	end	
end




//=======================================================
//                   SRAM control
//=======================================================
//tag_SRAM 's address
assign sram_idle_gating = SRAM_IDLE_GATING;
always_comb begin
    case(state)
        INIT: SRAM_addr = cnt_init;
        WAIT: SRAM_addr = cpu_req_addr[9:4];
        LOOKUP: begin
            if(cpu_req_LS_valid && cpu_req_ready)
				if(cpu_req_addr < 32'h0001_0000 || cpu_req_addr > 32'h0001_FFFC)
                    SRAM_addr = addr[9:4];
                else
                    SRAM_addr = cpu_req_addr[9:4];
            else
                SRAM_addr = addr[9:4];
        end
		STORE: SRAM_addr = sb_pop_addr[9:4];
		FLUSH,
		FLUSH_SRAM: SRAM_addr = index_flush;
        default: SRAM_addr = addr[9:4];
    endcase
end

always_comb begin
    case(state)
        INIT : tag_SRAM_wen = 1'b0;
        REFILL :tag_SRAM_wen = 1'b0;
        default : tag_SRAM_wen = 1'b1;
    endcase
end

always_comb begin
    if(sram_idle_gating)begin
        if(state == INIT || state == REFILL || state == FLUSH_SRAM || state == FLUSH || state_next == LOOKUP ||state == STORE)
            tag_SRAM_cen = 1'b0;
        else
            tag_SRAM_cen = 1'b1;
    end else begin
        tag_SRAM_cen = 1'b0;
    end
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
            tag_SRAM_wdata.way0.dummy = 8'd0;
            tag_SRAM_wdata.way0.tag = 24'h000;
            tag_SRAM_wdata.way1.dummy = 8'd0;
            tag_SRAM_wdata.way1.tag = 24'h000;
            tag_SRAM_wdata.way2.dummy = 8'd0;
            tag_SRAM_wdata.way2.tag = 24'h000;
            tag_SRAM_wdata.way3.dummy = 8'd0;
            tag_SRAM_wdata.way3.tag = 24'h000;
        end
        REFILL:begin
            // The byte mask selects the target way, so every way input may
            // carry the same updated tag fields without extra ordering logic.
            tag_SRAM_wdata.way0.dummy = 8'd0;
            tag_SRAM_wdata.way0.tag   = {2'b00,addr[31:10]};
            
            tag_SRAM_wdata.way1.dummy = 8'd0;
            tag_SRAM_wdata.way1.tag   = {2'b00,addr[31:10]};
            
            tag_SRAM_wdata.way2.dummy = 8'd0;
            tag_SRAM_wdata.way2.tag   = {2'b00,addr[31:10]};
            
            tag_SRAM_wdata.way3.dummy = 8'd0;
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

//assign data_SRAM_wdata = {RDATA_buffer[3],RDATA_buffer[2],RDATA_buffer[1],RDATA_buffer[0]};
always_comb begin
	case(state)
		REFILL: data_SRAM_wdata = {RDATA_buffer[3],RDATA_buffer[2],RDATA_buffer[1],RDATA_buffer[0]};
		STORE: data_SRAM_wdata = {4{sb_pop_data}};
		default : data_SRAM_wdata = 128'd0;
	endcase
end

//assign data_SRAM_wen = (state == REFILL) ? ~replace_target : 4'b1111;
always_comb begin
	case(state)
		REFILL: data_SRAM_wen = ~replace_target;
		STORE: data_SRAM_wen = (!sb_empty) ? ~sb_pop_way : 4'b1111;
		default: data_SRAM_wen = 4'b1111;
	endcase
end
always_comb begin
	case(state)
		REFILL: data_SRAM_bytemask = 16'hFFFF;
		STORE: data_SRAM_bytemask = {12'd0, sb_pop_wstrb} << {sb_pop_addr[3:2], 2'b00};
		default : data_SRAM_bytemask = 16'h0000;
	endcase
end

always_comb begin
    if(sram_idle_gating)begin
		if(state == FLUSH || state == FLUSH_SRAM || state_next == LOOKUP)
			data_SRAM_cen = 4'b0000;
		else if(state == REFILL || state == STORE)
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
SRAM_WRAPPER_64x128 way0_SRAM(.clk(clk),.cen(data_SRAM_cen[0]),.wen(data_SRAM_wen[0]),.byte_mask(data_SRAM_bytemask),.addr(SRAM_addr),.wdata(data_SRAM_wdata),.rdata(cacheline_data[0]));
SRAM_WRAPPER_64x128 way1_SRAM(.clk(clk),.cen(data_SRAM_cen[1]),.wen(data_SRAM_wen[1]),.byte_mask(data_SRAM_bytemask),.addr(SRAM_addr),.wdata(data_SRAM_wdata),.rdata(cacheline_data[1]));
SRAM_WRAPPER_64x128 way2_SRAM(.clk(clk),.cen(data_SRAM_cen[2]),.wen(data_SRAM_wen[2]),.byte_mask(data_SRAM_bytemask),.addr(SRAM_addr),.wdata(data_SRAM_wdata),.rdata(cacheline_data[2]));
SRAM_WRAPPER_64x128 way3_SRAM(.clk(clk),.cen(data_SRAM_cen[3]),.wen(data_SRAM_wen[3]),.byte_mask(data_SRAM_bytemask),.addr(SRAM_addr),.wdata(data_SRAM_wdata),.rdata(cacheline_data[3]));

endmodule
