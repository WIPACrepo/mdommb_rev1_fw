// Aaron Fienberg
// August 2020
//
// mDOM waveform buffer overflow controller
//

module wvb_overflow_ctrl #(parameter P_ADR_WIDTH = 12,
                           parameter P_HDR_WIDTH = 80,
                           parameter P_LTC_WIDTH = 48)
(
  input clk,
  input rst,

  output overflow,
  output[15:0] wvb_wused,

  input[P_ADR_WIDTH-1:0] wvb_wr_addr,
  input wvb_rddone,

  input[P_HDR_WIDTH-1:0] hdr_data,
  input hdr_full,
  input hdr_empty,

  // overflow logging interface
  input[P_LTC_WIDTH-1:0] ltc,
  input overflow_fifo_ack,
  output reg overflow_fifo_req = 0,
  output[P_LTC_WIDTH-1:0] overflow_start_ltc,
  output[P_LTC_WIDTH-1:0] overflow_end_ltc
);
`include "mDOM_wvb_hdr_bundle_2_inc.v"
`include "mDOM_wvb_hdr_bundle_3_inc.v" // T. Anderson Sat 05/21/2022_14:21:30.96
`include "mDOM_wvb_hdr_bundle_4_inc.v" // A. Fienberg 2025: Increase waveform buffer sizes

// header fan out
wire[P_ADR_WIDTH-1:0] stop_addr;

reg in_overflow = 0; // whether the buffer is in an overflow state

generate
if (P_HDR_WIDTH == L_WIDTH_MDOM_WVB_HDR_BUNDLE_4) begin
  mDOM_wvb_hdr_bundle_4_fan_out HDR_FAN_OUT (
    .bundle(hdr_data),
    .evt_ltc(),
    .start_addr(),
    .stop_addr(stop_addr),
    .trig_src(),
    .cnst_run(),
    .pre_conf(),
    .sync_rdy(),
    .bsum(),
    .bsum_len_sel(),
    .bsum_valid(),
    .local_coinc(),
    .partial_wfm(),
    .continued_wfm()
  );
end else begin
  invalid_p_adr_width invalid_module_conf();
end
endgenerate

reg[P_ADR_WIDTH-1:0] last_rd_addr = -1;
always @(posedge clk) begin
  if (rst) begin
    last_rd_addr <= -1;
  end else begin
    // stop addr is the last written address of the
    // event. So, after an event has been read, the next
    // address to read is stop_addr + 1
    if (wvb_rddone) begin
      last_rd_addr <= stop_addr;
    end
  end
end

// after change to writing every eighth clock cycle,
// we need to delay the overflow signal before it reaches the write controller
reg[2:0] overflow_delay_cnt = 0;
reg buffer_full_overflow = 0;
always @(posedge clk) begin
  if (rst) begin
    buffer_full_overflow <= 0;
    overflow_delay_cnt <= 0;
  end else begin
    overflow_delay_cnt <= 0;
    buffer_full_overflow <= overflow_delay_cnt == 6;
    if (overflow_delay_cnt >= 1 && (!in_overflow)) begin
      overflow_delay_cnt <= overflow_delay_cnt + 1;
    end else if (wvb_wr_addr == last_rd_addr && (!in_overflow)) begin
      overflow_delay_cnt <= 1;
    end
  end
end

// overflow condition: hdr_full or wr_addr == last_rd_addr
wire overflow_condition = hdr_full || buffer_full_overflow;

// calculate number of words used
wire[P_ADR_WIDTH-1:0] next_rd_addr = last_rd_addr + 1;

wire[15:0] MAX_WUSED = (1 << P_ADR_WIDTH);
reg[P_ADR_WIDTH - 1:0] i_wvb_wused = 0;

reg full = 0;
reg[P_ADR_WIDTH-1:0] prev_wr_addr;

wire wrote_last_rd_addr = (wvb_wr_addr == next_rd_addr && last_rd_addr == prev_wr_addr);
always @(posedge clk) begin
  if (rst) begin
    i_wvb_wused <= 0;
    full <= 0;
  end else begin
    i_wvb_wused <= wvb_wr_addr - next_rd_addr;

    prev_wr_addr <= wvb_wr_addr;
    full <= full && wvb_wr_addr == next_rd_addr;

    if (wrote_last_rd_addr) begin
      full <= 1;
    end
  end
end

assign wvb_wused[15:P_ADR_WIDTH] = full ? 1 : 0;
assign wvb_wused[P_ADR_WIDTH - 1:0] = i_wvb_wused;

// overflow state handling
reg overflow_clear = 0;
reg[P_LTC_WIDTH - 1:0] overflow_pe_ltc = 0;
always @(posedge clk)
begin
  if (rst) begin
    in_overflow <= 0;
  end else begin
    if (overflow_condition && !in_overflow) begin
      overflow_pe_ltc <= ltc;
      in_overflow <= 1;
    end else if (overflow_clear && in_overflow) begin
      in_overflow <= 0;
    end
  end
end

//
// overflow recording FSM
// handles handshaking with external overflow FIFO module
// FSM states
localparam
  S_IDLE = 0,
  S_OVERFLOW = 1,
  S_CLEAR = 2,
  S_REQ = 3,
  S_ACK_WAIT = 4,
  S_ACK_CLEAR_WAIT = 5;

reg[2:0] fsm = S_IDLE;
reg[P_LTC_WIDTH - 1:0] overflow_start_ltc_0 = 0;
reg[P_LTC_WIDTH - 1:0] overflow_end_ltc_0 = 0;
always @(posedge clk) begin
  if (rst) begin
    overflow_clear <= 0;
    overflow_fifo_req <= 0;

    fsm <= S_IDLE;
  end else begin
    overflow_clear <= 0;
    overflow_fifo_req <= 0;

    case (fsm)
      S_IDLE: begin
        fsm <= S_IDLE;

        if (in_overflow) begin
          overflow_start_ltc_0 <= overflow_pe_ltc;
          fsm <= S_OVERFLOW;
        end
      end

      S_OVERFLOW: begin
        fsm <= S_OVERFLOW;

        if (hdr_empty && i_wvb_wused == 0) begin
          overflow_clear <= 1;
          fsm <= S_REQ;
        end
      end

      S_REQ: begin
        overflow_fifo_req <= 1;
        overflow_end_ltc_0 <= ltc + 1;
        fsm <= S_ACK_WAIT;
      end

      S_ACK_WAIT: begin
        fsm <= S_ACK_WAIT;
        overflow_fifo_req <= 1;

        if (overflow_fifo_ack) begin
          overflow_fifo_req <= 0;
          fsm <= S_ACK_CLEAR_WAIT;
        end
      end

      S_ACK_CLEAR_WAIT: begin
        fsm <= S_ACK_CLEAR_WAIT;
        if (!overflow_fifo_ack) begin
          fsm <= S_IDLE;
        end
      end

      default: begin
        fsm <= S_IDLE;
      end
    endcase
  end
end

assign overflow = overflow_condition || in_overflow;
assign overflow_start_ltc = overflow_start_ltc_0;
assign overflow_end_ltc = overflow_end_ltc_0;

endmodule
