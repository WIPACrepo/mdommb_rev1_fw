// Aaron Fienberg
//
// Test bench for integrating the waveform buffer, secondary buffer, wvb_reader, hbuf controller
// 

`timescale 1ns/1ns

module hbuf_ctrl_integration_tb();

`include "mDOM_wvb_hdr_bundle_4_inc.v"
`include "mDOM_scdb_hdr_bundle_inc.v"
localparam P_WVB_ADR_WIDTH = 9;
localparam P_DATA_WIDTH = 170;
localparam P_READER_DATA_WIDTH = 85;
localparam P_LTC_WIDTH = 49;

parameter CLK_PERIOD = 10;
parameter DDR3_CLK_PERIOD = 15;

reg clk;
reg ddr3_clk;
initial begin
  // clock initialization        
  clk = 1'b0;
  ddr3_clk = 1'b0;    
end

// clock drivers
always @(clk)
  #(CLK_PERIOD / 2.0) clk <= !clk;

always @(ddr3_clk)
  #(DDR3_CLK_PERIOD / 2.0) ddr3_clk <= !ddr3_clk;

// dynamic inputs
reg rst = 1;
reg[11:0] adc_in = 0;
// second channel will have adc samples off by 5
wire[11:0] adc_in_2 = adc_in + 5;
reg[7:0] discr_in = 5;
reg trig = 0;
reg[P_LTC_WIDTH-1:0] ltc = 0;
reg[1:0] trig_src = 0;
wire[23:0] wvb_rdreq;
wire[23:0] wvb_hdr_rdreq;
wire[23:0] wvb_rddone;

wire[15:0] wvb_wused[0:23];
wire[15:0] wvb_n_wvf_in_buf[0:23];
wire overflow_out[0:23];
wire[P_DATA_WIDTH*24 - 1:0] wvb_out;

wire[L_WIDTH_MDOM_WVB_HDR_BUNDLE_4*24-1:0] hdr_out;
wire[23:0] hdr_full;
wire[23:0] hdr_empty;

reg[11:0] test_conf = 128;
reg[11:0] cnst_conf = 128;
reg cnst_run = 0;
reg[7:0] post_conf = 8;
reg wvb_rst = 0;

// trigger the two channels off-by-two clock cycles
reg trig_1 = 0;
reg trig_2 = 0;
always @(posedge clk) begin
  trig_1 <= trig;
  trig_2 <= trig_1;
end

// instantiate 24 waveform buffers
// for now, triggers will only make it into two channels: 23 and 5
generate
genvar i;
for (i = 0; i < 24; i = i + 1) begin
  // only send triggers to two channels
  wire trig_i = i == 23 ? trig : i == 5 ? trig_2 : 0;
  waveform_buffer
  #(.P_DATA_WIDTH(P_DATA_WIDTH),
    .P_ADR_WIDTH(P_WVB_ADR_WIDTH),
    .P_HDR_WIDTH(L_WIDTH_MDOM_WVB_HDR_BUNDLE_4),
    .P_LTC_WIDTH(P_LTC_WIDTH),
    .P_N_WVF_IN_BUF_WIDTH(16),
    .P_BSUM_WIDTH(19),
    .P_BSUM_LEN_SEL_WIDTH(3)
    )
  WVB
    (
    // Outputs
    .wvb_wused(wvb_wused[i]),
    .n_wvf_in_buf(wvb_n_wvf_in_buf[i]),
    .wvb_overflow(overflow_out[i]),
    .armed(),   
    .wvb_data_out(wvb_out[P_DATA_WIDTH*(i+1)-1 : P_DATA_WIDTH*i]),
    .hdr_data_out(hdr_out[L_WIDTH_MDOM_WVB_HDR_BUNDLE_4*(i+1)-1 : L_WIDTH_MDOM_WVB_HDR_BUNDLE_4*i]),
    .hdr_full(hdr_full[i]),
    .hdr_empty(hdr_empty[i]),

    // Inputs
    .clk(clk),
    .rst(rst || wvb_rst),
    .ltc_in(ltc),
    .adc_in(i == 23 ? adc_in : i == 5 ? adc_in_2 : 0),
    .discr_in(discr_in), 
    .tot(trig_i),
    .trig(trig_i),
    .trig_src(trig_src),
    .arm(1'b0),

    .wvb_rdreq(wvb_rdreq[i]),
    .hdr_rdreq(wvb_hdr_rdreq[i]),
    .wvb_rddone(wvb_rddone[i]),

    // Config inputs
    .pre_conf(4),
    .post_conf(post_conf),
    .test_conf(test_conf),
    .cnst_run(cnst_run),
    .cnst_conf(cnst_conf),
    .trig_mode(0),

    .icm_sync_rdy(1'b1),
    .bsum(19'b1),
    .bsum_len_sel(3'b1),
    .bsum_valid(1'b1),
    .local_coinc(1'b0)
    );
  end
endgenerate

wire overflow_out_5 = overflow_out[5];
wire overflow_out_23 = overflow_out[23];
wire[15:0] n_wvf_in_buf_5 = wvb_n_wvf_in_buf[5];
wire[15:0] n_wvf_in_buf_23 = wvb_n_wvf_in_buf[23];


// instantiate secondary buffer
wire buf_rdreq;
wire buf_hdr_rdreq;
wire buf_rddone;

wire[84:0] buf_data_out;
wire[112:0] buf_hdr_data_out;
wire buf_hdr_empty;
wire[15:0] n_wvf_in_scdb;
wire[15:0] scdb_wds_used;

reg secondary_buffer_enable = 0;
secondary_buffer
SCDB
(
  .clk(clk),
  .rst(rst),
  .en(secondary_buffer_enable),
  .buf_data_out(buf_data_out),
  .hdr_data_out(buf_hdr_data_out),
  .buf_hdr_empty(buf_hdr_empty),
  .n_wvf_in_buf(n_wvf_in_scdb),
  .buf_wds_used(scdb_wds_used),
  .buf_rdreq(buf_rdreq),
  .buf_hdr_rdreq(buf_hdr_rdreq),
  .buf_rddone(buf_rddone),
  .wvb_hdr_rdreq(wvb_hdr_rdreq),
  .wvb_rdreq(wvb_rdreq),
  .wvb_rddone(wvb_rddone),
  .wvb_data(wvb_out),
  .wvb_hdr_data(hdr_out),
  .wvb_hdr_empty(hdr_empty)
);

// instantiate wvb reader
wire[7:0] dpram_a;
wire[127:0] dpram_data;

wire[15:0] dpram_word_0 = dpram_data[15:0];
wire[15:0] dpram_word_1 = dpram_data[31:16];
wire[15:0] dpram_word_2 = dpram_data[47:32];
wire[15:0] dpram_word_3 = dpram_data[63:48];
wire[15:0] dpram_word_4 = dpram_data[79:64];
wire[15:0] dpram_word_5 = dpram_data[95:80];
wire[15:0] dpram_word_6 = dpram_data[111:96];
wire[15:0] dpram_word_7 = dpram_data[127:112];

wire[11:0] adc_word_0 = dpram_word_0[11:0];
wire[11:0] adc_word_1 = dpram_word_2[11:0];
wire[11:0] adc_word_2 = dpram_word_4[11:0];
wire[11:0] adc_word_3 = dpram_word_6[11:0];

wire[7:0] channel_idx = dpram_word_0;
wire[15:0] hdr_0 = dpram_word_2;
wire[48:0] header_ltc = {dpram_word_3, dpram_word_4, dpram_word_5, hdr_0[2]};

wire tot[0:3];
assign tot[0] = dpram_word_1[1];
assign tot[1] = dpram_word_3[1];
assign tot[2] = dpram_word_5[1];
assign tot[3] = dpram_word_7[1];

wire dpram_wren;
wire[15:0] dpram_len_in;
wire dpram_run;
reg dpram_mode = 0;
reg dpram_done = 0;
wire dpram_busy;

wire reader_enable = secondary_buffer_enable;

wvb_reader
#(.N_CHANNELS(1),
  .P_DATA_WIDTH(P_READER_DATA_WIDTH),
  .P_WVB_ADR_WIDTH(L_WIDTH_MDOM_SCDB_HDR_BUNDLE_START_ADDR),
  .P_HDR_WIDTH(L_WIDTH_MDOM_SCDB_HDR_BUNDLE),
  .P_FMT(3))
WVB_READER
(
  .clk(clk),
  .rst(rst),
  .en(reader_enable),
  .dpram_data(dpram_data),
  .dpram_addr(dpram_a),
  .dpram_wren(dpram_wren),
  .dpram_len(dpram_len_in),
  .dpram_run(dpram_run),
  .dpram_busy(dpram_busy),
  .dpram_mode(dpram_mode),
  .hdr_rdreq(buf_hdr_rdreq),
  .wvb_rdreq(buf_rdreq),
  .wvb_rddone(buf_rddone),
  .wvb_data(buf_data_out),
  .hdr_data(buf_hdr_data_out),
  .hdr_empty(buf_hdr_empty)
);

reg hbuf_en = 0;
reg[15:0] start_pg = 0;
wire[15:0] first_pg;
wire[15:0] last_pg;
reg[15:0] stop_pg = 0;
reg flush_req = 0;
wire flush_ack;
wire buffered_data;

wire[15:0] rd_pg_num;
wire[15:0] wr_pg_num;
wire[15:0] n_used_pgs;

wire pg_req;
reg pg_ack = 0;
wire[27:0] pg_addr;

reg[15:0] pg_clr_cnt = 1;
reg pg_clr_req = 0;
wire pg_clr_ack;
wire empty;
wire full;

wire[127:0] ddr3_dpram_dout;
wire[7:0] ddr3_dpram_rd_addr;
wire pg_optype;

hbuf_ctrl HBUF_CTRL_0
(
 .clk(clk),
 .rst(1'b0),
 .en(hbuf_en),
 .start_pg(start_pg),
 .stop_pg(stop_pg),
 .first_pg(first_pg),
 .last_pg(last_pg),
 .flush_req(flush_req),
 .flush_ack(flush_ack),
 .empty(empty),
 .full(full),
 .rd_pg_num(rd_pg_num),
 .wr_pg_num(wr_pg_num),
 .n_used_pgs(n_used_pgs),
 .pg_clr_cnt(pg_clr_cnt),
 .pg_clr_req(pg_clr_req),
 .pg_clr_ack(pg_clr_ack),
 
 .buffered_data(buffered_data),
 
 .dpram_len_in(dpram_len_in),
 .rdout_dpram_run(dpram_run),
 .dpram_busy(dpram_busy),
 .rdout_dpram_wren(dpram_wren),
 .rdout_dpram_wr_addr(dpram_a),
 .rdout_dpram_data(dpram_data),
 .ddr3_ui_clk(ddr3_clk),
 .ddr3_dpram_dout(ddr3_dpram_dout),
 .ddr3_dpram_rd_addr(ddr3_dpram_rd_addr),

 .pg_ack(pg_ack),
 .pg_req(pg_req),
 .pg_optype(pg_optype),
 .pg_addr(pg_addr)
);

wire[15:0] pg_dpram_word_0 = HBUF_CTRL_0.pg_dpram_din[15:0];
wire[15:0] pg_dpram_word_1 = HBUF_CTRL_0.pg_dpram_din[31:16];
wire[15:0] pg_dpram_word_2 = HBUF_CTRL_0.pg_dpram_din[47:32];
wire[15:0] pg_dpram_word_3 = HBUF_CTRL_0.pg_dpram_din[63:48];
wire[11:0] pg_dpram_adc_word_0 = pg_dpram_word_0[11:0];
wire[11:0] pg_dpram_adc_word_1 = pg_dpram_word_2[11:0];
wire[15:0] pg_dpram_evt_len = pg_dpram_word_1;
wire[7:0] pg_dpram_channel_number = pg_dpram_word_0[7:0];
wire[33:0] pg_dpram_evt_ltc_low = {pg_dpram_word_0, pg_dpram_word_1, 1'b0}; 

wire[8:0] pg_dpram_wr_addr = HBUF_CTRL_0.pg_dpram_wr_addr;
wire pg_dpram_wren = HBUF_CTRL_0.pg_dpram_wren;

always @(posedge clk) begin
  ltc <= ltc + 1;

  if (!rst) begin
    adc_in <= adc_in + 1;
    discr_in <= discr_in + 1;
  end

  trig <= 0;
  trig_src <= 0;

  if (ltc == 5) begin
    rst <= 0;
  end

  // continuous triggers w/ wfm length 2
  if (ltc == 149) begin
    test_conf <=128;
  end

  if (ltc >= 159) begin
    trig <= 1;
    trig_src <= 3;
  end

  if (ltc == 39) begin
    start_pg <= 5;
    stop_pg <= 15;
  end

  if (ltc == 49) begin
    hbuf_en <= 1;
  end  

  // check whether secondary buffer can keep up with 1 channel
  // start secondary buffer early
  if (ltc == 99) begin
    secondary_buffer_enable <= 1;
  end

end

// handle page reqs, acks
// simulate time to transfer a page (~270 clock cycles in the DDR3 clock domain)
wire pg_req_sync;
sync HREQSYNC(.clk(ddr3_clk), .rst_n(1'b1), .a(pg_req), .y(pg_req_sync));

localparam PG_TRANSFER_WAIT_CNT_MAX = 269;
reg[31:0] wait_cnt = 0;
always @(posedge ddr3_clk) begin
  wait_cnt <= 0;
  pg_ack <= pg_ack;

  if (pg_req_sync && !pg_ack) begin
    if (wait_cnt < PG_TRANSFER_WAIT_CNT_MAX) begin
      wait_cnt <= wait_cnt + 1;
    end else begin
      pg_ack <= 1;
      wait_cnt <= 0;
    end
  end

  if (pg_ack && !pg_req_sync) begin
    pg_ack <= 0;
  end
end

endmodule