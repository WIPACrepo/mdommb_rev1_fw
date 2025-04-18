// test distributed hdr fifo; compare to previously used blockram fifo
// ensure all latencies are identical so we can use it as a drop-in replacement

`timescale 1ns/1ns

module distributed_fifo_tb();

parameter CLK_PERIOD = 8;
reg clk;
initial begin
 // clock initialization
 clk = 1'b0;
end

always @(clk)
 #(CLK_PERIOD / 2.0) clk <= !clk;

// input/output data
reg rst = 1;

reg[107:0] din = 108'habcdef98743210;
reg wr_en = 0;
reg rd_en = 0;

wire[107:0] dist_dout;
wire dist_full;
wire dist_empty;
wire[6:0] dist_data_count;
distributed_hdr_fifo dist_fifo(
  .clk(clk),
  .srst(rst),
  .din(din),
  .wr_en(wr_en),
  .rd_en(rd_en),
  .dout(dist_dout),
  .full(dist_full),
  .empty(dist_empty),
  .data_count(dist_data_count)
);

wire[107:0] blockmem_dout;
wire blockmem_full;
wire blockmem_empty;
wire[6:0] blockmem_data_count;
FIFO_512_108 blockmem_fifo(
  .clk(clk),
  .srst(rst),
  .din(din),
  .wr_en(wr_en),
  .rd_en(rd_en),
  .dout(blockmem_dout),
  .full(blockmem_full),
  .empty(blockmem_empty),
  .data_count(blockmem_data_count)
);

initial begin
#(10 * CLK_PERIOD);
rst = 1'b0;
#(20 * CLK_PERIOD);

@(posedge clk) wr_en <= 1; #1;
@(posedge clk) wr_en <= 0; #1;
#(10 * CLK_PERIOD)
@(posedge clk) rd_en <= 1; #1;
@(posedge clk) rd_en <= 0; #1;
#(10 * CLK_PERIOD);
@(posedge clk) din <= 108'h98743210abcdef; wr_en <= 1; #1;
@(posedge clk) wr_en <= 0; #1;
#(10 * CLK_PERIOD)
@(posedge clk) rd_en <= 1; #1;
@(posedge clk) rd_en <= 0; #1;
end

endmodule

