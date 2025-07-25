// Aaron Fienberg
//
// Test bench for verifying single trigger mode works correctly with split events
//


`timescale 1ns/1ns

module single_trigger_split_event_tb();

`include "mDOM_wvb_hdr_bundle_4_inc.v"
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

// clock driver
always @(clk)
  #(CLK_PERIOD / 2.0) clk <= !clk;

// dynamic inputs
reg rst = 1;
reg[11:0] adc_in = 0;
reg[7:0] discr_in = 5;
reg trig = 0;
reg[P_LTC_WIDTH-1:0] ltc = 0;
reg[1:0] trig_src = 0;
reg wvb_rdreq = 0;
reg hdr_rdreq = 0;
reg wvb_rddone = 0;

wire[15:0] wvb_wused;
wire[15:0] wvb_n_wvf_in_buf;
wire overflow_out;
wire[P_DATA_WIDTH - 1:0] wvb_out;

wire[L_WIDTH_MDOM_WVB_HDR_BUNDLE_4-1:0] hdr_out;
wire hdr_full;
wire hdr_empty;

reg[11:0] test_conf = 17;
reg[11:0] cnst_conf = 17;
reg cnst_run = 0;
reg[7:0] post_conf = 8;
reg wvb_rst = 0;
reg arm = 0;
wire armed;

// instantiate the waveform buffer
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
   .wvb_wused(wvb_wused),
   .n_wvf_in_buf(wvb_n_wvf_in_buf),
   .wvb_overflow(overflow_out),
   .armed(armed),
   .wvb_data_out(wvb_out),
   .hdr_data_out(hdr_out),
   .hdr_full(hdr_full),
   .hdr_empty(hdr_empty),

   // Inputs
   .clk(clk),
   .rst(rst || wvb_rst),
   .ltc_in(ltc),
   .adc_in(adc_in),
   .discr_in(discr_in),
   .tot(trig),
   .trig(trig),
   .trig_src(trig_src),
   .arm(arm),

   .wvb_rdreq(wvb_rdreq),
   .hdr_rdreq(hdr_rdreq),
   .wvb_rddone(wvb_rddone),

   // Config inputs
   .pre_conf(4),
   .post_conf(post_conf),
   .test_conf(test_conf),
   .cnst_run(cnst_run),
   .cnst_conf(cnst_conf),
   .trig_mode(1'b1),

   .icm_sync_rdy(1'b1),
   .bsum(19'b1),
   .bsum_len_sel(3'b1),
   .bsum_valid(1'b1),
   .local_coinc(1'b0)
  );

always @(posedge clk) begin
  ltc <= ltc + 1;
  arm <= 0;
  trig <= 0;
  trig_src <= 0;

  if (!rst) begin
    adc_in <= adc_in + 1;
    discr_in <= discr_in + 1;
  end

  trig <= 0;
  trig_src <= 0;

  if (ltc == 5) begin
    rst <= 0;
  end

  if (ltc == 9) begin

    arm <= 1;
  end

  // test continuous triggering case
  if (ltc >= 14 && ltc < 4999) begin
    trig_src <= 1;
    trig <= 1;
  end

  if (ltc == 3099) begin
    arm <= 1;
  end

  // reset the waveform buffer
  if (ltc == 4999) begin
    rst <= 1;
    cnst_run <= 1;
    cnst_conf <= 3072;
  end
  if (ltc == 5009) begin
    rst <= 0;
  end

  if (ltc == 5014) begin
    arm <= 1;
  end

  // trigger a constant readout of length 3072
  if (ltc == 5044) begin
    trig_src <= 1;
    trig <= 1;
  end
end

endmodule