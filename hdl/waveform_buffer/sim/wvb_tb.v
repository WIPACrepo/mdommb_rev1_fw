// Aaron Fienberg
//
// Test bench for the mDOM waveform buffer
//

`timescale 1ns/1ns

`define TEST_CASE_1 // various triggering patterns
// `define TEST_CASE_2 // targeted overflow edge cases

module wvb_tb();

`include "mDOM_wvb_hdr_bundle_4_inc.v"
localparam P_WVB_ADR_WIDTH = 12;
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
reg rddone = 0;

wire[15:0] wvb_wused;
wire[15:0] wvb_n_wvf_in_buf;
wire overflow_out;
wire[21:0] wvb_out;
wire[7:0] discr_out = wvb_out[21:14];
wire[11:0] adc_out = wvb_out[13:2];
wire tot_out = wvb_out[1];
wire eoe_out = wvb_out[0];

wire[L_WIDTH_MDOM_WVB_HDR_BUNDLE_4-1:0] hdr_out;
wire hdr_full;
wire hdr_empty;

reg[11:0] test_conf = 10;

// instantiate the waveform buffer
waveform_buffer
#(.P_DATA_WIDTH(22),
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
   .rst(rst),
   .ltc_in(ltc),
   .adc_in(adc_in),
   .discr_in(discr_in), 
   .tot(trig),
   .trig(trig),
   .trig_src(trig_src),
   .arm(1'b0),

   .wvb_rdreq(wvb_rdreq),
   .hdr_rdreq(hdr_rdreq),
   .wvb_rddone(rddone),

   // Config inputs
   .pre_conf(10),
   .post_conf(4),
   .test_conf(test_conf),
   .cnst_run(0),
   .cnst_conf(10),
   .trig_mode(0),

   .icm_sync_rdy(1'b1),
   .bsum(19'b1),
   .bsum_len_sel(3'b1),
   .bsum_valid(1'b1),
   .local_coinc(1'b0)
  );

// hdr fan out
// header fan out
wire[P_WVB_ADR_WIDTH-1:0] hdr_start_addr;
wire[P_WVB_ADR_WIDTH-1:0] hdr_stop_addr;
wire[47:0] evt_ltc;
wire odd_ltc_bit;
wire[1:0] trig_src_hdr;
wire cnst_run;
wire[4:0] pre_conf;
wire icm_sync_rdy;
wire[18:0] bsum;
wire[2:0] bsum_len_sel;
wire bsum_valid;
wire local_coinc; // T. Anderson Sat 05/21/2022_14:32:00.75
mDOM_wvb_hdr_bundle_4_fan_out HDR_FAN_OUT (
      .bundle(hdr_out),
      .evt_ltc({evt_ltc, odd_ltc_bit}),
      .start_addr(hdr_start_addr),
      .stop_addr(hdr_stop_addr),
      .trig_src(trig_src_hdr),
      .cnst_run(cnst_run),
      .pre_conf(pre_conf),
      .sync_rdy(icm_sync_rdy),
      .bsum(bsum),
      .bsum_len_sel(bsum_len_sel),
      .bsum_valid(bsum_valid),
      .local_coinc(local_coinc) // T. Anderson Sat 05/21/2022_14:32:00.75
  );

wire[11:0] addr_diff = hdr_stop_addr - hdr_start_addr;
wire[15:0] wfm_len = addr_diff + 1;

reg filled_hdr_fifo = 0;
reg reader_enable = 0;

`ifdef TEST_CASE_1
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
  if (ltc == 45) begin
    trig <= 1;
    trig_src <= 3;
  end

  // another trig at ltc == 60
  if (ltc == 59) begin
    trig <= 1;
    trig_src <= 3;
  end

  if (ltc == 75) begin
    reader_enable <= 1;
  end

  // overflow the buffer, then reset it 
  if (ltc >= 150 && ltc < 5000) begin
    trig <= 1;
    trig_src <= 1;
  end

  // recover from overflow
  if (ltc == 8352) begin
    rst <= 1;
  end

  if (ltc == 8360) begin
    rst <= 0;
  end
  
  // one more software trigger 
  // (make sure to wait long enough for pretrigger 
  //  buffer to be ready)
  if (ltc == 8399) begin
    trig <= 1;
    trig_src <= 3;
  end

  // test overflow from full hdr fifo
  if (ltc == 9000) begin
    reader_enable <= 0;
    trig <= 1;
    trig_src <= 3;
  end

  if (ltc > 9000) begin
    // keep wvb_wren high continuously 
    if (!filled_hdr_fifo && (ltc % 10 == 0)) begin
      trig <= 1;
      trig_src <= 3;
    end
   if (overflow_out) begin
     filled_hdr_fifo <= 1;
   end
  end

  if (filled_hdr_fifo) begin
    #100
    reader_enable <= 1;
  end

end
`endif

`ifdef TEST_CASE_2
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
    test_conf <= 4094;
  end

  // test length 4094 waveform
  // external trigger at ltc == 45  
  if (ltc == 45) begin
    trig <= 1;
    trig_src <= 3;
  end

  // trigger again, causing an overflow

  if (ltc == 4141) begin
    trig <= 1;
    trig_src <= 3;
  end

end
`endif

// simple wvb reader 
localparam S_IDLE = 0,
           S_HDR  = 1,
           S_RD   = 2,
           S_DN   = 3; 

reg[2:0] fsm = S_IDLE;
reg[31:0] cnt = 0;
always @(posedge clk) begin
  if (rst) begin
    fsm <= S_IDLE;
  end

  else if (reader_enable) begin
    wvb_rdreq <= 0;
    hdr_rdreq <= 0;
    rddone <= 0;

    case (fsm)
      S_IDLE: begin
        if (wvb_n_wvf_in_buf > 0) begin
          hdr_rdreq <= 1;
          fsm <= S_HDR;
          cnt <= 0;
        end
      end

      S_HDR: begin
        cnt <= cnt + 1;
        if (cnt == 2) begin
          fsm <= S_RD;
          cnt <= 0;
        end
      end

      S_RD: begin
        cnt <= cnt + 1;
        wvb_rdreq <= 1;
        if (cnt == wfm_len - 1) begin
          wvb_rdreq <= 0;
          fsm <= S_DN;
        end
      end

      S_DN: begin
        rddone <= 1;
        fsm <= S_IDLE;
      end

      default: begin
        fsm <= S_IDLE;
      end
    endcase
  end
end

endmodule