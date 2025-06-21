// Aaron Fienberg
//
// Test bench for integrating the waveform buffer, three secondary buffers,
// the wvb_reader, and the hbuf controller
//

`timescale 1ns/1ns

module local_coinc_wr_ctrl_tb();

`include "mDOM_wvb_hdr_bundle_4_inc.v"
`include "mDOM_scdb_hdr_bundle_inc.v"
localparam P_WVB_ADR_WIDTH = 9;
localparam P_DATA_WIDTH = 170;
localparam P_READER_DATA_WIDTH = 85;
localparam P_LTC_WIDTH = 49;

parameter CLK_PERIOD = 10;

reg clk;
initial begin
  // clock initialization
  clk = 1'b0;
end

// clock drivers
always @(clk)
  #(CLK_PERIOD / 2.0) clk <= !clk;

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
wire[1:0] trig_src = 1;
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
reg[7:0] post_conf = 11;
reg wvb_rst = 0;

// instantiate local coincidence module
wire[23:0] local_coinc;

local_coincidence lc(
  .local_coinc(local_coinc),
  .clk(clk),
  .rst(rst),
  // LC window must be < pre_conf + post_conf
  .lc_window_width(14),
  .n_lc_thr(2),
  .trig(trig)
);

reg[23:0] wvb_trig = 0;
reg[23:0] wvb_lc = 0;
// register tr, lc to replicate pipelining in waveform acquisition modules
always @(posedge clk) begin
  wvb_trig <= trig;
  wvb_lc <= local_coinc;
end

// local coincidence required
reg lc_required = 0;

// instantiate 24 waveform buffers
generate
genvar i;
for (i = 0; i < 24; i = i + 1) begin : wvb_gen
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
    .tot(wvb_trig[i]),
    .trig(wvb_trig[i]),
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
    .local_coinc(wvb_lc),
    .lc_required(lc_required)
    );
  end
endgenerate

always @(posedge clk) begin
  ltc <= ltc + 1;

  if (!rst) begin
    discr_in <= discr_in + 1;
  end

  trig <= 0;

  if (ltc == 5) begin
    rst <= 0;
    lc_required <= 0;
  end

  if (ltc == 149) begin
    // trigger a single channel without LC required
    trig[0] <= 1;
  end

  if (ltc == 167) begin
    // trigger a single channel without LC required
    lc_required <= 1;
  end

  if (ltc == 169) begin
    // trigger a single channel with LC required
    trig[0] <= 1'b1;
  end

  if (ltc == 199) begin
    trig[0] <= 1'b1;
  end

  if (ltc == 213) begin
    trig[1] <= 1'b1;
  end

  if (ltc == 215) begin
    trig[0] <= 1'b1;
  end

  // fill up channel 0 buffer, ensure split events and overflow events are written into the buffer
  if (ltc > 299) begin
    trig[0] <= 1;
  end
end

wire wvb_hdr_data_lc = wvb_gen[0].WVB.hdr_data_in[99];

endmodule