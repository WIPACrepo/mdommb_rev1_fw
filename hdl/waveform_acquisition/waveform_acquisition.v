// Aaron Fienberg
// November 2020
//
// mDOM waveform triggering & buffering;
// adapted from arty S7 prototype project
//

module waveform_acquisition #(parameter P_DATA_WIDTH = 22,
                              parameter P_ADR_WIDTH = 12,
                              parameter P_HDR_WIDTH = 80,
                              parameter P_LTC_WIDTH = 48,
                              parameter P_N_WVF_IN_BUF_WIDTH = 16,
                              parameter P_WVB_TRIG_BUNDLE_WIDTH = 20,
                              parameter P_WVB_CONFIG_BUNDLE_WIDTH = 40,
                              parameter P_RATE_SCALER_STS_BUNDLE_WIDTH = 35,
                              parameter P_RATE_SCALER_CTRL_BUNDLE_WIDTH = 64)
(
  input clk,
  input rst,

  // adc and discr data streams
  input[11:0] adc_data,
  input[7:0] discr_data,

  // WVB reader interface
  output[P_DATA_WIDTH-1:0] wvb_data_out,
  output[P_HDR_WIDTH-1:0]  wvb_hdr_data_out,
  output wvb_hdr_full,
  output wvb_hdr_empty,
  output[P_N_WVF_IN_BUF_WIDTH-1:0] wvb_n_wvf_in_buf,
  output[15:0] wvb_wused,
  input wvb_hdr_rdreq,
  input wvb_wvb_rdreq,
  input wvb_wvb_rddone,

  // Local time counter
  input [P_LTC_WIDTH-1:0] ltc_in,

  // External
  input ext_trig_in,
  output wvb_trig_out,
  output wvb_trig_test_out,

  // Rate scaler
  // input[P_RATE_SCALER_CTRL_BUNDLE_WIDTH-1:0] rate_scaler_ctrl_bundle,
  // output[P_RATE_SCALER_STS_BUNDLE_WIDTH-1:0] rate_scaler_sts_bundle,

  // XDOM interface
  // temporary send "arm" and "run"
  // separately from the trigger bundle
  input xdom_arm,
  input xdom_trig_run,
  input[P_WVB_TRIG_BUNDLE_WIDTH-1:0] xdom_wvb_trig_bundle,
  input[P_WVB_CONFIG_BUNDLE_WIDTH-1:0] xdom_wvb_config_bundle,
  output          xdom_wvb_armed,
  output          xdom_wvb_overflow
);

// register synchronous reset & xdom bundles
(* max_fanout = 20 *) reg i_rst = 0;
(* DONT_TOUCH = "true" *) reg[P_WVB_TRIG_BUNDLE_WIDTH-1:0] i_xdom_wvb_trig_bundle = 0;
(* DONT_TOUCH = "true" *) reg[P_WVB_CONFIG_BUNDLE_WIDTH-1:0] i_xdom_wvb_config_bundle= 0;
always @(posedge clk) begin
  i_rst <= rst;
  i_xdom_wvb_trig_bundle <= xdom_wvb_trig_bundle;
  i_xdom_wvb_config_bundle <= xdom_wvb_config_bundle;
end

// trig fan out
wire wvb_trig_et;
wire wvb_trig_gt;
wire wvb_trig_lt;

// temporarily unused
wire wvb_bundle_trig_run;
// used xdom trig_run instead
wire wvb_trig_run = xdom_trig_run;

wire wvb_trig_discr_trig_pol;
wire [11:0] wvb_trig_thr;
wire wvb_trig_discr_trig_en;
wire wvb_trig_thresh_trig_en;
wire wvb_trig_ext_trig_en;
mDOM_trig_bundle_fan_out TRIG_FAN_OUT
  (
   .bundle(i_xdom_wvb_trig_bundle),
   .trig_et(wvb_trig_et),
   .trig_gt(wvb_trig_gt),
   .trig_lt(wvb_trig_lt),
   .trig_run(wvb_bundle_trig_run),
   .discr_trig_pol(wvb_trig_discr_trig_pol),
   .trig_thresh(wvb_trig_thr),
   .disc_trig_en(wvb_trig_discr_trig_en),
   .thresh_trig_en(wvb_trig_thresh_trig_en),
   .ext_trig_en(wvb_trig_ext_trig_en)
  );

// wvb config bundle fan out
wire[11:0] wvb_cnst_config;
wire[7:0] wvb_post_config;
wire[4:0] wvb_pre_config;
wire[11:0] wvb_test_config;

// temporarily unused
wire wvb_bundle_arm;
// used "xdom_arm" input instead
wire wvb_arm = xdom_arm;

wire wvb_trig_mode;
wire wvb_cnst_run;
mDOM_wvb_conf_bundle_fan_out CONF_FAN_OUT
  (
   .bundle(i_xdom_wvb_config_bundle),
   .cnst_conf(wvb_cnst_config),
   .test_conf(wvb_test_config),
   .post_conf(wvb_post_config),
   .pre_conf(wvb_pre_config),
   .arm(wvb_bundle_arm),
   .trig_mode(wvb_trig_mode),
   .cnst_run(wvb_cnst_run)
  );

//
// raw data streams
//
wire[11:0] adc_data_stream_0 = adc_data;
wire[7:0] discr_data_stream_0 = discr_data;

wire[11:0] adc_data_stream_1;
wire[7:0] discr_data_stream_1;
wire[1:0] trig_src;
wire wvb_trig;
wire thresh_tot;
wire discr_tot;
mdom_trigger MDOM_TRIG
  (
   .clk(clk),
   .rst(i_rst),

   // data stream in and out
   .adc_stream_in(adc_data_stream_0),
   .adc_stream_out(adc_data_stream_1),
   .discr_stream_in(discr_data_stream_0),
   .discr_stream_out(discr_data_stream_1),

   // threshold trigger settings
   .gt(wvb_trig_gt),
   .et(wvb_trig_et),
   .lt(wvb_trig_lt),
   .thr(wvb_trig_thr),
   .thresh_trig_en(wvb_trig_thresh_trig_en),

   // sw trig
   .run(wvb_trig_run),

   // ext trig
   .ext_trig_en(wvb_trig_ext_trig_en),
   .ext_run(ext_trig_in),

   // discr trig
   .discr_trig_en(wvb_trig_discr_trig_en),
   .discr_trig_pol(wvb_trig_discr_trig_pol),

   // trigger outputs
   .trig_src(trig_src),
   .trig(wvb_trig),
   .thresh_tot(thresh_tot),
   .discr_tot(discr_tot)
  );
assign wvb_trig_out = wvb_trig;

waveform_buffer
  #(.P_DATA_WIDTH(P_DATA_WIDTH),
    .P_ADR_WIDTH(P_ADR_WIDTH),
    .P_HDR_WIDTH(P_HDR_WIDTH),
    .P_LTC_WIDTH(P_LTC_WIDTH),
    .P_N_WVF_IN_BUF_WIDTH(P_N_WVF_IN_BUF_WIDTH)
   )
 WVB
  (
   // Outputs
   .wvb_wused(wvb_wused),
   .n_wvf_in_buf(wvb_n_wvf_in_buf),
   .wvb_overflow(xdom_wvb_overflow),
   .armed(xdom_wvb_armed),
   .wvb_data_out(wvb_data_out),
   .hdr_data_out(wvb_hdr_data_out),
   .hdr_full(wvb_hdr_full),
   .hdr_empty(wvb_hdr_empty),

   // Inputs
   .clk(clk),
   .rst(i_rst),
   .ltc_in(ltc_in),
   .adc_in(adc_data_stream_1),
   .discr_in(discr_data_stream_1),
   // .tot(discr_tot || thresh_tot),
   .tot(thresh_tot),
   .trig(wvb_trig),
   .trig_src(trig_src),
   .arm(wvb_arm),

   .wvb_rdreq(wvb_wvb_rdreq),
   .hdr_rdreq(wvb_hdr_rdreq),
   .wvb_rddone(wvb_wvb_rddone),

   // Config inputs
   .pre_conf(wvb_pre_config),
   .post_conf(wvb_post_config),
   .test_conf(wvb_test_config),
   .cnst_run(wvb_cnst_run),
   .cnst_conf(wvb_cnst_config),
   .trig_mode(wvb_trig_mode)
  );

endmodule