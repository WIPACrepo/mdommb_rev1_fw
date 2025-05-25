// Aaron Fienberg
//
// Test bench for integrating the waveform buffer, three secondary buffers, 
// the wvb_reader, and the hbuf controller
// 

`timescale 1ns/1ns

module multi_scdb_24_channel_integration_tb();

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

reg[P_LTC_WIDTH-1:0] ltc = 0;
// each channel will have its ADC samples equal to LTC + channel_index 
reg[11:0] adc_in[0:23];
integer i_chan;
always @(*) begin
  for (i_chan = 0; i_chan < 24; i_chan = i_chan + 1) begin
    adc_in[i_chan] = ltc + i_chan;
  end
end

reg rst = 1;

reg[7:0] discr_in = 5;
reg[23:0] trig = 0;
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

// instantiate 24 waveform buffers
generate
genvar i;
for (i = 0; i < 24; i = i + 1) begin
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
    .adc_in(adc_in[i]),
    .discr_in(discr_in), 
    .tot(trig[i]),
    .trig(trig[i]),
    .trig_src(trig_src),
    .arm(1'b0),

    .wvb_rdreq(wvb_rdreq[i]),
    .hdr_rdreq(wvb_hdr_rdreq[i]),
    .wvb_rddone(wvb_rddone[i]),

    // Config inputs
    .pre_conf(4),
    .post_conf(post_conf),
    // .test_conf(test_conf),
    .test_conf(test_conf + (i << 3)), // test different waveform lengths for each channel
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

// instantiate three secondary buffer;
// split channels into groups of 8 (0-7, 8-15, 16-23)
localparam P_N_SCDB = 3;
localparam P_CHANS_PER_SCDB = 24 / P_N_SCDB;
wire[P_N_SCDB - 1:0] buf_rdreq;
wire[P_N_SCDB - 1:0] buf_hdr_rdreq;
wire[P_N_SCDB - 1:0] buf_rddone;

wire[P_N_SCDB * P_READER_DATA_WIDTH - 1:0] buf_data_out;
wire[P_N_SCDB * L_WIDTH_MDOM_SCDB_HDR_BUNDLE - 1:0] buf_hdr_data_out;
wire[P_N_SCDB - 1 : 0] buf_hdr_empty;
wire[15:0] n_wvf_in_scdb[0 : P_N_SCDB - 1];
wire[15:0] scdb_wds_used[0 : P_N_SCDB - 1];

reg secondary_buffer_enable = 0;
generate 
for (i = 0; i < P_N_SCDB; i = i + 1) begin
  secondary_buffer
  #(
    .N_CHANNELS(8),
    .CHANNELS_PER_CYCLE(2),
    .P_CHANNEL_OFFSET(i * P_CHANS_PER_SCDB))
  SCDB
  (
    .clk(clk),
    .rst(rst),
    .en(secondary_buffer_enable),
    .buf_data_out
    (
      buf_data_out[(i+1)*P_READER_DATA_WIDTH-1:i*P_READER_DATA_WIDTH]
    ),
    .hdr_data_out(
      buf_hdr_data_out[(i+1)*L_WIDTH_MDOM_SCDB_HDR_BUNDLE-1:i*L_WIDTH_MDOM_SCDB_HDR_BUNDLE]
    ),
    .buf_hdr_empty(buf_hdr_empty[i]),
    .n_wvf_in_buf(n_wvf_in_scdb[i]),
    .buf_wds_used(scdb_wds_used[i]),
    .buf_rdreq(buf_rdreq[i]),
    .buf_hdr_rdreq(buf_hdr_rdreq[i]),
    .buf_rddone(buf_rddone[i]),
    .wvb_hdr_rdreq(wvb_hdr_rdreq[(i+1)*P_CHANS_PER_SCDB - 1 : i*P_CHANS_PER_SCDB]),
    .wvb_rdreq(wvb_rdreq[(i+1)*P_CHANS_PER_SCDB - 1 : i*P_CHANS_PER_SCDB]),
    .wvb_rddone(wvb_rddone[(i+1)*P_CHANS_PER_SCDB - 1 : i*P_CHANS_PER_SCDB]),
    .wvb_data(
      wvb_out[(i+1)*P_CHANS_PER_SCDB*P_DATA_WIDTH - 1 :
              i*P_CHANS_PER_SCDB*P_DATA_WIDTH]
    ),
    .wvb_hdr_data(
      hdr_out[(i+1)*P_CHANS_PER_SCDB*L_WIDTH_MDOM_WVB_HDR_BUNDLE_4 - 1 : 
              i*P_CHANS_PER_SCDB*L_WIDTH_MDOM_WVB_HDR_BUNDLE_4]
    ),
    .wvb_hdr_empty(hdr_empty[(i+1)*P_CHANS_PER_SCDB - 1 : i*P_CHANS_PER_SCDB])
  );
end
endgenerate

// instantiate wvb reader
wire[7:0] dpram_a;
wire[127:0] dpram_data;

wire dpram_wren;
wire[15:0] dpram_len_in;
wire dpram_run;
reg dpram_mode = 0;
reg dpram_done = 0;
wire dpram_busy;

wire reader_enable = secondary_buffer_enable;

wvb_reader
#(.N_CHANNELS(P_N_SCDB),
  .P_DATA_WIDTH(P_READER_DATA_WIDTH),
  .P_WVB_ADR_WIDTH(L_WIDTH_MDOM_SCDB_HDR_BUNDLE_START_ADDR),
  .P_HDR_WIDTH(L_WIDTH_MDOM_SCDB_HDR_BUNDLE),
  .P_FMT(3))
WVB_READER
(
  .clk(clk),
  .rst(rst),
  // .en(reader_enable && (ltc > 19000)),
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
reg[7:0] ddr3_dpram_rd_addr = 0;
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

// trigger the channels off by 1 clock cycle from each other
generate
for (i = 1; i < 24; i = i + 1) begin
  always @(posedge clk) begin
    trig[i] <= trig[i - 1]; // 24 channel test
    // trig[i] <= 0; // one channel test
  end
end
endgenerate


always @(posedge clk) begin
  ltc <= ltc + 1;

  if (!rst) begin
    discr_in <= discr_in + 1;
  end

  trig[0] <= 0;
  trig_src <= 0;

  if (ltc == 5) begin
    rst <= 0;
  end

  if (ltc == 149) begin
    test_conf <= 16; // short wfms
    // test_conf <= 1024; // long wfms (will be split up)
  end

  if (ltc >= 159
      // && ltc < 400
    ) 
  begin
    trig[0] <= 1;
    trig_src <= 3;
  end

  if (ltc == 39) begin
    start_pg <= 5;
    stop_pg <= 15;
  end

  if (ltc == 49) begin
    hbuf_en <= 1;
  end  

  if (ltc == 99) begin
    secondary_buffer_enable <= 1;
  end

end

// page clear reqs
always @(posedge clk) begin
  if (pg_clr_req && pg_clr_ack) begin
    pg_clr_req <= 0;
  end else if (ltc == 9319) begin
    pg_clr_req <= 1;
    // pg_clr_cnt <= 1;
    pg_clr_cnt <= 100;
  end
end

// flush reqs
always @(posedge clk) begin
  if (flush_req && flush_ack) begin
    flush_req <= 0;
  end else if (ltc == 13819) begin
    flush_req <= 1;
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
      if (wait_cnt == 0) begin
        ddr3_dpram_rd_addr <= 0;
      end else if (ddr3_dpram_rd_addr < 255) begin
        ddr3_dpram_rd_addr <= ddr3_dpram_rd_addr + 1;
      end
    end else begin
      pg_ack <= 1;
      wait_cnt <= 0;
    end
  end

  if (pg_ack && !pg_req_sync) begin
    pg_ack <= 0;
  end
end

wire[15:0] rd_pg_dpram_word_0 = ddr3_dpram_dout[15:0];
wire[15:0] rd_pg_dpram_word_1 = ddr3_dpram_dout[31:16];
wire[15:0] rd_pg_dpram_word_2 = ddr3_dpram_dout[47:32];
wire[15:0] rd_pg_dpram_word_3 = ddr3_dpram_dout[63:48];
wire[15:0] rd_pg_dpram_word_4 = ddr3_dpram_dout[79:64];
wire[15:0] rd_pg_dpram_word_5 = ddr3_dpram_dout[95:80];
wire[15:0] rd_pg_dpram_word_6 = ddr3_dpram_dout[111:96];
wire[15:0] rd_pg_dpram_word_7 = ddr3_dpram_dout[127:112];

wire[11:0] rd_pg_adc_word_0 = rd_pg_dpram_word_0[11:0];
wire[11:0] rd_pg_adc_word_1 = rd_pg_dpram_word_2[11:0];
wire[11:0] rd_pg_adc_word_2 = rd_pg_dpram_word_4[11:0];
wire[11:0] rd_pg_adc_word_3 = rd_pg_dpram_word_6[11:0];

wire[7:0] rd_pg_channel_idx_a = rd_pg_dpram_word_0;
wire[7:0] rd_pg_channel_idx_b = rd_pg_dpram_word_4;

reg[15:0] prev_word_6 = 0;
reg[15:0] prev_word_7 = 0;
always @(posedge ddr3_clk) begin
  prev_word_6 <= rd_pg_dpram_word_6;
  prev_word_7 <= rd_pg_dpram_word_7;
end

wire[48:0] rd_pg_ltc_a = {rd_pg_dpram_word_3, 
                          rd_pg_dpram_word_4,
                          rd_pg_dpram_word_5,
                          rd_pg_dpram_word_2[2]};
wire[48:0] rd_pg_ltc_b = {prev_word_7, 
                          rd_pg_dpram_word_0,
                          rd_pg_dpram_word_1,
                          prev_word_6[2]};
endmodule