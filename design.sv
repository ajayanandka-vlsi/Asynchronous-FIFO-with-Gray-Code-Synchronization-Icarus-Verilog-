// Code your design here
module async_fifo #(
    parameter DSIZE = 8,
    parameter ASIZE = 4
)(
    input wclk,
    input wrst_n,
    input winc,
    input [DSIZE-1:0] wdata,
    output reg wfull,
    input rclk,
    input rrst_n,
    input rinc,
    output [DSIZE-1:0] rdata,
    output reg rempty
);

reg [DSIZE-1:0] mem [0:(1<<ASIZE)-1];
reg [ASIZE:0] wptr, rptr;
reg [ASIZE:0] wq1_rptr, wq2_rptr;
reg [ASIZE:0] rq1_wptr, rq2_wptr;
reg [ASIZE:0] wbin, rbin;
wire [ASIZE:0] wbinnext, rbinnext;
wire [ASIZE:0] wptrnext, rptrnext;
wire wfull_val, rempty_val;

assign rdata = mem[rbin[ASIZE-1:0]];

always @(posedge wclk) begin
    if (winc && !wfull) mem[wbin[ASIZE-1:0]] <= wdata;
end

always @(posedge wclk or negedge wrst_n) begin
    if (!wrst_n) begin
        wq1_rptr <= 0;
        wq2_rptr <= 0;
    end else begin
        wq1_rptr <= rptr;
        wq2_rptr <= wq1_rptr;
    end
end

always @(posedge rclk or negedge rrst_n) begin
    if (!rrst_n) begin
        rq1_wptr <= 0;
        rq2_wptr <= 0;
    end else begin
        rq1_wptr <= wptr;
        rq2_wptr <= rq1_wptr;
    end
end

assign wbinnext = wbin + (winc & ~wfull);
assign wptrnext = (wbinnext >> 1) ^ wbinnext;

always @(posedge wclk or negedge wrst_n) begin
    if (!wrst_n) begin
        wbin <= 0;
        wptr <= 0;
    end else begin
        wbin <= wbinnext;
        wptr <= wptrnext;
    end
end

assign rbinnext = rbin + (rinc & ~rempty);
assign rptrnext = (rbinnext >> 1) ^ rbinnext;

always @(posedge rclk or negedge rrst_n) begin
    if (!rrst_n) begin
        rbin <= 0;
        rptr <= 0;
    end else begin
        rbin <= rbinnext;
        rptr <= rptrnext;
    end
end

assign wfull_val = (wptrnext == {~wq2_rptr[ASIZE:ASIZE-1], wq2_rptr[ASIZE-2:0]});
always @(posedge wclk or negedge wrst_n) begin
    if (!wrst_n) wfull <= 1'b0;
    else         wfull <= wfull_val;
end

assign rempty_val = (rptrnext == rq2_wptr);
always @(posedge rclk or negedge rrst_n) begin
    if (!rrst_n) rempty <= 1'b1;
    else         rempty <= rempty_val;
end

endmodule