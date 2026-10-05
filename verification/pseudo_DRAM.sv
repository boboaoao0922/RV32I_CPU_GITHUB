`ifdef FUNC
    `define LAT_MAX 20
    `define LAT_MIN 1
`endif
`ifdef PERF
    `define LAT_MAX 40
    `define LAT_MIN 20
`endif

/*
Memory Map:
DRAM_inst 0x0000_0000 - 0x0000_FFFF
DRAM_data 0x0001_0000 - 0x0001_FFFF
MMIO      0x1000_0000 
*/
module pseudo_DRAM #(
    parameter ID_WIDTH    = 4,
    parameter ADDR_WIDTH  = 32,
    parameter DATA_WIDTH  = 32,
    parameter STRB_WIDTH  = DATA_WIDTH/8, // Auto-calculated WSTRB width (4 bytes for 32-bit data)
	parameter MAX_OUTSTANDING  = 4,
    parameter DRAM_ptr = "dram.dat"
)(
    // Global Signals interface
    input logic clk,
	input logic rst_n,
    INF_AXI.PSUEDO_DRAM inf 
);

// --- Memory Array ---
// Byte-addressable array: 1 Byte per entry, total 32768 entries (32KB)
//logic [7:0] DRAM [0:32767]; 
logic [7:0] DRAM [0:131071]; 
parameter OKAY = 2'b00, SLVERR = 2'b10;


// ==========================================
// FIFO declaration
// ==========================================
typedef struct packed {
    logic [ID_WIDTH-1:0]   id;
    logic [ADDR_WIDTH-1:0] addr;
    logic [7:0]            len;
    logic [2:0]            size;
	logic [1:0]			   burst;
} axi_req_t;

typedef struct packed {
    logic [ID_WIDTH-1:0] id;
    logic [1:0]          resp;
} axi_resp_t;

// ==========================================
// ★ WRITE CHANNEL: FIFOs & Pointers
// ==========================================
axi_req_t  aw_fifo [0:MAX_OUTSTANDING-1];

logic [31:0] cnt_w_delay_fifo [0:MAX_OUTSTANDING-1];
logic [9:0] w_delay_fifo [0:MAX_OUTSTANDING-1];

logic [31:0] cnt_w_delay;
logic [9:0] w_delay;
logic [2:0] aw_rptr,aw_wptr;
logic aw_full, aw_empty;
logic aw_push,aw_pop;

axi_resp_t b_fifo [0:MAX_OUTSTANDING-1];
logic [2:0] b_rptr,b_wptr;
logic b_full, b_empty;
logic b_push,b_pop;

// ==========================================
// ★ READ CHANNEL: FIFOs & Pointers
// ==========================================
axi_req_t  ar_fifo [0:MAX_OUTSTANDING-1];

logic [31:0] cnt_r_delay_fifo [0:MAX_OUTSTANDING-1];
logic [9:0] r_delay_fifo [0:MAX_OUTSTANDING-1];

logic [31:0] cnt_r_delay;
logic [9:0] r_delay;
logic [2:0] ar_rptr,ar_wptr;
logic ar_full, ar_empty;
logic ar_push,ar_pop;



// FSM States
/*typedef enum logic  [3:0] { 
      AXI_IDLE      = 4'd0,  
      AXI_DELAY     = 4'd1,  // Simulates memory access latency
      AXI_WRITE     = 4'd2,  // Handles Write Data and Response channels
      AXI_READ      = 4'd3   // Handles Read Data channel
} State;*/
typedef enum logic [1:0] {
    R_IDLE  = 2'd0,
    R_DELAY = 2'd1,
    R_BURST = 2'd2
} R_State;
R_State r_state, r_state_next;

typedef enum logic [1:0] {
    W_IDLE  = 2'd0,
    W_DELAY = 2'd1,
    W_BURST = 2'd2
   // W_RESP  = 2'd3
} W_State;
W_State w_state, w_state_next;

// Pending Action Tracking
typedef enum logic  [1:0] { 
      NONE  = 2'd0,
      READ  = 2'd1,
      WRITE = 2'd2
} Action;

initial begin
    for (int i = 0; i < 131072; i++) begin
        DRAM[i] = 8'h00;
    end
    $readmemh(DRAM_ptr, DRAM);
end

// Internal Registers
//State state, state_next;
Action action;

// Latched Write Address Channel Signals
logic [ID_WIDTH-1:0] AWID;
logic [ADDR_WIDTH-1:0] AWADDR;
logic [7:0] AWLEN;
logic [2:0] AWSIZE;
logic [1:0] AWBURST;

// Latched Read Address Channel Signals
logic [ID_WIDTH-1:0] ARID;
logic [ADDR_WIDTH-1:0] ARADDR;
logic [7:0] ARLEN;
logic [2:0] ARSIZE;
logic [1:0] ARBURST;

// Write Channel Control Signals
logic BVALID;
logic [1:0]BRESP;
logic [7:0] cnt_WDATA;
logic WREADY;
logic [ADDR_WIDTH-1:0] WADDR;
logic [8:0] INCR_WADDR;

// Calculate address increment step based on AWSIZE (e.g., 2^2 = 4 bytes)
assign INCR_WADDR = 1 << AWSIZE;
//assign INCR_WADDR = 4; 
// Read Channel Control Signals
logic [7:0] cnt_RDATA;
logic [ADDR_WIDTH-1:0] RADDR;
logic [8:0] INCR_RADDR;
logic [DATA_WIDTH-1:0] RDATA;
logic [1:0] RRESP;
logic is_waddr_error, is_waddr_error_comb;

// Calculate address increment step based on ARSIZE
assign INCR_RADDR = 1 << ARSIZE;

// ==========================================
// FSM Logic
// ==========================================

// State Register Update
/*always_ff @(posedge clk, negedge rst_n) begin 
      if(!rst_n)
            state <= AXI_IDLE;
      else
            state <= state_next;
end*/

always_ff @(posedge clk, negedge rst_n) begin 
      if(!rst_n)
            r_state <= R_IDLE;
      else
            r_state <= r_state_next;
end

always_ff @(posedge clk, negedge rst_n) begin 
      if(!rst_n)
            w_state <= W_IDLE;
      else
            w_state <= w_state_next;
end

always_comb begin 
      case(r_state)
			R_IDLE : begin
				if(!ar_empty)
					r_state_next = R_DELAY;
				else
					r_state_next = R_IDLE;
			end
			R_DELAY:begin
				if(cnt_r_delay >= r_delay && (w_state != W_BURST))begin
					r_state_next = R_BURST;
				end else
					r_state_next = R_DELAY;
			end
			R_BURST:begin
				if(inf.RLAST && inf.RVALID && inf.RREADY)
                        r_state_next = R_IDLE;
                  else
                        r_state_next = R_BURST;
			end
			default: r_state_next = R_IDLE;
	  endcase
end

always_comb begin 
      case(w_state)
			W_IDLE : begin
				if(!aw_empty)
					w_state_next = W_DELAY;
				else
					w_state_next = W_IDLE;
			end
			W_DELAY:begin
				if(cnt_w_delay >= w_delay && ((r_state_next == R_IDLE) && (r_state == R_IDLE)))begin
					w_state_next = W_BURST;
				end else
					w_state_next = W_DELAY;
			end
			W_BURST:begin
				if(inf.BVALID && inf.BREADY)
                        w_state_next = W_IDLE;
                  else
                        w_state_next = W_BURST;
			end
			default: w_state_next = W_IDLE;
	  endcase
end

// ==========================================
// AWFIFO implement
// ==========================================
assign aw_push = inf.AWVALID && inf.AWREADY;
assign aw_pop  = (w_state == W_IDLE) && !aw_empty ;//&& !b_full; 

always_ff @(posedge clk, negedge rst_n) begin 
      if(!rst_n)begin
            aw_rptr <= 0;
			aw_wptr <= 0;
      end else begin
			if(aw_push)
				aw_wptr <= aw_wptr + 1;
			if(aw_pop)
				aw_rptr <= aw_rptr + 1;
	  end
end

always_ff @(posedge clk, negedge rst_n) begin 
      if(!rst_n)
            for(int i = 0; i < MAX_OUTSTANDING; i++)begin
				aw_fifo[i] <= 'd0;
		    end
      else begin
		    if(aw_push)
				aw_fifo[aw_wptr[1:0]] <= {inf.AWID,inf.AWADDR,inf.AWLEN,inf.AWSIZE,inf.AWBURST};
	  end
end

/*
always_ff @(posedge clk, negedge rst_n) begin 
      if(!rst_n) being
            b_rptr <= 0;
			b_wprt <= 0;
      else begin
			if(b_push)
				b_wptr <= b_wptr + 1;
			if(b_pop)
				b_rptr < = b_rptr + 1;
	  end
end
*/

assign aw_full  = ((aw_rptr[2] == ~aw_wptr[2]) && (aw_rptr[1:0] == aw_wptr[1:0]));
assign aw_empty = (aw_rptr == aw_wptr);
//assign b_full   = ((b_rptr[2] == ~b_wptr[2]) && (b_rptr[1:0] == b_wptr[1:0]));
//assign b_empty  = (b_rptr == b_wptr);

always_ff @(posedge clk, negedge rst_n) begin 
      if(!rst_n)
            for(int i = 0; i < MAX_OUTSTANDING;i++)
                cnt_w_delay_fifo[i] <= 0;
      else begin
            for(int i = 0; i < MAX_OUTSTANDING;i++) begin
                if (aw_push && (i == aw_wptr[1:0]))
                    cnt_w_delay_fifo[i] <= 0;
                else
                    cnt_w_delay_fifo[i] <= cnt_w_delay_fifo[i] + 1;
            end
      end
end

always_ff @(posedge clk, negedge rst_n) begin 
      if(!rst_n)
            for(int i = 0; i < MAX_OUTSTANDING; i++)begin
				w_delay_fifo[i] <= 'd0;
		    end
      else begin
			for(int i = 0; i < MAX_OUTSTANDING; i++)begin
				if(aw_push)
					w_delay_fifo[aw_wptr[1:0]] <= $urandom_range(`LAT_MAX, `LAT_MIN);
			end		
	  end
end

always_ff @(posedge clk, negedge rst_n) begin 
      if(!rst_n)
            cnt_w_delay <= 0;
      else begin
			if(aw_pop)
				cnt_w_delay <= cnt_w_delay_fifo[aw_rptr[1:0]];
			else begin
				if(w_state == W_DELAY)
					cnt_w_delay <= cnt_w_delay + 1;
			end
	  end
end

always_ff @(posedge clk, negedge rst_n) begin 
      if(!rst_n)
            w_delay <= 0;
      else begin
			if(aw_pop)
				w_delay <= w_delay_fifo[aw_rptr[1:0]];
	  end
end


// ==========================================
// ARFIFO implement
// ==========================================
assign ar_push = inf.ARVALID && inf.ARREADY;
assign ar_pop  = (r_state == R_IDLE) && !ar_empty ; 

always_ff @(posedge clk, negedge rst_n) begin 
      if(!rst_n)begin
            ar_rptr <= 0;
		ar_wptr <= 0;
      end else begin
            if(ar_push)
                  ar_wptr <= ar_wptr + 1;
            if(ar_pop)
                  ar_rptr <= ar_rptr + 1;
      end
end

always_ff @(posedge clk, negedge rst_n) begin 
      if(!rst_n)
            for(int i = 0; i < MAX_OUTSTANDING; i++)begin
			ar_fifo[i] <= 'd0;
		end
      else begin
		if(ar_push)
		      ar_fifo[ar_wptr[1:0]] <= {inf.ARID,inf.ARADDR,inf.ARLEN,inf.ARSIZE,inf.ARBURST};
	  end
end

assign ar_full  = ((ar_rptr[2] == ~ar_wptr[2]) && (ar_rptr[1:0] == ar_wptr[1:0]));
assign ar_empty = (ar_rptr == ar_wptr);

always_ff @(posedge clk, negedge rst_n) begin 
      if(!rst_n)
            for(int i = 0; i < MAX_OUTSTANDING;i++)
                cnt_r_delay_fifo[i] <= 0;
      else begin
            for(int i = 0; i < MAX_OUTSTANDING;i++) begin
                if (ar_push && (i == ar_wptr[1:0]))
                    cnt_r_delay_fifo[i] <= 0;
                else
                    cnt_r_delay_fifo[i] <= cnt_r_delay_fifo[i] + 1;
            end
      end
end

always_ff @(posedge clk, negedge rst_n) begin 
      if(!rst_n)
            for(int i = 0; i < MAX_OUTSTANDING; i++)begin
			r_delay_fifo[i] <= 'd0;
		end
      else begin
            for(int i = 0; i < MAX_OUTSTANDING; i++)begin
                  if(ar_push)
                        r_delay_fifo[ar_wptr[1:0]] <= $urandom_range(`LAT_MAX, `LAT_MIN);
            end		
	  end
end

always_ff @(posedge clk, negedge rst_n) begin 
      if(!rst_n)
            cnt_r_delay <= 0;
      else begin
            if(ar_pop)
                  cnt_r_delay <= cnt_r_delay_fifo[ar_rptr[1:0]];
            else begin
                  if(r_state == R_DELAY)
                        cnt_r_delay <= cnt_r_delay + 1;
            end
	  end
end

always_ff @(posedge clk, negedge rst_n) begin 
      if(!rst_n)
            r_delay <= 0;
      else begin
            if(ar_pop)
                  r_delay <= r_delay_fifo[ar_rptr[1:0]];
	  end
end


// ==========================================
// WRITE CHANNEL CONTROL
// ==========================================


always_ff @(posedge clk, negedge rst_n) begin 
      if(!rst_n)begin
            AWID <= 0;
            AWADDR <= 0;
            AWSIZE <= 0;
            AWLEN <= 0;
            AWBURST <= 0;
      end else begin
            if(aw_pop)begin
				AWID <= aw_fifo[aw_rptr[1:0]].id;
				AWADDR <= aw_fifo[aw_rptr[1:0]].addr;
				AWSIZE <= aw_fifo[aw_rptr[1:0]].size;
				AWLEN <= aw_fifo[aw_rptr[1:0]].len;
				AWBURST <= aw_fifo[aw_rptr[1:0]].burst;
			end
      end     
end


// Write Data Beat Counter
always_ff @(posedge clk, negedge rst_n) begin 
      if(!rst_n)
            cnt_WDATA <= 0;
      else begin
            if(w_state == W_BURST)begin
                  if(inf.WVALID && inf.WREADY)
                        cnt_WDATA <= cnt_WDATA + 1;
                  else
                        cnt_WDATA <= cnt_WDATA;
            end else
                  cnt_WDATA <= 0;
      end       
end

// Write Response Valid (BVALID) Logic
always_ff @(posedge clk, negedge rst_n) begin 
      if(!rst_n)
            BVALID <= 0;
      else begin
            if(w_state == W_BURST)begin
                  // Assert BVALID when the last data beat is successfully received
                  if(inf.WVALID && inf.WREADY && inf.WLAST) 
                        BVALID <= 1;
                  // Error handling: WLAST mismatch (either too early or too late)
                 // else if ((inf.WLAST && (cnt_WDATA != AWLEN)) || (inf.WVALID && inf.WREADY && (cnt_WDATA == AWLEN) && !inf.WLAST) )
                 //       BVALID <= 1;
                  else if(inf.BVALID && inf.BREADY)
                        BVALID <= 0;
            end else
                  BVALID <= 0;
      end       
end

// Write Response Status (BRESP) Logic
always_ff @(posedge clk, negedge rst_n) begin 
      if(!rst_n)
            BRESP <= OKAY;
      else begin
            if(w_state == W_BURST)begin
                  // Return OKAY for successful burst
                  if(inf.WVALID && inf.WREADY && inf.WLAST)begin
                        if (cnt_WDATA != AWLEN|| is_waddr_error_comb)
                              BRESP <= SLVERR;
                        else
                              BRESP <= OKAY;
                  end else if(inf.BVALID && inf.BREADY)
                              BRESP <= OKAY;
            end
      end       
end

// Internal Write Address Generator for Burst Mode
always_ff @(posedge clk, negedge rst_n) begin 
      if(!rst_n)
            WADDR <= 32'd0;
      else begin
            if(w_state == W_BURST)begin
                  // Increment address on each successful beat except the last one
                  if(inf.WVALID && inf.WREADY && !inf.WLAST)
                        WADDR <= WADDR + INCR_WADDR;
                  else
                        WADDR <= WADDR;
            end else if(aw_pop)
                  WADDR <= aw_fifo[aw_rptr[1:0]].addr; // Initial address latch
      end       
end

always_comb begin
      if(inf.BVALID && inf.BREADY)
            is_waddr_error_comb = 0;
      else if(w_state == W_BURST)begin
            if(WADDR> 32'h0001_FFFF)
                  is_waddr_error_comb = 1;
            else
                  is_waddr_error_comb = is_waddr_error;
      end else
            is_waddr_error_comb = 0;
end

always_ff @(posedge clk, negedge rst_n) begin 
      if(!rst_n)
            is_waddr_error <= 0;
      else begin
            is_waddr_error <= is_waddr_error_comb;
      end       
end

// Main Memory Write Logic (Byte-addressable with WSTRB masking)
always @(posedge clk) begin 
      if(w_state == W_BURST && inf.WVALID && inf.WREADY)begin
            // Use local variable for the loop to avoid conflicts
            for(int i = 0; i < STRB_WIDTH; i++) begin
                  if(inf.WSTRB[i] && ((WADDR + i) <= 32'h0001_FFFF)) begin
                        DRAM[WADDR + i] <= inf.WDATA[(i*8) +: 8];
                  end
            end
      end      
end

// ==========================================
// READ CHANNEL CONTROL
// ==========================================
/*
// Latch Read Address Channel Signals
always_ff @(posedge clk, negedge rst_n) begin 
      if(!rst_n)begin
            ARID <= 0;
            ARADDR <= 0;
            ARSIZE <= 0;
            ARLEN <= 0;
            ARBURST <= 0;
      end else begin
            case(r_state)
                  R_IDLE : begin
                        if(inf.ARVALID && inf.ARREADY)begin
                              ARID <= inf.ARID;
                              ARADDR <= inf.ARADDR;
                              ARSIZE <= inf.ARSIZE;
                              ARLEN <= inf.ARLEN;
                              ARBURST <= inf.ARBURST;
                        end else begin
                              ARID <= 0;
                              ARADDR <= 0;
                              ARSIZE <= 0;
                              ARLEN <= 0;
                              ARBURST <= 0;    
                        end
                  end
                  default : begin
                        ARID <= ARID;
                        ARADDR <= ARADDR;
                        ARSIZE <= ARSIZE;
                        ARLEN <= ARLEN;
                        ARBURST <= ARBURST;  
                  end
            endcase
      end     
end
*/

always_ff @(posedge clk, negedge rst_n) begin 
      if(!rst_n)begin
            ARID <= 0;
            ARADDR <= 0;
            ARSIZE <= 0;
            ARLEN <= 0;
            ARBURST <= 0;
      end else begin
            if(ar_pop)begin
                  ARID <= ar_fifo[ar_rptr[1:0]].id;
                  ARADDR <= ar_fifo[ar_rptr[1:0]].addr;
                  ARSIZE <= ar_fifo[ar_rptr[1:0]].size;
                  ARLEN <= ar_fifo[ar_rptr[1:0]].len;
                  ARBURST <= ar_fifo[ar_rptr[1:0]].burst;
            end
      end     
end

// Read Data Beat Counter
always_ff @(posedge clk, negedge rst_n) begin 
      if(!rst_n)
            cnt_RDATA <= 0;
      else begin
            if(r_state == R_BURST)begin
                  if(inf.RVALID && inf.RREADY)
                        cnt_RDATA <= cnt_RDATA + 1;
                  else
                        cnt_RDATA <= cnt_RDATA;
            end else
                  cnt_RDATA <= 0;
      end       
end

// Internal Read Address Generator for Burst Mode
always_ff @(posedge clk, negedge rst_n) begin 
      if(!rst_n)
            RADDR <= 32'd0;
      else begin
            if(r_state == R_BURST)begin
                  // Increment address on each successful beat except the last one
                  if(inf.RVALID && inf.RREADY && !inf.RLAST)
                        RADDR <= RADDR + INCR_RADDR;
                  else
                        RADDR <= RADDR;
            end else if(ar_pop)
                  RADDR <= ar_fifo[ar_rptr[1:0]].addr; // Initial address latch
      end       
end

// Main Memory Read Logic (Combinational for zero-delay cycle-accurate matching)
always_comb begin
     if (r_state == R_BURST) begin
        // Fetch Little-Endian structured data dynamically based on latched RADDR   
      for(int i = 0; i < STRB_WIDTH; i++) begin
            if ((RADDR + i) <= 32'h0001_FFFF) begin
                RDATA[(i*8) +: 8] = DRAM[RADDR + i];
            end else begin
                RDATA[(i*8) +: 8] = 8'h00;
            end
      end
    end else begin
        RDATA = 32'd0;
    end
end
/*
// Read Response Status (RRESP) Logic
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        RRESP <= OKAY;
    end else if (r_state == R_BURST) begin
        // Check for Out-of-Bound access (Address beyond 32KB)
        if (RADDR > 32'h0001_FFFF) begin
            RRESP <= SLVERR; // Slave Error
        end else begin
            RRESP <= OKAY;   // Normal operation
        end
    end
end
*/

always_comb begin
      if(r_state == R_BURST && (RADDR > 32'h0001_FFFF))
            RRESP = SLVERR;
      else
            RRESP = OKAY;
end
// ==========================================
// AXI Output Assignments
// ==========================================

// Observe inf.ARREADY/inf.AWREADY (the AXI interface), not an internal register.
assign inf.ARREADY = !ar_full;
assign inf.AWREADY = !aw_full;

// Write Channel Assignments
assign inf.WREADY  = (w_state == W_BURST) && !BVALID; // Stop accepting data once BVALID is pending
assign inf.BVALID  = BVALID;
assign inf.BRESP   = BRESP;
assign inf.BID     = AWID;

// Read Channel Assignments
assign inf.RDATA  = RDATA;
assign inf.RLAST  = (cnt_RDATA == ARLEN) && (r_state == R_BURST); // Combinational assertion of RLAST on final beat
assign inf.RVALID = (r_state == R_BURST);
assign inf.RID    = ARID;
assign inf.RRESP  = RRESP;

endmodule
