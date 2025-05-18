// Aaron Fienberg
//
// Test bench for the overhauled mDOM waveform buffer that moves eight words per clock cycle
// 
// Tests various triggering and overflow cases as well as the fmt_4 write controller
//

`timescale 1ns/1ns

module buffer_overhaul_reader_tb();

`include "mDOM_wvb_hdr_bundle_4_inc.v"
localparam P_WVB_ADR_WIDTH = 10;
localparam P_DATA_WIDTH = 85;
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
wire wvb_rdreq;
wire hdr_rdreq;
wire wvb_rddone;

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
   .local_coinc(1'b0)
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
wire[15:0] dpram_len;
wire dpram_run;
reg dpram_mode = 0;
reg dpram_busy = 0;
reg dpram_done = 0;

reg reader_enable = 0;
wvb_reader
#(.N_CHANNELS(24),
  .P_DATA_WIDTH(P_DATA_WIDTH),
  .P_WVB_ADR_WIDTH(P_WVB_ADR_WIDTH),
  .P_HDR_WIDTH(L_WIDTH_MDOM_WVB_HDR_BUNDLE_4),
  .P_FMT(3))
WVB_READER
(
  .clk(clk),
  .rst(rst),
  .en(reader_enable),
  .dpram_data(dpram_data),
  .dpram_addr(dpram_a),
  .dpram_wren(dpram_wren),
  .dpram_len(dpram_len),
  .dpram_run(dpram_run),
  .dpram_busy(dpram_busy),
  .dpram_mode(dpram_mode),
  .hdr_rdreq(hdr_rdreq),
  .wvb_rdreq(wvb_rdreq),
  .wvb_rddone(wvb_rddone),
  .wvb_data(wvb_out),
  .hdr_data(hdr_out),
  .hdr_empty(hdr_empty)
);

always @(posedge clk) begin
  ltc <= ltc + 1;

  if (!rst) begin
    adc_in <= adc_in + 1;
    discr_in <= discr_in + 1;
  end

  trig <= 0;
  trig_src <= 0;

  if (ltc == 100) begin
    reader_enable <= 1;
  end

  if (ltc == 5) begin
    rst <= 0;
  end

  // external trigger at ltc == 45  
  if (ltc == 44) begin
    trig <= 1;
    trig_src <= 3;
  end

  // test variable trigger including retriggering at end of waveform
  // and a trigger right after the end of the waveform
  if (ltc == 61 || ltc == 63 || ltc == 76 || ltc == 89) begin
    trig <= 1;
    trig_src <= 1;
  end

  // test split waveforms
  if (ltc == 245) test_conf <= 2048;
  if (ltc == 249) begin
    trig <= 1;
    trig_src <= 3;
  end
  
  // test non split max length
  if (ltc == 3115) test_conf <= 1020;
  if (ltc == 3119) begin
    trig <= 1;
    trig_src <= 3;
  end

  // test overflow
  if (ltc == 5399) begin
    reader_enable <= 0;
    test_conf <= 3076;
  end

  if (ltc == 5449) begin
    trig <= 1;
    trig_src <= 3;
  end

  if (ltc == 5459) test_conf <= 1020;

  if (ltc == 9299) begin
    trig <= 1;
    trig_src <= 3;
  end

  if (ltc == 10329) begin
    wvb_rst <= 1;
  end

  if (ltc == 10399) begin
    wvb_rst <= 0;
    test_conf <= 3076;
  end

  // test some overflow edge cases 
  
  if (ltc == 10549) begin
    trig <= 1;
    trig_src <= 3;
  end

  if (ltc == 13626) test_conf <= 1016;
  if (ltc == 13629) begin
    trig <= 1;
    trig_src <= 3;
  end
  // 1: write up to but not including last word

  // 2: write up to but not including last word, then trigger immediately after
  // if (ltc == 14645) begin
  //   trig <= 1;
  //   trig_src <= 3;
  // end
  // 3: write up to but not including last word, then trigger after a one cycle delay
  // if (ltc == 14646) begin
  //   trig <= 1;
  //   trig_src <= 3;
  // end
  // 4: extra cycle of delay
  if (ltc == 14647) begin
    trig <= 1;
    trig_src <= 3;
  end

  if (ltc == 14659) begin
    reader_enable <= 1;
  end
end


// handle rbd signals
always @(posedge clk) begin
  if (dpram_run) begin
    dpram_busy <= 1;
  end

  else if (dpram_done && dpram_busy) begin
    dpram_busy <= 0;
  end

end

// DPRAM user

reg[8:0] rdout_dpram_rd_addr = 0;
wire[63:0] rdout_dpram_dout;
HBUF_RDOUT_DPRAM READER_DPRAM_0
(
  .clka(clk),
  .wea(dpram_wren),
  .addra(dpram_a),
  .dina(dpram_data),
  .clkb(clk),
  .addrb(rdout_dpram_rd_addr),
  .doutb(rdout_dpram_dout)
);

wire[31:0] max_rd_addr = (dpram_len >> 2) - 1; 

wire[15:0] reader_word_0 = rdout_dpram_dout[15:0];
wire[15:0] reader_word_1 = rdout_dpram_dout[31:16];
wire[15:0] reader_word_2 = rdout_dpram_dout[47:32];
wire[15:0] reader_word_3 = rdout_dpram_dout[63:48];

wire[11:0] reader_adc_word_0 = reader_word_0[11:0];
wire[11:0] reader_adc_word_1 = reader_word_2[11:0];

always @(posedge clk) begin
  dpram_done <= 0;
  rdout_dpram_rd_addr <= 0;

  if (dpram_busy) begin
    rdout_dpram_rd_addr <= rdout_dpram_rd_addr + 1;

    if (rdout_dpram_rd_addr == max_rd_addr) begin
      rdout_dpram_rd_addr <= max_rd_addr;
      dpram_done <= 1;
    end
  end
end


endmodule