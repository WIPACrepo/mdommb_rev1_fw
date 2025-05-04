// Aaron Fienberg
// August 2020
//
// mDOM waveform buffer storage
//

module waveform_buffer_storage #(parameter P_DATA_WIDTH = 22,
	                               parameter P_ADR_WIDTH = 12,
	                               parameter P_HDR_WIDTH = 80,
	                               parameter P_N_WVF_IN_BUF_WIDTH = 16)
(
	input clk,
	input rst,

	output[P_DATA_WIDTH-1:0] wvb_data_out,
	output[P_HDR_WIDTH-1:0] hdr_data_out,
	output hdr_full,
	output hdr_empty,
	output[P_N_WVF_IN_BUF_WIDTH-1:0] n_wvf_in_buf,

	input eoe_in,
	input[P_DATA_WIDTH-1:0] wvb_data_in,
	input[P_ADR_WIDTH-1:0] wvb_wr_addr,
	input[P_ADR_WIDTH-1:0] wvb_rd_addr,
  input wvb_wrreq,
  input[P_HDR_WIDTH-1:0] hdr_data_in,
  input hdr_wrreq,
  input hdr_rdreq
);

wire[P_DATA_WIDTH-1:0] buff_din = {wvb_data_in[P_DATA_WIDTH-1:1], eoe_in};

wire[8:0] hdr_data_cnt;
generate
  if (P_ADR_WIDTH == 12) begin
    BUFFER_4096_22 WAVEFORM_DISCR_BUFF (
      .clka(clk),
      .wea(wvb_wrreq),
      .addra(wvb_wr_addr),
      .dina(buff_din),
      .clkb(clk),
      .addrb(wvb_rd_addr),
      .doutb(wvb_data_out)
    );

    wire[107:0] fifo_out;
    wire[6:0] dist_hdr_data_count;
    distributed_hdr_fifo DIST_HDR_FIFO (
      .clk(clk),
      .srst(rst),
      .din({{108-P_HDR_WIDTH{1'b0}}, hdr_data_in}),
      .wr_en(hdr_wrreq),
      .rd_en(hdr_rdreq),
      .dout(fifo_out),
      .full(hdr_full),
      .empty(hdr_empty),
      .data_count(dist_hdr_data_count)
    );
    assign hdr_data_cnt = {2'b0, dist_hdr_data_count};
    assign hdr_data_out = fifo_out[P_HDR_WIDTH-1:0];

  end

  else if (P_ADR_WIDTH == 10) begin
    BUFFER_1024_22 WAVEFORM_DISCR_BUFF (
       .clka(clk),
       .wea(wvb_wrreq),
       .addra(wvb_wr_addr),
       .dina(buff_din),
       .clkb(clk),
       .addrb(wvb_rd_addr),
       .doutb(wvb_data_out)
    );

    wire[71:0] fifo_out;
    FIFO_256_72 HDR_FIFO_FMT_0 (
      .clk(clk),
      .srst(rst),
      .din({1'b0, hdr_data_in}),
      .wr_en(hdr_wrreq),
      .rd_en(hdr_rdreq),
      .dout(fifo_out),
      .full(hdr_full),
      .empty(hdr_empty),
      .data_count(hdr_data_cnt)
    );
    assign hdr_data_out = fifo_out[70:0];
  end

  else begin
    invalid_p_adr_width invalid_module_conf();
  end

  // wire[9:0] i_n_wvf_in_buf = hdr_full ? 10'd512 : hdr_data_cnt;
  wire[9:0] i_n_wvf_in_buf = hdr_full ? 10'd128 : hdr_data_cnt;
  assign n_wvf_in_buf = {{(P_N_WVF_IN_BUF_WIDTH - 10){1'b0}},
                         i_n_wvf_in_buf};

endgenerate

endmodule