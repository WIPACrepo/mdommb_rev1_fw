// Aaron Fienberg
//
// Test bench for basic secondary buffer functionality
// 

`timescale 1ns/1ns

module secondary_buffer_tb();

`include "mDOM_wvb_hdr_bundle_4_inc.v"
localparam P_WVB_ADR_WIDTH = 9;
localparam P_DATA_WIDTH = 170;
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
wire[23:0] wvb_rdreq;
wire[23:0] wvb_hdr_rdreq;
wire[23:0] wvb_rddone;

wire[15:0] wvb_wused;
wire[15:0] wvb_n_wvf_in_buf;
wire overflow_out;
wire[P_DATA_WIDTH*24 - 1:0] wvb_out;

wire[L_WIDTH_MDOM_WVB_HDR_BUNDLE_4*24-1:0] hdr_out;
wire[23:0] hdr_full;
wire[23:0] hdr_empty;

assign hdr_full[23:1] = 0;
assign hdr_empty[23:1] = {23{1'b1}};
assign hdr_out[L_WIDTH_MDOM_WVB_HDR_BUNDLE_4*24-1:L_WIDTH_MDOM_WVB_HDR_BUNDLE_4] = 0;
assign wvb_out[P_DATA_WIDTH*24 - 1:P_DATA_WIDTH] = 0;

reg[11:0] test_conf = 128;
reg[11:0] cnst_conf = 128;
reg cnst_run = 0;
reg[7:0] post_conf = 8;
reg wvb_rst = 0;

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
   .armed(),   
   .wvb_data_out(wvb_out[P_DATA_WIDTH-1:0]),
   .hdr_data_out(hdr_out[L_WIDTH_MDOM_WVB_HDR_BUNDLE_4-1:0]),
   .hdr_full(hdr_full[0]),
   .hdr_empty(hdr_empty[0]),

   // Inputs
   .clk(clk),
   .rst(rst || wvb_rst),
   .ltc_in(ltc),
   .adc_in(adc_in),
   .discr_in(discr_in), 
   .tot(trig),
   .trig(trig),
   .trig_src(trig_src),
   .arm(1'b0),

   .wvb_rdreq(wvb_rdreq[0]),
   .hdr_rdreq(wvb_hdr_rdreq[0]),
   .wvb_rddone(wvb_rddone[0]),

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

// instantiate secondary buffer
reg buf_rdreq = 0;
reg buf_hdr_rdreq = 0;
reg buf_rddone = 0;

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

  // external trigger at ltc == 45  
  if (ltc == 44) begin
    trig <= 1;
    trig_src <= 3;
  end

  // trigger again at ltc == 175
  if (ltc == 174) begin
    trig <= 1;
    trig_src <= 3;
  end

  if (ltc == 324) begin
    secondary_buffer_enable <= 1;
  end

end

endmodule