// Aaron Fienberg
//
// Test bench for overflow deadtime recording and recovery
//

`timescale 1ns/1ns

module overflow_recovery_tb();

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

wire overflow_fifo_req;
reg overflow_fifo_ack = 0;
wire[P_LTC_WIDTH-1:0] overflow_start_ltc;
wire[P_LTC_WIDTH-1:0] overflow_end_ltc;

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
   .arm(1'b0),

   .wvb_rdreq(wvb_rdreq),
   .hdr_rdreq(hdr_rdreq),
   .wvb_rddone(wvb_rddone),

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
   .local_coinc(1'b0),

   .overflow_fifo_ack(overflow_fifo_ack),
   .overflow_fifo_req(overflow_fifo_req),
   .overflow_start_ltc(overflow_start_ltc),
   .overflow_end_ltc(overflow_end_ltc)
  );

always @(posedge clk) begin
  ltc <= ltc + 1;

  if (!rst) begin
    adc_in <= adc_in + 1;
    discr_in <= discr_in + 1;
  end

  if (ltc == 5) begin
    rst <= 0;
  end

  trig <= 0;
  trig_src <= 0;

  // // overflow from full buffer and full fifo
  // if (ltc == 19) begin
  //   test_conf <= 32;
  // end

  // overflow from full buffer
  if (ltc == 19) begin
    test_conf <= 2040;
  end

  // overflow from full hdr fifo
  // if (ltc == 19) begin
  //   test_conf <= 16;
  // end

  // start continuous triggering to cause an overflow
  if (ltc > 44) begin
    trig <= 1;
    trig_src <= 3;
  end
end

// clear the buffers after there has been an overflow
reg[31:0] clear_cnt = 0;
always @(posedge clk) begin
  if (!overflow_out) begin
    clear_cnt <= 0;
  end else begin
    clear_cnt <= (clear_cnt + 1) % 5;
  end
end

always @(*) begin
  hdr_rdreq = overflow_out && (clear_cnt == 1);
  wvb_rddone = overflow_out && (clear_cnt == 4);
end

// acknowledge overflow req after two overflows have occurred

always @(posedge clk) begin
  if (ltc > 8999) begin
    overflow_fifo_ack <= overflow_fifo_req;
  end
end

endmodule