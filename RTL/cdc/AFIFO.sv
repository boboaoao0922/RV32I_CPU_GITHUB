module AFIFO #(
    parameter DATA_WIDTH = 64,
    parameter ADDR_WIDTH = 5   
)(
    input logic wclk,
    input logic rclk,
    input logic wrst_n,
    input logic rrst_n,
    input logic winc,
    input logic  [DATA_WIDTH-1:0] wdata,
    output logic wfull,
    input logic rinc,
    output logic [DATA_WIDTH-1:0] rdata,
    output logic  rempty
);

logic sram_WEB, sram_REB;
logic [4:0] sram_w_addr, sram_r_addr;
logic [ADDR_WIDTH : 0] w_addr, r_addr;
logic [63:0] sram_w_data, sram_r_data;

logic fifo_push, fifo_pop;

logic [ADDR_WIDTH : 0] rptr_r, wptr_r;
logic [ADDR_WIDTH : 0] rptr_w, wptr_w;
logic [ADDR_WIDTH : 0] rptr_r_ff, wptr_w_ff;

assign wfull = (rptr_w[ADDR_WIDTH:ADDR_WIDTH-1] == ~wptr_w[ADDR_WIDTH:ADDR_WIDTH-1]) && (rptr_w[ADDR_WIDTH-2:0] == wptr_w[ADDR_WIDTH-2:0]);
assign rempty = (rptr_r == wptr_r);

assign rdata = {{(64 - DATA_WIDTH){1'd0}},sram_r_data[DATA_WIDTH-1:0]};
assign sram_w_data = {{(64 - DATA_WIDTH){1'd0}},wdata[DATA_WIDTH-1:0]};

assign fifo_push = winc && !wfull;
assign fifo_pop = rinc && !rempty;

assign sram_WEB = !fifo_push;
assign sram_REB = !fifo_pop;

assign sram_r_addr = {{(5-ADDR_WIDTH){1'd0}},r_addr[ADDR_WIDTH-1:0]};
assign sram_w_addr = {{(5-ADDR_WIDTH){1'd0}},w_addr[ADDR_WIDTH-1:0]};

always_ff@(posedge wclk, negedge wrst_n)begin
    if(!wrst_n)
        w_addr <= 0;
    else if(fifo_push)
        w_addr <= w_addr + 1;
end

assign wptr_w = w_addr ^ (w_addr >> 1);

always_ff@(posedge wclk,negedge wrst_n)begin
    if(!wrst_n)
        wptr_w_ff <= 0;
    else
        wptr_w_ff <= wptr_w;
end


always_ff@(posedge rclk, negedge rrst_n)begin
    if(!rrst_n)
        r_addr <= 0;
    else if(fifo_pop)
        r_addr <= r_addr + 1;
end

assign rptr_r = r_addr ^ (r_addr >> 1);

always_ff@(posedge rclk,negedge rrst_n)begin
    if(!rrst_n)
        rptr_r_ff <= 0;
    else
        rptr_r_ff <= rptr_r;
end

NDFF #(.N(2),.DATA_WIDTH(ADDR_WIDTH + 1)) u_W_NDFF(
    .clk(wclk),
    .rst_n(wrst_n),
    .D(rptr_r_ff),
    .Q(rptr_w)   
);

NDFF #(.N(2),.DATA_WIDTH(ADDR_WIDTH + 1)) u_R_NDFF(
    .clk(rclk),
    .rst_n(rrst_n),
    .D(wptr_w_ff),
    .Q(wptr_r)   
);

SRAM_WRAPPER_32x64 u_sram(
    .wclk(wclk),
    .WEB(sram_WEB), 
    .w_addr(sram_w_addr), 
    .w_data(sram_w_data), 
    .rclk(rclk), 
    .REB(sram_REB),
    .r_addr(sram_r_addr),
    .r_data(sram_r_data)
);

endmodule