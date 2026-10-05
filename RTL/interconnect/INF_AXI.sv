`ifndef INF_AXI
`define INF_AXI
interface INF_AXI #(
    parameter  DATA_WIDTH = 32
)(

);
    //import  usertype::*;

    //logic rst_n;
    //logic clk;
    //write address channel
    logic [3:0] AWID;
    logic [31:0] AWADDR;
    logic [7:0] AWLEN;
    logic [2:0] AWSIZE;
    logic [1:0] AWBURST;
    logic AWVALID;
    logic AWREADY;

    //write data channel
    logic [DATA_WIDTH-1:0] WDATA;
    logic [(DATA_WIDTH/8)-1:0] WSTRB;
    logic WLAST;
    logic WVALID;
    logic WREADY;
    //write response channel
    logic [3:0] BID;
    logic [1:0] BRESP;
    logic BVALID;
    logic BREADY;

    //read address channel
    logic [3:0] ARID;
    logic [31:0] ARADDR;
    logic [7:0] ARLEN;
    logic [2:0] ARSIZE;
    logic [1:0] ARBURST;
    logic ARVALID;
    logic ARREADY;
    //write data channel
    logic [3:0] RID;
    logic [DATA_WIDTH-1:0] RDATA;
    logic [1:0] RRESP;
    logic RLAST;
    logic RVALID;
    logic RREADY;
    //write response channel
    modport PATTERN(
        input AWREADY, WREADY, BID, BRESP, BVALID, 
            ARREADY, 
            RID, RDATA, RRESP, RLAST, RVALID, 
        output //rst_n, 
            AWID, AWADDR, AWLEN, AWSIZE, AWBURST, AWVALID, 
            WDATA, WSTRB, WLAST, WVALID, BREADY,
            ARID, ARADDR, ARLEN, ARSIZE, ARBURST, ARVALID,
            RREADY
    );

    modport PSUEDO_DRAM(
	    input //rst_n, 
            AWID, AWADDR, AWLEN, AWSIZE, AWBURST, AWVALID, 
            WDATA, WSTRB, WLAST, WVALID, BREADY,
            ARID, ARADDR, ARLEN, ARSIZE, ARBURST, ARVALID,
            RREADY,
        output AWREADY, WREADY, BID, BRESP, BVALID, 
            ARREADY, 
            RID, RDATA, RRESP, RLAST, RVALID
    );

    modport CHECKER_AXI(
	    input //rst_n, 
            AWID, AWADDR, AWLEN, AWSIZE, AWBURST, AWVALID, 
            WDATA, WSTRB, WLAST, WVALID, BREADY,
            ARID, ARADDR, ARLEN, ARSIZE, ARBURST, ARVALID,
            RREADY,
            AWREADY, WREADY, BID, BRESP, BVALID, 
            ARREADY, 
            RID, RDATA, RRESP, RLAST, RVALID
    );
    
endinterface
`endif