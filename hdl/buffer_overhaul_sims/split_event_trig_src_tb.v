// Test bench for mdommb_rev1_fw issue #3:
//   trigger source reported for continued (split) waveform payloads
//
// A long waveform is split by wvb_wr_ctrl into payloads of at most
// MAX_WRITES_PER_PAYLOAD (127) rows = 1016 samples. Every payload of a split
// waveform must report the source of the trigger that started the waveform
// ("source of initial trigger" in mDOM_wvb_hdr_bundle_4.json).
//
// The DUT is one complete channel of the production data path
// (waveform_acquisition: mdom_trigger -> pipeline regs -> waveform_buffer),
// configured with production widths. Payload headers are read out of the
// channel header FIFO (hdr_rdreq / wvb_rddone, as the reader does) and are
// cross-checked against the header words written by wvb_wr_ctrl.
//
// Scenarios:
//  1. Reproduction of event 328936 (mDOM (90,113), ch 7): ADC threshold
//     trigger, pre_conf = 6, post_conf = 12, a pulse that keeps the channel
//     above threshold long enough for a 2040-sample capture, which is split
//     into 1016 + 1016 + 8 samples.
//  2. Sweep of the threshold-trigger pulse length across both split
//     boundaries, so the end of the pulse visits every phase relative to the
//     split write.
//  3. Software-triggered 2040-sample test readout, with the ADC above the
//     threshold-trigger level when the readout is split (the inverse case:
//     the continuation must stay SOFTWARE, not pick up THRESHOLD).
//
// The bench prints a cycle trace of wvb_wr_ctrl around every split of the
// scenario-1 waveform, then a PASS / FAIL summary.
//
// Runs in Vivado xsim (set as sim_1 top, "run all"; ~2.1 ms of sim time) or in
// Icarus Verilog using the IP *_sim_netlist.v files and the Xilinx unisims library.

`timescale 1ns/1ps

module split_event_trig_src_tb();

`include "trigger_src_inc.v"
`include "mDOM_wvb_hdr_bundle_4_inc.v"
`include "mDOM_trig_bundle_inc.v"
`include "mDOM_wvb_conf_bundle_inc.v"
`include "mDOM_bsum_bundle_inc.v"

// production configuration (mdommb_fw_rev1_top.v)
localparam P_DATA_WIDTH = 170;
localparam P_ADR_WIDTH = 9;
localparam P_HDR_WIDTH = L_WIDTH_MDOM_WVB_HDR_BUNDLE_4;
localparam P_LTC_WIDTH = 49;
localparam N_ROWS = 1 << P_ADR_WIDTH;

// readout configuration used for event 328936
localparam[4:0] PRE_CONF = 6;
localparam[7:0] POST_CONF = 12;
localparam[11:0] TEST_CONF = 2040;

// ADC levels
localparam[11:0] BASELINE = 200;
localparam[11:0] THRESH = 300;
localparam[11:0] PULSE_HEIGHT = 3500;

// 120 MHz lclk
parameter CLK_PERIOD = 8.333;
reg clk = 0;
always #(CLK_PERIOD / 2.0) clk = !clk;

reg rst = 1;
reg[P_LTC_WIDTH-1:0] ltc = 0;
always @(posedge clk) ltc <= ltc + 1;

//
// DUT inputs
//
reg[11:0] adc_data = BASELINE;
reg xdom_trig_run = 0;
reg[11:0] test_conf = TEST_CONF;

wire[L_WIDTH_MDOM_TRIG_BUNDLE-1:0] trig_bundle;
mDOM_trig_bundle_fan_in TRIG_FAN_IN (
  .bundle(trig_bundle),
  .trig_et(1'b0),
  .trig_gt(1'b1),
  .trig_lt(1'b0),
  .trig_run(1'b0),
  .discr_trig_pol(1'b0),
  .trig_thresh(THRESH),
  .disc_trig_en(1'b0),
  .thresh_trig_en(1'b1),
  .ext_trig_en(1'b0)
);

wire[L_WIDTH_MDOM_WVB_CONF_BUNDLE-1:0] conf_bundle;
mDOM_wvb_conf_bundle_fan_in CONF_FAN_IN (
  .bundle(conf_bundle),
  .cnst_conf(12'd0),
  .test_conf(test_conf),
  .post_conf(POST_CONF),
  .pre_conf(PRE_CONF),
  .arm(1'b0),
  .trig_mode(1'b0),
  .cnst_run(1'b0)
);

wire[L_WIDTH_MDOM_BSUM_BUNDLE-1:0] bsum_bundle;
mDOM_bsum_bundle_fan_in BSUM_FAN_IN (
  .bundle(bsum_bundle),
  .pause(1'b0),
  .pause_override(1'b0),
  .sum_len_sel(3'd3),
  .pause_len(16'd0),
  .dev_low(12'd0),
  .dev_high(12'd4095)
);

//
// DUT outputs / reader interface
//
wire[P_DATA_WIDTH-1:0] wvb_data_out;
wire[P_HDR_WIDTH-1:0] hdr_data_out;
wire hdr_full;
wire hdr_empty;
wire[15:0] n_wvf_in_buf;
wire[15:0] wvb_wused;
reg hdr_rdreq = 0;
reg wvb_rdreq = 0;
reg wvb_rddone = 0;
wire armed;
wire overflow;
wire overflow_fifo_req;

waveform_acquisition #(.P_DATA_WIDTH(P_DATA_WIDTH),
                       .P_ADR_WIDTH(P_ADR_WIDTH),
                       .P_HDR_WIDTH(P_HDR_WIDTH),
                       .P_LTC_WIDTH(P_LTC_WIDTH))
DUT
(
  .clk(clk),
  .rst(rst),

  .adc_data(adc_data),
  .discr_data(8'h00),

  .wvb_data_out(wvb_data_out),
  .wvb_hdr_data_out(hdr_data_out),
  .wvb_hdr_full(hdr_full),
  .wvb_hdr_empty(hdr_empty),
  .wvb_n_wvf_in_buf(n_wvf_in_buf),
  .wvb_wused(wvb_wused),
  .wvb_hdr_rdreq(hdr_rdreq),
  .wvb_wvb_rdreq(wvb_rdreq),
  .wvb_wvb_rddone(wvb_rddone),

  .ltc_in(ltc),

  .ext_trig_in(1'b0),
`ifndef MDOMREV1
  .cal_trig_trig_en(1'b0),
  .cal_trig_trig_run(1'b0),
`endif
  .wvb_trig_out(),
  .wvb_trig_test_out(),
  .thresh_tot_out(),

  .xdom_arm(1'b0),
  .xdom_trig_run(xdom_trig_run),
  .xdom_wvb_trig_bundle(trig_bundle),
  .xdom_wvb_config_bundle(conf_bundle),
  .xdom_wvb_armed(armed),
  .xdom_wvb_overflow(overflow),
  .xdom_trig_en(1'b1),

  .global_trigger(1'b0),
  .icm_sync_rdy(1'b1),
  .bsum_bundle(bsum_bundle),
  .local_coinc(1'b0),
  .lc_required(1'b0),

  .overflow_fifo_ack(overflow_fifo_req),
  .overflow_fifo_req(overflow_fifo_req),
  .overflow_start_ltc(),
  .overflow_end_ltc()
);

//
// shadow copy of the waveform buffer rows (for sample reconstruction)
// and a queue of the header words written by wvb_wr_ctrl
//
reg[P_DATA_WIDTH-1:0] shadow[0:N_ROWS-1];
always @(posedge clk) begin
  if (DUT.WVB.wvb_wrreq) shadow[DUT.WVB.wvb_wr_addr] <= DUT.WVB.WBS.buff_din;
end

reg[P_HDR_WIDTH-1:0] wr_hdr_q[0:1023];
integer wr_hdr_head = 0;
integer wr_hdr_tail = 0;
always @(posedge clk) begin
  if (DUT.WVB.hdr_wrreq) begin
    wr_hdr_q[wr_hdr_tail % 1024] <= DUT.WVB.hdr_data_in;
    wr_hdr_tail <= wr_hdr_tail + 1;
  end
end

//
// bookkeeping
//
integer n_errors = 0;
integer n_payloads = 0;
integer n_chains = 0;
integer n_mislabeled_chains = 0;
integer n_overflows = 0;
reg verbose = 0;

// current chain (one triggered waveform, possibly split over several payloads)
reg chain_open = 0;
reg[1:0] chain_src = 0;
reg[1:0] expected_src = TRIG_SRC_THRESH;
integer chain_npl = 0;
integer chain_len = 0;
integer chain_bad = 0;

// result of the most recently closed chain
integer last_chain_len = 0;
integer last_chain_npl = 0;
integer last_chain_bad = 0;
integer last_lens[0:7];
integer last_srcs[0:7];

function [8*6-1:0] src_name(input[1:0] src);
  case (src)
    TRIG_SRC_SW:     src_name = "SW    ";
    TRIG_SRC_THRESH: src_name = "THRESH";
    TRIG_SRC_DISCR:  src_name = "DISCR ";
    default:         src_name = "EXT   ";
  endcase
endfunction

task process_header(input[P_HDR_WIDTH-1:0] hdr);
  reg[P_LTC_WIDTH-1:0] h_ltc;
  reg[P_ADR_WIDTH-1:0] h_start;
  reg[P_ADR_WIDTH-1:0] h_stop;
  reg[1:0] h_src;
  reg h_partial;
  reg h_continued;
  integer len;
  integer row;
  integer i_row;
  integer i_wd;
  integer adc;
  integer adc_max;
  integer adc_min;
  reg[P_DATA_WIDTH-1:0] row_data;
  begin
    h_ltc = hdr[L_STOP_POS_MDOM_WVB_HDR_BUNDLE_4_EVT_LTC:L_START_POS_MDOM_WVB_HDR_BUNDLE_4_EVT_LTC];
    h_start = hdr[L_STOP_POS_MDOM_WVB_HDR_BUNDLE_4_START_ADDR:L_START_POS_MDOM_WVB_HDR_BUNDLE_4_START_ADDR];
    h_stop = hdr[L_STOP_POS_MDOM_WVB_HDR_BUNDLE_4_STOP_ADDR:L_START_POS_MDOM_WVB_HDR_BUNDLE_4_STOP_ADDR];
    h_src = hdr[L_STOP_POS_MDOM_WVB_HDR_BUNDLE_4_TRIG_SRC:L_START_POS_MDOM_WVB_HDR_BUNDLE_4_TRIG_SRC];
    h_partial = hdr[L_START_POS_MDOM_WVB_HDR_BUNDLE_4_PARTIAL_WFM];
    h_continued = hdr[L_START_POS_MDOM_WVB_HDR_BUNDLE_4_CONTINUED_WFM];

    len = ((h_stop - h_start) % N_ROWS + 1) * 8;

    // reconstruct ADC samples of this payload from the buffer rows
    // row layout: {w0, w1, w2, w3, eoe, w4, w5, w6, w7, 0}, w7 oldest;
    // word = {discr[7:0], adc[11:0], tot}
    adc_max = 0;
    adc_min = 4095;
    for (i_row = 0; i_row < len / 8; i_row = i_row + 1) begin
      row = (h_start + i_row) % N_ROWS;
      row_data = shadow[row];
      for (i_wd = 0; i_wd < 8; i_wd = i_wd + 1) begin
        if (i_wd < 4) adc = row_data[(i_wd*21 + 1) + 1 +: 12];
        else adc = row_data[(i_wd*21 + 2) + 1 +: 12];
        if (adc > adc_max) adc_max = adc;
        if (adc < adc_min) adc_min = adc;
      end
    end

    n_payloads = n_payloads + 1;

    // chain bookkeeping
    if (!h_continued) begin
      if (chain_open) begin
        $display("ERROR: new waveform started before previous split waveform was closed");
        n_errors = n_errors + 1;
      end
      chain_open = 1;
      chain_src = h_src;
      chain_npl = 0;
      chain_len = 0;
      chain_bad = 0;
      if (h_src != expected_src) begin
        $display("ERROR: initial payload trig_src=%0s, expected %0s",
                 src_name(h_src), src_name(expected_src));
        n_errors = n_errors + 1;
      end
    end else if (!chain_open) begin
      $display("ERROR: continued payload without an open waveform");
      n_errors = n_errors + 1;
    end

    if (chain_npl < 8) begin
      last_lens[chain_npl] = len;
      last_srcs[chain_npl] = h_src;
    end
    chain_npl = chain_npl + 1;
    chain_len = chain_len + len;

    if (h_continued && h_src != chain_src) chain_bad = chain_bad + 1;

    if (verbose) begin
      $display("  payload: ltc=%0d len=%4d trig_src=%0s partial=%0d continued=%0d  ADC range [%0d, %0d]%0s",
               h_ltc, len, src_name(h_src), h_partial, h_continued, adc_min, adc_max,
               (h_continued && h_src != chain_src) ? "   <-- trig_src differs from initial trigger" : "");
    end

    if (!h_partial) begin
      chain_open = 0;
      n_chains = n_chains + 1;
      last_chain_len = chain_len;
      last_chain_npl = chain_npl;
      last_chain_bad = chain_bad;
      if (chain_bad > 0) begin
        n_mislabeled_chains = n_mislabeled_chains + 1;
        n_errors = n_errors + 1;
      end
    end
  end
endtask

//
// reader: drain the header FIFO like the downstream reader, check each
// header against what wvb_wr_ctrl wrote, release the buffer rows
//
initial begin : reader
  reg[P_HDR_WIDTH-1:0] hdr;
  forever begin
    @(posedge clk);
    if (!rst && !hdr_empty) begin
      hdr_rdreq <= 1;
      @(posedge clk);
      hdr_rdreq <= 0;
      repeat (5) @(posedge clk);
      hdr = hdr_data_out;
      if (hdr !== wr_hdr_q[wr_hdr_head % 1024]) begin
        $display("ERROR: header read from FIFO does not match header written by wvb_wr_ctrl");
        n_errors = n_errors + 1;
      end
      wr_hdr_head = wr_hdr_head + 1;
      process_header(hdr);
      wvb_rddone <= 1;
      @(posedge clk);
      wvb_rddone <= 0;
      repeat (2) @(posedge clk);
    end
  end
end

always @(posedge clk) begin
  if (!rst && DUT.WVB.WR_CTRL.overflow_pe) begin
    $display("ERROR: unexpected waveform buffer overflow at ltc=%0d", ltc);
    n_overflows = n_overflows + 1;
    n_errors = n_errors + 1;
  end
end

//
// cycle trace of wvb_wr_ctrl around each split (enabled for scenario 1)
//
reg trace_en = 0;
integer trace_cnt = 0;
always @(posedge clk) begin
  if (trace_en && DUT.WVB.WR_CTRL.split_evt) trace_cnt <= 6;
  else if (trace_cnt > 0) trace_cnt <= trace_cnt - 1;
end

always @(posedge clk) begin
  if (trace_en && (DUT.WVB.WR_CTRL.split_evt || trace_cnt > 0 ||
      (DUT.WVB.WR_CTRL.fsm != 0 && DUT.WVB.WR_CTRL.n_writes_check))) begin
    $display("    ltc=%0d fsm=%0d cnt=%2d trig=%0d trig_src=%0d | wvb_wren=%0d split_evt=%0d hdr_wren=%0d hdr_wren_prev=%0d | i_trig_src=%0d",
             ltc,
             DUT.WVB.WR_CTRL.fsm,
             DUT.WVB.WR_CTRL.cnt,
             DUT.WVB.WR_CTRL.trig,
             DUT.WVB.WR_CTRL.trig_src,
             DUT.WVB.WR_CTRL.wvb_wren,
             DUT.WVB.WR_CTRL.split_evt,
             DUT.WVB.WR_CTRL.hdr_wren,
             DUT.WVB.WR_CTRL.hdr_wren_prev,
             DUT.WVB.WR_CTRL.i_trig_src);
  end
end

//
// stimulus helpers
//
task idle(input integer n);
  begin
    adc_data <= BASELINE;
    repeat (n) @(posedge clk);
  end
endtask

// threshold-triggered pulse: n_over consecutive samples above threshold
task thresh_pulse(input integer n_over);
  begin
    expected_src = TRIG_SRC_THRESH;
    adc_data <= PULSE_HEIGHT;
    repeat (n_over) @(posedge clk);
    adc_data <= BASELINE;
    // wait for the waveform to finish and be read out
    idle(400);
  end
endtask

integer sweep_len;
integer sweep_first_bad;
integer sweep_last_bad;
integer sweep_n_bad;
integer scen_errors;
integer saved_mislabeled;
integer n_over_repro;

initial begin
  $display("==== split_event_trig_src_tb: pre_conf=%0d post_conf=%0d thresh=%0d ====",
           PRE_CONF, POST_CONF, THRESH);

  repeat (10) @(posedge clk);
  rst <= 0;
  // let the pretrigger buffer and baseline sum settle
  idle(200);

  //
  // 1) event 328936 reproduction: 2040 samples -> 1016 + 1016 + 8
  //
  // find the pulse length that gives a 2040-sample capture with an 8-sample tail
  // (quietly), then replay that pulse with tracing enabled
  n_over_repro = -1;
  scen_errors = n_errors;
  saved_mislabeled = n_mislabeled_chains;
  for (sweep_len = 2000; sweep_len <= 2040 && n_over_repro < 0; sweep_len = sweep_len + 1) begin
    thresh_pulse(sweep_len);
    if (last_chain_len == 2040 && last_chain_npl == 3) n_over_repro = sweep_len;
  end
  // the search is not itself a check
  n_errors = scen_errors;
  n_mislabeled_chains = saved_mislabeled;

  $display("");
  $display("---- scenario 1: event 328936 reproduction (%0d samples above threshold) ----", n_over_repro);
  if (n_over_repro < 0) begin
    $display("ERROR: no pulse length produced a 1016 + 1016 + 8 capture");
    n_errors = n_errors + 1;
  end else begin
    scen_errors = n_errors;
    verbose = 1;
    trace_en = 1;
    thresh_pulse(n_over_repro);
    trace_en = 0;
    verbose = 0;
    $display("  capture: %0d samples in %0d payloads (%0d + %0d + %0d), trig_src %0s / %0s / %0s",
             last_chain_len, last_chain_npl, last_lens[0], last_lens[1], last_lens[2],
             src_name(last_srcs[0]), src_name(last_srcs[1]), src_name(last_srcs[2]));
    $display("  scenario 1: %0s", (n_errors == scen_errors) ? "PASS" : "FAIL");
  end

  //
  // 2) sweep the pulse length across both split boundaries
  //
  $display("");
  $display("---- scenario 2: threshold-trigger pulse-length sweep ----");
  scen_errors = n_errors;
  sweep_n_bad = 0;
  for (sweep_len = 980; sweep_len <= 1040; sweep_len = sweep_len + 1) begin
    thresh_pulse(sweep_len);
    if (last_chain_npl > 1) begin
      $display("  n_over=%4d: %0d samples = %4d + %4d%0s   trig_src %0s / %0s%0s",
               sweep_len, last_chain_len, last_lens[0], last_lens[1],
               last_chain_npl > 2 ? " + ..." : "",
               src_name(last_srcs[0]), src_name(last_srcs[1]),
               last_chain_bad ? "  MISLABELED" : "");
      if (last_chain_bad) sweep_n_bad = sweep_n_bad + 1;
    end
  end
  for (sweep_len = 2000; sweep_len <= 2050; sweep_len = sweep_len + 1) begin
    thresh_pulse(sweep_len);
    if (last_chain_npl > 2) begin
      $display("  n_over=%4d: %0d samples = %4d + %4d + %4d   trig_src %0s / %0s / %0s%0s",
               sweep_len, last_chain_len, last_lens[0], last_lens[1], last_lens[2],
               src_name(last_srcs[0]), src_name(last_srcs[1]), src_name(last_srcs[2]),
               last_chain_bad ? "  MISLABELED" : "");
      if (last_chain_bad) sweep_n_bad = sweep_n_bad + 1;
    end
  end
  $display("  %0d mislabeled split waveforms in sweep", sweep_n_bad);
  $display("  scenario 2: %0s", (n_errors == scen_errors) ? "PASS" : "FAIL");

  //
  // 3) software-triggered 2040-sample test readout; ADC is above the
  //    threshold-trigger level around the 1016-sample split
  //
  $display("");
  $display("---- scenario 3: software-triggered test readout (test_conf=%0d) ----", TEST_CONF);
  scen_errors = n_errors;
  verbose = 1;
  expected_src = TRIG_SRC_SW;
  idle(50);
  xdom_trig_run <= 1;
  @(posedge clk);
  xdom_trig_run <= 0;
  idle(990);
  adc_data <= PULSE_HEIGHT;
  repeat (60) @(posedge clk);
  idle(1400);
  verbose = 0;
  $display("  capture: %0d samples in %0d payloads, trig_src %0s / %0s / %0s",
           last_chain_len, last_chain_npl,
           src_name(last_srcs[0]), src_name(last_srcs[1]), src_name(last_srcs[2]));
  $display("  scenario 3: %0s", (n_errors == scen_errors) ? "PASS" : "FAIL");

  //
  // summary
  //
  $display("");
  $display("==== %0d payloads, %0d waveforms, %0d mislabeled split waveforms, %0d overflows ====",
           n_payloads, n_chains, n_mislabeled_chains, n_overflows);
  if (n_errors == 0) $display("==== split_event_trig_src_tb PASSED ====");
  else $display("==== split_event_trig_src_tb FAILED (%0d errors) ====", n_errors);
  $finish;
end

endmodule
