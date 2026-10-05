import ARBITER_PKG::*;
module Arbiter(
    input clk,
    input rst_n,
    INF_AXI.PSUEDO_DRAM inf_axi_master0,
    INF_AXI.PSUEDO_DRAM inf_axi_master1,
    INF_AXI.PATTERN inf_axi_MEM
);

Arb_owner AR_owner, AW_owner, W_owner; 
logic AR_robin, AW_robin;
Arb_owner W_owner_fifo [7:0];
logic [3:0] W_owner_wptr, W_owner_rptr;
logic W_owner_push, W_owner_pop, W_owner_empty, W_owner_full;
// ==========================================
// AR CHANNEL CTRL
// ==========================================

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)
        AR_robin <= 0;
    else if(inf_axi_MEM.ARVALID && inf_axi_MEM.ARREADY)begin
        if(AR_owner == Arb_owner_master0)
            AR_robin <= 1;
        else 
            AR_robin <= 0;
    end
end

always_ff@(posedge clk, negedge rst_n)begin
    if(!rst_n)
        AR_owner <= Arb_owner_none;
    else if(inf_axi_MEM.ARVALID && inf_axi_MEM.ARREADY)
        AR_owner <= Arb_owner_none;
    else if(AR_owner == Arb_owner_none)begin
        if(inf_axi_master0.ARVALID && inf_axi_master1.ARVALID)begin
            if(AR_robin)
                AR_owner <= Arb_owner_master1;
            else
                AR_owner <= Arb_owner_master0;
        end else if(inf_axi_master0.ARVALID)
            AR_owner <= Arb_owner_master0;
        else if(inf_axi_master1.ARVALID)
            AR_owner <= Arb_owner_master1;
    end
end

always_comb begin
    case (AR_owner)
        Arb_owner_master0: begin
            inf_axi_MEM.ARVALID = inf_axi_master0.ARVALID;
            inf_axi_MEM.ARADDR  = inf_axi_master0.ARADDR;
            inf_axi_MEM.ARLEN   = inf_axi_master0.ARLEN;
            inf_axi_MEM.ARSIZE  = inf_axi_master0.ARSIZE;
            inf_axi_MEM.ARBURST = inf_axi_master0.ARBURST;
            inf_axi_MEM.ARID    = {1'b0,inf_axi_master0.ARID[2:0]};
        end

        Arb_owner_master1: begin
            inf_axi_MEM.ARVALID = inf_axi_master1.ARVALID;
            inf_axi_MEM.ARADDR  = inf_axi_master1.ARADDR;
            inf_axi_MEM.ARLEN   = inf_axi_master1.ARLEN;
            inf_axi_MEM.ARSIZE  = inf_axi_master1.ARSIZE;
            inf_axi_MEM.ARBURST = inf_axi_master1.ARBURST;
            inf_axi_MEM.ARID    = {1'b1,inf_axi_master1.ARID[2:0]} ;
        end

        default: begin
            inf_axi_MEM.ARVALID = '0;
            inf_axi_MEM.ARADDR  = '0;
            inf_axi_MEM.ARLEN   = '0;
            inf_axi_MEM.ARSIZE  = '0;
            inf_axi_MEM.ARBURST = '0;
            inf_axi_MEM.ARID    = '0 ;
        end
    endcase
end

assign inf_axi_master0.ARREADY = (AR_owner == Arb_owner_master0) ? inf_axi_MEM.ARREADY : 0;
assign inf_axi_master1.ARREADY = (AR_owner == Arb_owner_master1) ? inf_axi_MEM.ARREADY : 0;

// ==========================================
// R CHANNEL CTRL
// ==========================================

assign inf_axi_master0.RID = inf_axi_MEM.RID[3] ? 0 : {1'b0, inf_axi_MEM.RID[2:0]};
assign inf_axi_master0.RDATA = inf_axi_MEM.RID[3] ? 0 : inf_axi_MEM.RDATA;
assign inf_axi_master0.RRESP = inf_axi_MEM.RID[3] ? 0 : inf_axi_MEM.RRESP;
assign inf_axi_master0.RLAST = inf_axi_MEM.RID[3] ? 0 : inf_axi_MEM.RLAST;
assign inf_axi_master0.RVALID = inf_axi_MEM.RVALID && !inf_axi_MEM.RID[3];

assign inf_axi_master1.RID = inf_axi_MEM.RID[3] ? {1'b0, inf_axi_MEM.RID[2:0]} : 0;
assign inf_axi_master1.RDATA = inf_axi_MEM.RID[3] ? inf_axi_MEM.RDATA : 0;
assign inf_axi_master1.RRESP = inf_axi_MEM.RID[3] ? inf_axi_MEM.RRESP : 0;
assign inf_axi_master1.RLAST = inf_axi_MEM.RID[3] ? inf_axi_MEM.RLAST : 0;
assign inf_axi_master1.RVALID = inf_axi_MEM.RVALID && inf_axi_MEM.RID[3];

assign inf_axi_MEM.RREADY = inf_axi_MEM.RVALID && (inf_axi_MEM.RID[3] ? inf_axi_master1.RREADY : inf_axi_master0.RREADY);


// ==========================================
// AW CHANNEL CTRL
// ==========================================
always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n)
        AW_robin <= 0;
    else if(inf_axi_MEM.AWVALID && inf_axi_MEM.AWREADY)begin
        if(AW_owner == Arb_owner_master0)
            AW_robin <= 1;
        else 
            AW_robin <= 0;
    end
        
end

always_ff@(posedge clk, negedge rst_n)begin
    if(!rst_n)
        AW_owner <= Arb_owner_none;
    else if(inf_axi_MEM.AWVALID && inf_axi_MEM.AWREADY)
        AW_owner <= Arb_owner_none;
    else if(AW_owner == Arb_owner_none && !W_owner_full)begin
        if(inf_axi_master0.AWVALID && inf_axi_master1.AWVALID)begin
            if(AW_robin)
                AW_owner <= Arb_owner_master1;
            else
                AW_owner <= Arb_owner_master0;
        end else if(inf_axi_master0.AWVALID)
            AW_owner <= Arb_owner_master0;
        else if(inf_axi_master1.AWVALID)
            AW_owner <= Arb_owner_master1;
    end
end

always_comb begin
    case (AW_owner)
        Arb_owner_master0: begin
            inf_axi_MEM.AWVALID = inf_axi_master0.AWVALID;
            inf_axi_MEM.AWADDR  = inf_axi_master0.AWADDR;
            inf_axi_MEM.AWLEN   = inf_axi_master0.AWLEN;
            inf_axi_MEM.AWSIZE  = inf_axi_master0.AWSIZE;
            inf_axi_MEM.AWBURST = inf_axi_master0.AWBURST;
            inf_axi_MEM.AWID    = {1'b0,inf_axi_master0.AWID[2:0]};
        end

        Arb_owner_master1: begin
            inf_axi_MEM.AWVALID = inf_axi_master1.AWVALID;
            inf_axi_MEM.AWADDR  = inf_axi_master1.AWADDR;
            inf_axi_MEM.AWLEN   = inf_axi_master1.AWLEN;
            inf_axi_MEM.AWSIZE  = inf_axi_master1.AWSIZE;
            inf_axi_MEM.AWBURST = inf_axi_master1.AWBURST;
            inf_axi_MEM.AWID    = {1'b1,inf_axi_master1.AWID[2:0]};
        end

        default: begin
            inf_axi_MEM.AWVALID = '0;
            inf_axi_MEM.AWADDR  = '0;
            inf_axi_MEM.AWLEN   = '0;
            inf_axi_MEM.AWSIZE  = '0;
            inf_axi_MEM.AWBURST = '0;
            inf_axi_MEM.AWID    = '0 ;
        end
    endcase
end

assign inf_axi_master0.AWREADY = (AW_owner == Arb_owner_master0) ? inf_axi_MEM.AWREADY : 0;
assign inf_axi_master1.AWREADY = (AW_owner == Arb_owner_master1) ? inf_axi_MEM.AWREADY : 0;
// ==========================================
// W CHANNEL CTRL
// ==========================================
assign W_owner_push = inf_axi_MEM.AWVALID && inf_axi_MEM.AWREADY;
//assign W_owner_pop = inf_axi_MEM.WVALID && inf_axi_MEM.WREADY && inf_axi_MEM.WLAST;
assign W_owner_pop = (W_owner == Arb_owner_none) && !W_owner_empty;
assign W_owner_full = (W_owner_wptr[3] != W_owner_rptr[3]) && (W_owner_wptr[2:0] == W_owner_rptr[2:0]);
assign W_owner_empty = (W_owner_wptr == W_owner_rptr);
//assign W_owner = W_owner_empty ? Arb_owner_none : W_owner_fifo[W_owner_rptr[2:0]];
always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n) begin
        for(int i = 0; i < 8;i++)
            W_owner_fifo[i] <= Arb_owner_none;
    end else if(W_owner_push)
        W_owner_fifo[W_owner_wptr[2:0]] <= AW_owner;
end

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n) 
        W_owner_wptr <= 0;
    else if(W_owner_push)
        W_owner_wptr <= W_owner_wptr + 1;
end

always_ff@(posedge clk,negedge rst_n)begin
    if(!rst_n) 
        W_owner_rptr <= 0;
    else if(W_owner_pop)
        W_owner_rptr <= W_owner_rptr + 1;
end

always_ff@(posedge clk, negedge rst_n)begin
    if(!rst_n)
        W_owner <= Arb_owner_none;
    else if(inf_axi_MEM.WVALID && inf_axi_MEM.WREADY && inf_axi_MEM.WLAST)
        W_owner <= Arb_owner_none;
    else if(W_owner_pop)
        W_owner <=  W_owner_fifo[W_owner_rptr[2:0]];
end



always_comb begin
    case (W_owner)
        Arb_owner_master0: begin
            inf_axi_MEM.WVALID = inf_axi_master0.WVALID;
            inf_axi_MEM.WDATA  = inf_axi_master0.WDATA;
            inf_axi_MEM.WLAST   = inf_axi_master0.WLAST;
            inf_axi_MEM.WSTRB  = inf_axi_master0.WSTRB;
        end

        Arb_owner_master1: begin
            inf_axi_MEM.WVALID = inf_axi_master1.WVALID;
            inf_axi_MEM.WDATA  = inf_axi_master1.WDATA;
            inf_axi_MEM.WLAST   = inf_axi_master1.WLAST;
            inf_axi_MEM.WSTRB  = inf_axi_master1.WSTRB;
        end

        default: begin
            inf_axi_MEM.WVALID = 0;
            inf_axi_MEM.WDATA  = 0;
            inf_axi_MEM.WLAST   = 0;
            inf_axi_MEM.WSTRB  = 0;
        end
    endcase
end


assign inf_axi_master0.WREADY = (W_owner == Arb_owner_master0) ? inf_axi_MEM.WREADY : 0;
assign inf_axi_master1.WREADY = (W_owner == Arb_owner_master1) ? inf_axi_MEM.WREADY : 0;


// ==========================================
// B CHANNEL CTRL
// ==========================================

assign inf_axi_master0.BID = inf_axi_MEM.BID[3] ? 0 : {1'b0, inf_axi_MEM.BID[2:0]};
assign inf_axi_master0.BRESP = inf_axi_MEM.BID[3] ? 0 : inf_axi_MEM.BRESP;
assign inf_axi_master0.BVALID = inf_axi_MEM.BVALID && !inf_axi_MEM.BID[3] ;

assign inf_axi_master1.BID = inf_axi_MEM.BID[3] ? {1'b0, inf_axi_MEM.BID[2:0]} : 0;
assign inf_axi_master1.BRESP = inf_axi_MEM.BID[3] ? inf_axi_MEM.BRESP : 0;
assign inf_axi_master1.BVALID = inf_axi_MEM.BVALID && inf_axi_MEM.BID[3] ;

assign inf_axi_MEM.BREADY = inf_axi_MEM.BVALID && (inf_axi_MEM.BID[3] ? inf_axi_master1.BREADY : inf_axi_master0.BREADY);


endmodule