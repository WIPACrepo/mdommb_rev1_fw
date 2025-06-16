// Aaron Fienberg
// August 2020
//
// mDOM waveform buffer write controller
//

module wvb_wr_ctrl #(parameter P_ADR_WIDTH = 12,
                     parameter P_HDR_WIDTH = 80,
                     parameter P_LTC_WIDTH = 48,
                     parameter P_CONST_CONF_WIDTH = 12,
                     parameter P_TEST_CONF_WIDTH = 12,
                     parameter P_PRE_CONF_WIDTH = 5,
                     parameter P_POST_CONF_WIDTH = 8,
                     parameter P_BSUM_WIDTH = 19,
                     parameter P_BSUM_LEN_SEL_WIDTH = 3
                    )
(
  input clk,
  input rst,

  // Outputs
  output overflow_out,
  output reg armed = 0,
  output reg eoe = 0,
  (*max_fanout=5*) output reg[P_ADR_WIDTH-1:0] wvb_wr_addr = 0,
  output wvb_wren,
  output[P_HDR_WIDTH-1:0] hdr_data,
  output hdr_wren,

  // Inputs
  input[P_LTC_WIDTH-1:0] ltc,
  input[P_PRE_CONF_WIDTH-1:0] pre_config,
  input[P_POST_CONF_WIDTH-1:0] post_config,
  input[P_TEST_CONF_WIDTH-1:0] test_config,
  input[P_CONST_CONF_WIDTH-1:0] cnst_config,
  input trig_mode,
  input cnst_run,
  input arm,
  input trig,
  input[1:0] trig_src,
  input overflow_in,
  input icm_sync_rdy,

  input[P_BSUM_WIDTH-1:0] bsum,
  input[P_BSUM_LEN_SEL_WIDTH-1:0] bsum_len_sel,
  input bsum_valid,
  input local_coinc // T. Anderson Sat 05/21/2022_14:39:29.68
);
`include "trigger_src_inc.v"
`include "mDOM_wvb_hdr_bundle_2_inc.v"
`include "mDOM_wvb_hdr_bundle_3_inc.v" // T. Anderson Sat 05/21/2022_14:35:13.75
`include "mDOM_wvb_hdr_bundle_4_inc.v"

localparam MAX_WRITES_PER_PAYLOAD = 127;

// register synchronous rst
(* DONT_TOUCH = "true" *) reg i_rst = 0;
always @(posedge clk) begin
  i_rst <= rst;
end

// Internals
reg[P_LTC_WIDTH-1:0] i_evt_ltc = 0;
reg[P_PRE_CONF_WIDTH-1:0] i_pre_conf = 0;
reg[P_PRE_CONF_WIDTH-1:0] i_pre_cnt_max = 0;
reg[P_POST_CONF_WIDTH-1:0] i_post_conf = 0;
reg[P_POST_CONF_WIDTH-1:0] i_post_cnt_max = 0;
reg[P_TEST_CONF_WIDTH-1:0] i_test_conf = 0;
reg[P_TEST_CONF_WIDTH-1:0] i_test_cnt_max = 0;
reg[P_CONST_CONF_WIDTH-1:0] i_const_conf = 0;
reg[P_CONST_CONF_WIDTH-1:0] i_const_cnt_max = 0;
reg[P_ADR_WIDTH-1:0] i_start_addr = 0;
reg[P_ADR_WIDTH-1:0] i_stop_addr = 0;
reg i_cnst_run = 0;
reg[1:0] i_trig_src = 0;
reg i_icm_sync_rdy = 0;
reg[P_BSUM_WIDTH-1:0] i_bsum = 0;
reg[P_BSUM_LEN_SEL_WIDTH-1:0] i_bsum_len_sel = 0;
reg i_bsum_valid = 0;
reg i_local_coinc = 0; // T. Anderson Sat 05/21/2022_14:37:47.72 
reg i_continued_wfm = 0;
   
// FSM states
localparam
  S_IDLE = 0,
  S_PRE = 1,
  S_SOT = 2,
  S_POST = 3,
  S_TEST = 4,
  S_CONST = 5;

reg[2:0] fsm = S_IDLE;
reg[31:0] cnt = 0;

// minimum values for various length configs
localparam PRE_CONF_MIN = 3,
           POST_CONF_MIN = 4,
           TEST_CONF_MIN = 8,
           CONST_CONF_MIN = 8;
// update interal length conf values
always @(posedge clk) begin
  if (fsm == S_IDLE) begin
    i_pre_conf <= pre_config >= PRE_CONF_MIN ? pre_config : PRE_CONF_MIN;
    i_post_conf <= post_config >= POST_CONF_MIN ? post_config : POST_CONF_MIN;
    // constrain test conf / cnst conf to multiples of 8
    i_test_conf <= test_config >= TEST_CONF_MIN ? {test_config[P_TEST_CONF_WIDTH-1:3], 3'b0} : TEST_CONF_MIN;
    i_const_conf <= cnst_config >= CONST_CONF_MIN ? {cnst_config[P_CONST_CONF_WIDTH-1:3], 3'b0} : CONST_CONF_MIN;

    i_pre_cnt_max <= i_pre_conf - 1;
    i_post_cnt_max <= i_post_conf - 1;
    i_test_cnt_max <= i_test_conf - 1;
    i_const_cnt_max <= i_const_conf - 1;
  end
end

wire writing_event;
// We want to latch the local coincidence flag if it fires at any time while writing the event. 
always @(posedge clk)
  if(writing_event && local_coinc) i_local_coinc <= 1'b1;
  else if(fsm==S_IDLE) i_local_coinc <= 1'b0; 
   
// stop addr will always update along with wvb_wr_addr
always @(*) i_stop_addr = wvb_wr_addr;

// overflow signals
reg overflow_state = 0;
always @(posedge clk) begin
  overflow_state <= overflow_in;
end

wire overflow_pe = overflow_in && !overflow_state;
assign overflow_out = overflow_state;

// handle trigger arm logic
always @(posedge clk) begin
  if (i_rst) begin
    armed <= 0;
  end

  else begin
    if (arm) begin
      armed <= 1;
    end

    else if (hdr_wren) begin
      armed <= 0;
    end
  end
end

// writing_event logic
wire write_condition = (trig && !overflow_pe) || fsm != S_IDLE;
wire mode_0_condition = (trig_mode == 0);
wire mode_1_condition = (trig_mode == 1) && armed;
assign writing_event = !overflow_state && write_condition && (mode_0_condition || mode_1_condition);

// when writing an event, we assert wvb_wren every eighth clock cycle
reg[2:0] write_cnt = 0;
always @(posedge clk) begin
  if (fsm == S_IDLE) begin
    write_cnt <= 1;
  end else begin
    write_cnt <= write_cnt + 1;
  end
end

assign wvb_wren = writing_event && (write_cnt == 3'h7);

// signal that this is the final write of a waveform
reg final_write = 0;
reg final_cnt_check = 0;

// register cnt comparisons to help
// with timing of hdr_wren
always @(posedge clk) begin
  // check against cnt_max - 1 so that final_cnt_check
  // will be true on the cycle where cnt == i_<x>_cnt_max
  case (fsm)
    S_IDLE:  final_cnt_check <= 0;
    S_PRE:   final_cnt_check <= 0;
    S_SOT:   final_cnt_check <= 0;
    S_POST:  final_cnt_check <= (cnt >= i_post_cnt_max - 1) && (write_cnt == 6);
    S_CONST: final_cnt_check <= cnt == i_const_cnt_max - 1;
    S_TEST:  final_cnt_check <= cnt == i_test_cnt_max - 1;
    default: final_cnt_check <= 0;
  endcase
end

// "final write" logic
always @(*) begin
  case (fsm)
    S_IDLE:  final_write = 0;
    S_PRE:   final_write = 0;
    S_SOT:   final_write = 0;
    S_POST:  final_write = !trig && final_cnt_check;
    S_CONST: final_write = final_cnt_check;
    S_TEST:  final_write = final_cnt_check;
    default: final_write = 0;
  endcase
end

// split events when they reach MAX_WRITES_PER_PAYLOAD
reg [P_ADR_WIDTH-1:0] n_writes = 0;
reg split_evt_prev = 0;
reg n_writes_check = 0;
wire split_evt;
always @(posedge clk) begin
  split_evt_prev <= split_evt;
  n_writes_check <= n_writes == MAX_WRITES_PER_PAYLOAD - 1;

  if ((fsm == S_IDLE) || hdr_wren) begin
    n_writes <= 0;
  end else if (writing_event) begin
    n_writes <= n_writes + wvb_wren;
  end
end
assign split_evt = (n_writes_check) && (wvb_wren) && (!final_write) && (!overflow_pe);

assign hdr_wren = wvb_wren && (final_write || overflow_pe || split_evt);
always @(*) eoe = hdr_wren;


// latch header values when fsm is in the idle state 
// or after writing into the header fifo (e.g. after splitting a long event)
reg hdr_wren_prev = 0;
always @(posedge clk) begin
  hdr_wren_prev <= hdr_wren;

  if ((fsm == S_IDLE) || hdr_wren_prev) begin
    i_evt_ltc <= ltc;
    i_trig_src <= trig_src;
    i_start_addr <= wvb_wr_addr;
    i_cnst_run <= cnst_run;
    i_icm_sync_rdy <= icm_sync_rdy;
    i_bsum <= bsum;
    i_bsum_len_sel <= bsum_len_sel;
    i_bsum_valid <= bsum_valid;
    i_continued_wfm <= split_evt_prev;
  end
end

// header bundle fan_in
generate
if (P_HDR_WIDTH == L_WIDTH_MDOM_WVB_HDR_BUNDLE_4)
  mDOM_wvb_hdr_bundle_4_fan_in HDR_FAN_IN
  (
    .bundle(hdr_data),
    .evt_ltc(i_evt_ltc),
    .start_addr(i_start_addr),
    .stop_addr(i_stop_addr),
    .trig_src(i_trig_src),
    .cnst_run(i_cnst_run),
    .pre_conf(i_pre_conf),
    .sync_rdy(i_icm_sync_rdy),
    .bsum(i_bsum),
    .bsum_len_sel(i_bsum_len_sel),
    .bsum_valid(i_bsum_valid),
    .local_coinc(i_local_coinc),
    .partial_wfm(split_evt),
    .continued_wfm(i_continued_wfm)
  );
else begin
  invalid_p_adr_width invalid_module_conf();
end
endgenerate

// FSM logic

// how extra wait count for retriggering logic
reg[P_ADR_WIDTH-1:0] sot_cnt = 0;

always @(posedge clk) begin
  if (i_rst) begin
    cnt <= 0;
    fsm <= S_IDLE;
    wvb_wr_addr <= 0;
    sot_cnt <= 0;
  end else if (overflow_state) begin
    cnt <= 0;
    fsm <= S_IDLE;
    sot_cnt <= 0;
  end else begin
    // always advance write address following a write
    if (wvb_wren) begin
      wvb_wr_addr <= wvb_wr_addr + 1;
    end

    case (fsm)
      S_IDLE: begin
        cnt <= 0;

        // trigger
        if (writing_event) begin
          cnt <= 1;

          if ((trig_src == TRIG_SRC_SW) ||
              (trig_src == TRIG_SRC_EXT)) begin
            fsm <= S_TEST;
          end

          else if (i_cnst_run) begin
            fsm <= S_CONST;
          end

          else begin
            // default case: one sample over threshold
            sot_cnt <= 1;

            fsm <= S_PRE;
          end
        end
      end

      S_PRE: begin
        cnt <= cnt + 1;

        if (trig) begin
          // if a trigger occurs during pretrigger readout,
          // we must extend the SOT window to "cnt + 1" cycles
          sot_cnt <= cnt + 1;
        end

        if (cnt == i_pre_cnt_max) begin
          cnt <= 0;
          fsm <= S_SOT;
        end
      end

      S_SOT: begin
        cnt <= cnt + 1;

        if (trig) begin
          // if a trigger occurs during the SOT state,
          // we must wait i_pre_conf cycles before
          // continuing to S_POST
          cnt <= 0;
          sot_cnt <= i_pre_conf;
        end

        else if (cnt == sot_cnt - 1) begin
          cnt <= 0;
          fsm <= S_POST;
        end
      end

      S_POST: begin
        cnt <= cnt + 1;

        if (trig) begin
          // if a trigger occurs during the POST state,
          // we must wait i_pre_conf cycles
          // and restart the post count
          cnt <= 0;
          sot_cnt <= i_pre_conf;
          fsm <= S_SOT;
        end

        else begin
          if (cnt >= i_post_cnt_max && (write_cnt == 7)) begin
            cnt <= 0;
            fsm <= S_IDLE;
          end
        end
      end

      S_TEST: begin
        cnt <= cnt + 1;

        if (cnt == i_test_cnt_max) begin
          cnt <= 0;
          fsm <= S_IDLE;
        end
      end

      S_CONST: begin
        cnt <= cnt + 1;

        if (cnt == i_const_cnt_max) begin
          cnt <= 0;
          fsm <= S_IDLE;
        end
      end

      default: begin
        fsm <= S_IDLE;
      end

    endcase
  end
end

endmodule
