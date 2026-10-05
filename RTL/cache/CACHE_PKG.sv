`ifndef CACHE_PKG_SV
`define CACHE_PKG_SV

// Cache_pkg.sv
package CACHE_PKG;

    // MESI state encoding for instruction-cache tag entries.
    typedef enum logic [7:0] {
        INVALID  = 8'h00,
        SHARED   = 8'h01,
        MODIFIED = 8'h02,
        EXCLUSIVE= 8'h03  // Reserved for future use.
    } mesi_state_t;
	
	typedef enum logic [1:0] {
        DATA_INVALID  = 2'd0,
        DATA_SHARED   = 2'd1,
        DATA_MODIFIED = 2'd2,
        DATA_EXCLUSIVE = 2'd3  // Reserved for future use.
    } mesi_state_D_tag;

    // One packed 32-bit instruction-cache tag entry per way.
    typedef struct packed {
        mesi_state_t  state; // [31:24] (Byte 3)
        logic [23:0] tag;   // [23:0]  (Bytes 2, 1, 0)
    } cache_way_t;

    // Four ways form one 128-bit SRAM word.
    typedef struct packed {
        cache_way_t way3; // [127:96]
        cache_way_t way2; // [95:64]
        cache_way_t way1; // [63:32]
        cache_way_t way0; // [31:0]
    } cache_set_t;
	
	// One packed 32-bit data-cache tag entry per way.
	typedef struct packed {
        //mesi_state_t  state; // [31:24] (Byte 3)
		logic [7:0] dummy;
        logic [23:0] tag;   // [23:0]  (Bytes 2, 1, 0)
    } cache_way_D_tag;

    // Four data-cache tag entries form one 128-bit SRAM word.
    typedef struct packed {
        cache_way_D_tag way3; // [127:96]
        cache_way_D_tag way2; // [95:64]
        cache_way_D_tag way1; // [63:32]
        cache_way_D_tag way0; // [31:0]
    } cache_set_D_tag;

    typedef logic [31:0] word;

    typedef struct packed {
        word word3; // [127:96] 
        word word2; // [95:64]  
        word word1; // [63:32]
        word word0; // [31:0]
    } cacheline;
	/*
    typedef enum logic [2:0] {
        INIT = 3'd0,
        LOOKUP  = 3'd1,
        AXI_READ = 3'd2,
        REFILL= 3'd3,
        WAIT = 3'd4,
        ERROR = 3'd5,
		RETRIEVE = 3'd6 // the state after refill, get the instruction written in REFILL
    } cache_inst_state;
	*/
	typedef struct packed {
        logic [21:0] tag;
		logic [5:0] index;
		logic [1:0] word_offset;
		logic [1:0] byte_offset;
    } inst_address;
	
	typedef enum logic [3:0] {
        INIT = 4'd0, //initialize tag SRAM,set all block invalid		
        LOOKUP  = 4'd1, //compare tag, if hit, rise cpu_req_ready and cpu_rsp_valid 
        AXI_READ = 4'd2, //waiting AXI reading   
        REFILL= 4'd3, //write data from AXI reading to SRAM 
        WAIT = 4'd4, // waiting cpu_req_valid
        ERROR = 4'd5, // error state 
		RETRIEVE = 4'd6, // the state after refill, get the data from SRAM
		FILL = 4'd7, // after comparing tag, if hit, write data to DRAM (store inst only)
		FLUSH = 4'd8,
		KICK_VICTIM = 4'd9,
		STORE = 4'd10,
		FLUSH_SRAM = 4'd11
	} cache_data_state;
	// I-cache uses the same state encodings; keep one set of enum literals.
	typedef cache_data_state cache_inst_state;
	
	typedef enum logic [1:0] {
        NOT_HANDSHAKE = 2'd0,
		AXI_HAND_SHAKED = 2'd1,
		WRITRING = 2'd2,
		DONE = 2'd3
	} VB_state;
	
	typedef enum logic {
        BUFFER_INVALID = 1'b0,
		BUFFER_VALID = 1'b1
	} Valid_bit;
	
	
	typedef struct packed {
		Valid_bit valid_bit;
		logic [2:0] ID;
        logic [27:0] addr;
		cacheline data;
    } Victim_Buffer;
	
	typedef struct packed {
		Valid_bit valid_bit;
		logic [3:0] way;
		logic [3:0] wstrb;
        logic [31:0] addr;
		word data;
    } Store_Buffer;
	
	/*typedef enum logic [1:0] {
		W_IDLE  = 2'd0,
		W_HS = 2'd1,
		W_BURST = 2'd2
	    W_RESP  = 2'd3  // Wait for the BVALID response.
	} cache_data_W_State;
	*/
endpackage
`endif
