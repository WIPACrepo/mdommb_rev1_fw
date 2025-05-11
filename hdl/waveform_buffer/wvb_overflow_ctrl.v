// Aaron Fienberg
// August 2020
//
// mDOM waveform buffer overflow controller
//

module wvb_overflow_ctrl #(parameter P_ADR_WIDTH = 12,
	                         parameter P_HDR_WIDTH = 80)
(
	input clk,
	input rst,

	output overflow,
	output[15:0] wvb_wused,

	input[P_ADR_WIDTH-1:0] wvb_wr_addr,
	input wvb_rddone,

	input[P_HDR_WIDTH-1:0] hdr_data,
	input hdr_full
);
`include "mDOM_wvb_hdr_bundle_2_inc.v"
`include "mDOM_wvb_hdr_bundle_3_inc.v" // T. Anderson Sat 05/21/2022_14:21:30.96
`include "mDOM_wvb_hdr_bundle_4_inc.v" // A. Fienberg 2025: Increase waveform buffer sizes

// header fan out
wire[P_ADR_WIDTH-1:0] stop_addr;

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
reg wvb_rddone_1 = 0;
always @(posedge clk) begin
	if (rst) begin
		last_rd_addr <= -1;
		wvb_rddone_1 <= 0;
	end else begin
		wvb_rddone_1 <= wvb_rddone;

		// stop addr is the last written address of the
		// event. So, after an event has been read, the next
		// address to read is stop_addr + 1
		if (wvb_rddone) begin
		  last_rd_addr <= stop_addr;
		end
	end
end

// after change to writing every fourth clock cycle,
// we need to delay the overflow_in before it reaches the write controller
reg[1:0] overflow_delay_cnt = 0;
reg buffer_full_overflow = 0;
reg in_overflow = 0;
always @(posedge clk) begin
  if (rst) begin
    buffer_full_overflow <= 0;
    overflow_delay_cnt <= 0;
    in_overflow <= 0;
  end else begin
    in_overflow <= in_overflow || buffer_full_overflow;
    overflow_delay_cnt <= 0;
    buffer_full_overflow <= overflow_delay_cnt == 2;
    if (overflow_delay_cnt >= 1 && (!in_overflow)) begin
      overflow_delay_cnt <= overflow_delay_cnt + 1;
    end else if (wvb_wr_addr == last_rd_addr && (!in_overflow)) begin
      overflow_delay_cnt <= 1;
    end
  end
end

// overflow condition: hdr_full or wr_addr == last_rd_addr
assign overflow = hdr_full || (buffer_full_overflow);

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
    full <= 0;

    if (full && wvb_rddone_1) begin
      full <= 0;
    end else if (full || wrote_last_rd_addr) begin
      full <= 1;
    end
  end
end

assign wvb_wused[15:P_ADR_WIDTH] = full ? 1 : 0;
assign wvb_wused[P_ADR_WIDTH - 1:0] = i_wvb_wused;

endmodule
