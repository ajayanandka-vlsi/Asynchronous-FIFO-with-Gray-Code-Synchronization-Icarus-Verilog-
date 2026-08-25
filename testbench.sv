// Code your testbench here
// or browse Examples
`timescale 1ns/1ps
module tb_async_fifo;
parameter DSIZE = 8;
parameter ASIZE = 4;
reg wclk, rclk, wrst_n, rrst_n, winc, rinc;
reg [DSIZE-1:0] wdata;
wire wfull, rempty;
wire [DSIZE-1:0] rdata;

async_fifo #(DSIZE, ASIZE) dut (
    .wclk(wclk), .wrst_n(wrst_n), .winc(winc), .wdata(wdata), .wfull(wfull),
    .rclk(rclk), .rrst_n(rrst_n), .rinc(rinc), .rdata(rdata), .rempty(rempty)
);

initial begin
    wclk = 0;
    forever #5 wclk = ~wclk;
end

initial begin
    rclk = 0;
    forever #13 rclk = ~rclk;
end

initial begin
    $dumpfile("async_fifo.vcd");
    $dumpvars(0, tb_async_fifo);
    wrst_n = 0; rrst_n = 0;
    winc = 0; rinc = 0; wdata = 0;
    #30;
    wrst_n = 1; rrst_n = 1;
    #20;
    repeat (20) begin
        @(negedge wclk);
        if (!wfull) begin
            winc = 1;
            wdata = $random;
        end
    end
    @(negedge wclk) winc = 0;
    #50;
    repeat (20) begin
        @(negedge rclk);
        if (!rempty) rinc = 1;
    end
    @(negedge rclk) rinc = 0;
    #50;
    $finish;
end
endmodule