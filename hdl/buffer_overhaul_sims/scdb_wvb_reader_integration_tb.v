// Aaron Fienberg
//
// Test bench for integrating the waveform buffer, secondary buffer, and wvb_reader
// 

`timescale 1ns/1ns

module scdb_wvb_reader_integration_tb();

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

assign hdr_full[22:0] = 0;
assign hdr_empty[22:0] = {23{1'b1}};
assign hdr_out[L_WIDTH_MDOM_WVB_HDR_BUNDLE_4*23-1:0] = 0;
assign wvb_out[P_DATA_WIDTH*23 - 1:0] = 0;

reg[11:0] test_conf = 128;
reg[11:0] cnst_conf = 128;
reg cnst_run = 0;
reg[7:0] post_conf = 8;
reg wvb_rst = 0;

// instantiate the waveform buffer
// make this channel 23 so we can verify channel info is making it through
// to the wvb_reader
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
   .wvb_data_out(wvb_out[P_DATA_WIDTH*24-1:P_DATA_WIDTH*23]),
   .hdr_data_out(hdr_out[L_WIDTH_MDOM_WVB_HDR_BUNDLE_4*24-1:L_WIDTH_MDOM_WVB_HDR_BUNDLE_4*23]),
   .hdr_full(hdr_full[23]),
   .hdr_empty(hdr_empty[23]),

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

   .wvb_rdreq(wvb_rdreq[23]),
   .hdr_rdreq(wvb_hdr_rdreq[23]),
   .wvb_rddone(wvb_rddone[23]),

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

  // // external trigger at ltc == 45  
  // if (ltc == 44) begin
  //   trig <= 1;
  //   trig_src <= 3;
  // end

  // overflow from a few long wfms
  // // trigger again at ltc == 175 with a long wfm
  // if (ltc == 169) begin
  //   test_conf <= 4095;
  // end
    
  // overflow from many short wfms (full header fifo)
  if (ltc == 169) begin
    // test_conf <= 8;
    test_conf <= 16;
    // test_conf <= 24;
    // test_conf <= 32;
    // test_conf <= 80;
  end
    
  if (ltc == 249) begin
    test_conf <= 24;
  end

  if (ltc >= 259) begin
    trig <= 1;
    trig_src <= 3;
  end
  // overflow test; start secondary buffer later
  if (ltc == 8999) begin
    secondary_buffer_enable <= 1;
  end

  // check whether secondary buffer can keep up with 1 channel
  // start secondary buffer early
  // if (ltc == 9) begin
  //   secondary_buffer_enable <= 1;
  // end

end

// 
// DPRAM user
// 

reg[8:0] rdout_dpram_rd_addr = 0;
wire[63:0] rdout_dpram_dout;
wire[15:0] dpram_len;
wire rd_busy;
double_buffer rdout_double_buffer (
  .rst(rst),
  .wr_clk(clk),
  .wr_en(dpram_wren),
  .wr_addr(dpram_a),
  .wr_din(dpram_data),
  .dpram_len_in(dpram_len_in),
  .run(dpram_run),
  .wr_busy(dpram_busy),
  .rd_clk(clk),
  .rd_addr(rdout_dpram_rd_addr),
  .rd_dout(rdout_dpram_dout),
  .dpram_len_out(dpram_len),
  .done(dpram_done),
  .rd_busy(rd_busy)
);

wire[31:0] max_rd_addr = (dpram_len >> 2) - 1; 

wire[15:0] reader_word_0 = rdout_dpram_dout[15:0];
wire[15:0] reader_word_1 = rdout_dpram_dout[31:16];
wire[15:0] reader_word_2 = rdout_dpram_dout[47:32];
wire[15:0] reader_word_3 = rdout_dpram_dout[63:48];

wire[11:0] reader_adc_word_0 = reader_word_0[11:0];
wire[11:0] reader_adc_word_1 = reader_word_2[11:0];

reg[31:0] cnt = 0;

// DPRAM reader
reg[31:0] read_start_ltc = 1000;
always @(posedge clk) begin
  dpram_done <= 0;
  cnt <= 0;

  if (rd_busy) begin
    rdout_dpram_rd_addr <= 0;
    // wait 3 cycles (simulate reader latency)
    cnt <= cnt + 1;

    if (cnt >= 3 && ltc >= read_start_ltc) begin
      rdout_dpram_rd_addr <= rdout_dpram_rd_addr + 1;

      if (rdout_dpram_rd_addr == max_rd_addr) begin
        rdout_dpram_rd_addr <= max_rd_addr;
        // for testing,
        // artificially slow down the reader so that the secondary buffer fills up
        // #10000
        if (!dpram_done) begin
          dpram_done <= 1;
        end
      end
    end
  end
end

endmodule