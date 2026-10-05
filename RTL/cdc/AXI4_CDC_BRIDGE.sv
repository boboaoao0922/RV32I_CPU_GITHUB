module AXI4_CDC_BRIDGE(
    input logic master_clk,
    input logic master_rst_n,
    input logic slave_clk,
    input logic slave_rst_n,
    INF_AXI.PSUEDO_DRAM inf_axi_master,
    INF_AXI.PATTERN inf_axi_slave
);

parameter DATA_INVALID= 1'd0, DATA_VALID = 1'd1;

//AR varible
logic ar_slave_state;
logic ar_fifo_wfull, ar_fifo_rempty;
logic ar_fifo_winc, ar_fifo_rinc;
logic [48:0] ar_fifo_wdata, ar_fifo_rdata;

// AW varbile
logic aw_slave_state;
logic aw_fifo_wfull, aw_fifo_rempty;
logic aw_fifo_winc, aw_fifo_rinc;
logic [48:0] aw_fifo_wdata, aw_fifo_rdata;

//R varible
logic r_master_state;
logic r_fifo_wfull, r_fifo_rempty;
logic r_fifo_winc, r_fifo_rinc;
logic [38:0] r_fifo_wdata, r_fifo_rdata;

// W varbile
logic w_slave_state;
logic w_fifo_wfull, w_fifo_rempty;
logic w_fifo_winc, w_fifo_rinc;
logic [36:0] w_fifo_wdata, w_fifo_rdata;

// B varbile
logic b_master_state;
logic b_fifo_wfull, b_fifo_rempty;
logic b_fifo_winc, b_fifo_rinc;
logic [5:0] b_fifo_wdata, b_fifo_rdata;



// ==========================================
// AR CHANNEL CTRL 
// ==========================================
always_ff@(posedge slave_clk, negedge slave_rst_n)begin
    if(!slave_rst_n)
        ar_slave_state <= DATA_INVALID;
    else begin
        case(ar_slave_state)
            DATA_INVALID: begin
                if(ar_fifo_rinc)
                    ar_slave_state <= DATA_VALID;
            end
            DATA_VALID: begin
                if(ar_fifo_rempty && inf_axi_slave.ARVALID && inf_axi_slave.ARREADY)
                    ar_slave_state <= DATA_INVALID;
            end
            default: ar_slave_state <= ar_slave_state;
        endcase
    end
end

assign inf_axi_master.ARREADY = !ar_fifo_wfull;
assign ar_fifo_winc = inf_axi_master.ARVALID && inf_axi_master.ARREADY;
assign ar_fifo_wdata = {inf_axi_master.ARID ,inf_axi_master.ARADDR, inf_axi_master.ARLEN, inf_axi_master.ARSIZE, inf_axi_master.ARBURST};
always_ff@(posedge slave_clk, negedge slave_rst_n)begin
    if(!slave_rst_n)
        inf_axi_slave.ARVALID <= 0;
    else if(ar_fifo_rinc)
        inf_axi_slave.ARVALID <= 1;
    else if(inf_axi_slave.ARVALID && inf_axi_slave.ARREADY)
        inf_axi_slave.ARVALID <= 0;
end

always_comb begin
    case(ar_slave_state)
        DATA_INVALID: ar_fifo_rinc = !ar_fifo_rempty;
        DATA_VALID: ar_fifo_rinc = !ar_fifo_rempty && inf_axi_slave.ARVALID && inf_axi_slave.ARREADY;
        default : ar_fifo_rinc = 0;
    endcase
end

assign inf_axi_slave.ARID = ar_fifo_rdata[48:45];
assign inf_axi_slave.ARADDR = ar_fifo_rdata[44:13];
assign inf_axi_slave.ARLEN = ar_fifo_rdata[12:5];
assign inf_axi_slave.ARSIZE = ar_fifo_rdata[4:2];
assign inf_axi_slave.ARBURST = ar_fifo_rdata[1:0];

AFIFO #(
    .DATA_WIDTH(49),
    .ADDR_WIDTH (5)   
) u_AR_AFIFO(
    .wclk(master_clk),
    .rclk(slave_clk),
    .wrst_n(master_rst_n),
    .rrst_n(slave_rst_n),
    .winc(ar_fifo_winc),
    .wdata(ar_fifo_wdata),
    .wfull(ar_fifo_wfull),
    .rinc(ar_fifo_rinc),
    .rdata(ar_fifo_rdata),
    .rempty(ar_fifo_rempty)
);


// ==========================================
// AW CHANNEL CTRL 
// ==========================================
always_ff@(posedge slave_clk, negedge slave_rst_n)begin
    if(!slave_rst_n)
        aw_slave_state <= DATA_INVALID;
    else begin
        case(aw_slave_state)
            DATA_INVALID: begin
                if(aw_fifo_rinc)
                    aw_slave_state <= DATA_VALID;
            end
            DATA_VALID: begin
                if(aw_fifo_rempty && inf_axi_slave.AWVALID && inf_axi_slave.AWREADY)
                    aw_slave_state <= DATA_INVALID;
            end
            default: aw_slave_state <= aw_slave_state;
        endcase
    end
end

assign inf_axi_master.AWREADY = !aw_fifo_wfull;
assign aw_fifo_winc = inf_axi_master.AWVALID && inf_axi_master.AWREADY;
assign aw_fifo_wdata = {inf_axi_master.AWID ,inf_axi_master.AWADDR, inf_axi_master.AWLEN, inf_axi_master.AWSIZE, inf_axi_master.AWBURST};
always_ff@(posedge slave_clk, negedge slave_rst_n)begin
    if(!slave_rst_n)
        inf_axi_slave.AWVALID <= 0;
    else if(aw_fifo_rinc)
        inf_axi_slave.AWVALID <= 1;
    else if(inf_axi_slave.AWVALID && inf_axi_slave.AWREADY)
        inf_axi_slave.AWVALID <= 0;
end

always_comb begin
    case(aw_slave_state)
        DATA_INVALID: aw_fifo_rinc = !aw_fifo_rempty;
        DATA_VALID: aw_fifo_rinc = !aw_fifo_rempty && inf_axi_slave.AWVALID && inf_axi_slave.AWREADY;
        default : aw_fifo_rinc = 0;
    endcase
end

assign inf_axi_slave.AWID = aw_fifo_rdata[48:45];
assign inf_axi_slave.AWADDR = aw_fifo_rdata[44:13];
assign inf_axi_slave.AWLEN = aw_fifo_rdata[12:5];
assign inf_axi_slave.AWSIZE = aw_fifo_rdata[4:2];
assign inf_axi_slave.AWBURST = aw_fifo_rdata[1:0];

AFIFO #(
    .DATA_WIDTH(49),
    .ADDR_WIDTH (5)   
) u_AW_AFIFO(
    .wclk(master_clk),
    .rclk(slave_clk),
    .wrst_n(master_rst_n),
    .rrst_n(slave_rst_n),
    .winc(aw_fifo_winc),
    .wdata(aw_fifo_wdata),
    .wfull(aw_fifo_wfull),
    .rinc(aw_fifo_rinc),
    .rdata(aw_fifo_rdata),
    .rempty(aw_fifo_rempty)
);

// ==========================================
// R CHANNEL CTRL 
// ==========================================
always_ff@(posedge master_clk, negedge master_rst_n)begin
    if(!master_rst_n)
        r_master_state <= DATA_INVALID;
    else begin
        case(r_master_state)
            DATA_INVALID: begin
                if(r_fifo_rinc)
                    r_master_state <= DATA_VALID;
            end
            DATA_VALID: begin
                if(r_fifo_rempty && inf_axi_master.RVALID && inf_axi_master.RREADY)
                    r_master_state <= DATA_INVALID;
            end
            default: r_master_state <= r_master_state;
        endcase
    end
end

assign inf_axi_slave.RREADY = !r_fifo_wfull;
assign r_fifo_winc = inf_axi_slave.RVALID && inf_axi_slave.RREADY;
assign r_fifo_wdata = {inf_axi_slave.RID ,inf_axi_slave.RDATA, inf_axi_slave.RRESP, inf_axi_slave.RLAST};
always_ff@(posedge master_clk, negedge master_rst_n)begin
    if(!master_rst_n)
        inf_axi_master.RVALID <= 0;
    else if(r_fifo_rinc)
        inf_axi_master.RVALID <= 1;
    else if(inf_axi_master.RVALID && inf_axi_master.RREADY)
        inf_axi_master.RVALID <= 0;
end

always_comb begin
    case(r_master_state)
        DATA_INVALID: r_fifo_rinc = !r_fifo_rempty;
        DATA_VALID: r_fifo_rinc = !r_fifo_rempty && inf_axi_master.RVALID && inf_axi_master.RREADY;
        default : r_fifo_rinc = 0;
    endcase
end

assign inf_axi_master.RID = r_fifo_rdata[38:35];
assign inf_axi_master.RDATA = r_fifo_rdata[34:3];
assign inf_axi_master.RRESP = r_fifo_rdata[2:1];
assign inf_axi_master.RLAST = r_fifo_rdata[0];

AFIFO #(
    .DATA_WIDTH(39),
    .ADDR_WIDTH (5)   
) u_R_AFIFO(
    .wclk(slave_clk),
    .rclk(master_clk),
    .wrst_n(slave_rst_n),
    .rrst_n(master_rst_n),
    .winc(r_fifo_winc),
    .wdata(r_fifo_wdata),
    .wfull(r_fifo_wfull),
    .rinc(r_fifo_rinc),
    .rdata(r_fifo_rdata),
    .rempty(r_fifo_rempty)
);

// ==========================================
// W CHANNEL CTRL 
// ==========================================
always_ff@(posedge slave_clk, negedge slave_rst_n)begin
    if(!slave_rst_n)
        w_slave_state <= DATA_INVALID;
    else begin
        case(w_slave_state)
            DATA_INVALID: begin
                if(w_fifo_rinc)
                    w_slave_state <= DATA_VALID;
            end
            DATA_VALID: begin
                if(w_fifo_rempty && inf_axi_slave.WVALID && inf_axi_slave.WREADY)
                    w_slave_state <= DATA_INVALID;
            end
            default: w_slave_state <= w_slave_state;
        endcase
    end
end

assign inf_axi_master.WREADY = !w_fifo_wfull;
assign w_fifo_winc = inf_axi_master.WVALID && inf_axi_master.WREADY;
assign w_fifo_wdata = {inf_axi_master.WDATA ,inf_axi_master.WSTRB, inf_axi_master.WLAST};
always_ff@(posedge slave_clk, negedge slave_rst_n)begin
    if(!slave_rst_n)
        inf_axi_slave.WVALID <= 0;
    else if(w_fifo_rinc)
        inf_axi_slave.WVALID <= 1;
    else if(inf_axi_slave.WVALID && inf_axi_slave.WREADY)
        inf_axi_slave.WVALID <= 0;
end

always_comb begin
    case(w_slave_state)
        DATA_INVALID: w_fifo_rinc = !w_fifo_rempty;
        DATA_VALID: w_fifo_rinc = !w_fifo_rempty && inf_axi_slave.WVALID && inf_axi_slave.WREADY;
        default : w_fifo_rinc = 0;
    endcase
end

assign inf_axi_slave.WDATA = w_fifo_rdata[36:5];
assign inf_axi_slave.WSTRB = w_fifo_rdata[4:1];
assign inf_axi_slave.WLAST = w_fifo_rdata[0];

AFIFO #(
    .DATA_WIDTH(37),
    .ADDR_WIDTH (5)   
) u_W_AFIFO(
    .wclk(master_clk),
    .rclk(slave_clk),
    .wrst_n(master_rst_n),
    .rrst_n(slave_rst_n),
    .winc(w_fifo_winc),
    .wdata(w_fifo_wdata),
    .wfull(w_fifo_wfull),
    .rinc(w_fifo_rinc),
    .rdata(w_fifo_rdata),
    .rempty(w_fifo_rempty)
);


// ==========================================
// B CHANNEL CTRL 
// ==========================================
always_ff@(posedge master_clk, negedge master_rst_n)begin
    if(!master_rst_n)
        b_master_state <= DATA_INVALID;
    else begin
        case(b_master_state)
            DATA_INVALID: begin
                if(b_fifo_rinc)
                    b_master_state <= DATA_VALID;
            end
            DATA_VALID: begin
                if(b_fifo_rempty && inf_axi_master.BVALID && inf_axi_master.BREADY)
                    b_master_state <= DATA_INVALID;
            end
            default: b_master_state <= b_master_state;
        endcase
    end
end

assign inf_axi_slave.BREADY = !b_fifo_wfull;
assign b_fifo_winc = inf_axi_slave.BVALID && inf_axi_slave.BREADY;
assign b_fifo_wdata = {inf_axi_slave.BID ,inf_axi_slave.BRESP};
always_ff@(posedge master_clk, negedge master_rst_n)begin
    if(!master_rst_n)
        inf_axi_master.BVALID <= 0;
    else if(b_fifo_rinc)
        inf_axi_master.BVALID <= 1;
    else if(inf_axi_master.BVALID && inf_axi_master.BREADY)
        inf_axi_master.BVALID <= 0;
end

always_comb begin
    case(b_master_state)
        DATA_INVALID: b_fifo_rinc = !b_fifo_rempty;
        DATA_VALID: b_fifo_rinc = !b_fifo_rempty && inf_axi_master.BVALID && inf_axi_master.BREADY;
        default : b_fifo_rinc = 0;
    endcase
end

assign inf_axi_master.BID = b_fifo_rdata[5:2];
assign inf_axi_master.BRESP = b_fifo_rdata[1:0];

AFIFO #(
    .DATA_WIDTH(6),
    .ADDR_WIDTH (5)
) u_B_AFIFO(
    .wclk(slave_clk),
    .rclk(master_clk),
    .wrst_n(slave_rst_n),
    .rrst_n(master_rst_n),
    .winc(b_fifo_winc),
    .wdata(b_fifo_wdata),
    .wfull(b_fifo_wfull),
    .rinc(b_fifo_rinc),
    .rdata(b_fifo_rdata),
    .rempty(b_fifo_rempty)
);


endmodule
