`timescale 1ns/1ps
module tb_async_fifo;
parameter DSIZE = 8;
parameter ASIZE = 4;
localparam DEPTH = 1 << ASIZE;

reg              wclk, rclk, wrst_n, rrst_n, winc, rinc;
reg  [DSIZE-1:0] wdata;
wire             wfull, rempty;
wire [DSIZE-1:0] rdata;

async_fifo #(DSIZE, ASIZE) dut (
    .wclk(wclk), .wrst_n(wrst_n), .winc(winc), .wdata(wdata), .wfull(wfull),
    .rclk(rclk), .rrst_n(rrst_n), .rinc(rinc), .rdata(rdata), .rempty(rempty)
);

real w_half = 5.0;
real r_half = 13.0;
initial begin wclk = 0; forever #(w_half) wclk = ~wclk; end
initial begin rclk = 0; forever #(r_half) rclk = ~rclk; end

reg [DSIZE-1:0] model [0:16383];
integer wr_count, rd_count;
integer w_target, r_target;
integer w_mode, r_mode;
integer errors, seed;

function integer popcount;
    input [ASIZE:0] v;
    integer k;
    begin
        popcount = 0;
        for (k = 0; k <= ASIZE; k = k + 1) popcount = popcount + v[k];
    end
endfunction

reg [ASIZE:0] wptr_prev;
always @(posedge wclk) begin
    if (!wrst_n) begin
        winc <= 1'b0;
        wdata <= {DSIZE{1'b0}};
        wptr_prev <= 0;
    end else begin
        if (winc && !wfull) begin
            model[wr_count] = wdata;
            wr_count = wr_count + 1;
        end
        if (popcount(dut.wptr ^ wptr_prev) > 1) begin
            errors = errors + 1;
            $display("ERROR @%0t wptr changed by more than one bit: %b -> %b", $time, wptr_prev, dut.wptr);
        end
        wptr_prev <= dut.wptr;
        if (w_mode != 0 && wr_count < w_target)
            winc <= (w_mode == 1) ? 1'b1 : ($random(seed) % 2 != 0);
        else
            winc <= 1'b0;
        wdata <= $random(seed);
    end
end

reg [ASIZE:0] rptr_prev;
always @(posedge rclk) begin
    if (!rrst_n) begin
        rinc <= 1'b0;
        rptr_prev <= 0;
    end else begin
        if (rinc && !rempty) begin
            if (rd_count >= wr_count) begin
                errors = errors + 1;
                $display("ERROR @%0t read of a word that was never written (underflow)", $time);
            end else if (rdata !== model[rd_count]) begin
                errors = errors + 1;
                $display("ERROR @%0t word #%0d: read %h, expected %h", $time, rd_count, rdata, model[rd_count]);
            end
            rd_count = rd_count + 1;
        end
        if (popcount(dut.rptr ^ rptr_prev) > 1) begin
            errors = errors + 1;
            $display("ERROR @%0t rptr changed by more than one bit: %b -> %b", $time, rptr_prev, dut.rptr);
        end
        rptr_prev <= dut.rptr;
        if (r_mode != 0 && rd_count < r_target)
            rinc <= (r_mode == 1) ? 1'b1 : ($random(seed) % 2 != 0);
        else
            rinc <= 1'b0;
    end
end

always @(posedge wclk or posedge rclk) begin
    if (wrst_n && rrst_n && (wr_count - rd_count > DEPTH || wr_count - rd_count < 0)) begin
        errors = errors + 1;
        $display("ERROR @%0t occupancy %0d out of range", $time, wr_count - rd_count);
    end
end

initial begin
    #3_000_000;
    $display("STATUS: SIMULATION FAIL (timeout) wr=%0d rd=%0d", wr_count, rd_count);
    $finish;
end

initial begin
    $dumpfile("async_fifo.vcd");
    $dumpvars(0, tb_async_fifo);
    errors = 0; seed = 3;
    wr_count = 0; rd_count = 0; w_target = 0; r_target = 0; w_mode = 0; r_mode = 0;
    wrst_n = 0; rrst_n = 0; winc = 0; rinc = 0; wdata = 0;
    #60;
    wrst_n = 1; rrst_n = 1;
    #40;

    $display("[%0t] phase 1: overfill", $time);
    w_target = 20; w_mode = 1;
    #600;
    if (wfull !== 1'b1)      begin errors = errors + 1; $display("ERROR: wfull not set when full"); end
    if (wr_count !== DEPTH)  begin errors = errors + 1; $display("ERROR: %0d words accepted, expected %0d", wr_count, DEPTH); end
    w_mode = 0; w_target = wr_count;

    $display("[%0t] phase 2: overdrain", $time);
    r_target = 20; r_mode = 1;
    #1500;
    if (rempty !== 1'b1)     begin errors = errors + 1; $display("ERROR: rempty not set when empty"); end
    if (rd_count !== DEPTH)  begin errors = errors + 1; $display("ERROR: %0d words read, expected %0d", rd_count, DEPTH); end
    if (wfull !== 1'b0)      begin errors = errors + 1; $display("ERROR: wfull still set after draining"); end
    r_mode = 0; r_target = rd_count;

    $display("[%0t] phase 3: random traffic, wclk 100 MHz / rclk 38.5 MHz", $time);
    w_target = wr_count + 3000; r_target = w_target;
    w_mode = 2; r_mode = 2;
    wait (rd_count == r_target);
    #200;

    $display("[%0t] phase 4: random traffic, wclk 38.5 MHz / rclk 100 MHz", $time);
    w_half = 13.0; r_half = 5.0;
    w_target = wr_count + 3000; r_target = w_target;
    wait (rd_count == r_target);
    #200;

    $display("words written: %0d, words read: %0d", wr_count, rd_count);
    if (wr_count != rd_count) begin errors = errors + 1; $display("ERROR: counts differ"); end
    if (errors == 0)
        $display("\n===================================\nSTATUS: SIMULATION PASS\n===================================\n");
    else
        $display("\n===================================\nSTATUS: SIMULATION FAIL (%0d ERRORS)\n===================================\n", errors);
    $finish;
end
endmodule
