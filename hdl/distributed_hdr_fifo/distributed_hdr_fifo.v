// 
// A header FIFO built out of distributed RAM
// Can be used as a drop-in replacement for the block ram based header FIFO
// 

module distributed_hdr_fifo(
  input clk,
  input srst,
  input[107:0] din,
  input wr_en,
  input rd_en,
  output[107:0] dout,
  output full,
  output empty,
  output[6:0] data_count
);

wire[107:0] i_dout;
wire i_full;
wire i_empty;
wire[6:0] i_data_count;
MDOM_CHANNEL_HDR_FIFO HDR_FIFO(
  .clk(clk),
  .srst(srst),
  .din(din),
  .wr_en(wr_en),
  .rd_en(rd_en),
  .dout(i_dout),
  .full(i_full),
  .empty(i_empty),
  .data_count(i_data_count)
);

reg[107:0] dout_0;
reg full_0;
always @(posedge clk) begin
  if (srst) begin
    dout_0 <= 108'b0;
  end else begin
    dout_0 <= i_dout;
  end
end

assign dout = dout_0;
assign full = i_full;
assign empty = i_empty;
assign data_count = i_data_count;

endmodule