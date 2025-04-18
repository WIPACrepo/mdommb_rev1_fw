// Aaron Fienberg
// August 2020
//
// mDOM waveform buffer rd addr controller
//

module wvb_rd_addr_ctrl #(parameter P_ADR_WIDTH = 12,
                          parameter P_HDR_WIDTH = 80)
(
	input clk,
	input rst,

	input[P_HDR_WIDTH-1:0] hdr_data,
	input hdr_rdreq,
	input wvb_rdreq,
	input wvb_rddone,

	output reg[P_ADR_WIDTH-1:0] wvb_rd_addr = 0
);
`include "mDOM_wvb_hdr_bundle_2_inc.v"
`include "mDOM_wvb_hdr_bundle_3_inc.v" // T. Anderson Sat 05/21/2022_14:24:26.47
`include "mDOM_wvb_hdr_bundle_4_inc.v"

// header fan out
wire[P_ADR_WIDTH-1:0] start_addr;
wire[P_ADR_WIDTH-1:0] stop_addr;
generate
if (P_HDR_WIDTH == 71)
  mDOM_wvb_hdr_bundle_1_fan_out HDR_FAN_OUT (
  	.bundle(hdr_data),
  	.evt_ltc(),
  	.start_addr(start_addr),
  	.stop_addr(stop_addr),
  	.trig_src(),
  	.cnst_run()
  );
else if (P_HDR_WIDTH == L_WIDTH_MDOM_WVB_HDR_BUNDLE_2) begin
  mDOM_wvb_hdr_bundle_2_fan_out HDR_FAN_OUT (
    .bundle(hdr_data),
    .evt_ltc(),
    .start_addr(start_addr),
    .stop_addr(stop_addr),
    .trig_src(),
    .cnst_run(),
    .pre_conf(),
    .sync_rdy(),
    .bsum(),
    .bsum_len_sel(),
    .bsum_valid()
  );
end
else if (P_HDR_WIDTH == L_WIDTH_MDOM_WVB_HDR_BUNDLE_3) begin
  mDOM_wvb_hdr_bundle_3_fan_out HDR_FAN_OUT (
    .bundle(hdr_data),
    .evt_ltc(),
    .start_addr(start_addr),
    .stop_addr(stop_addr),
    .trig_src(),
    .cnst_run(),
    .pre_conf(),
    .sync_rdy(),
    .bsum(),
    .bsum_len_sel(),
    .bsum_valid(),
    .local_coinc()
  );
end
else if (P_HDR_WIDTH == L_WIDTH_MDOM_WVB_HDR_BUNDLE_4) begin
  mDOM_wvb_hdr_bundle_4_fan_out HDR_FAN_OUT (
    .bundle(hdr_data),
    .evt_ltc(),
    .start_addr(start_addr),
    .stop_addr(stop_addr),
    .trig_src(),
    .cnst_run(),
    .pre_conf(),
    .sync_rdy(),
    .bsum(),
    .bsum_len_sel(),
    .bsum_valid(),
    .local_coinc()
  );
end
endgenerate

// determines delay between hdr_rdreq and
// start addr updating
localparam HDR_WAIT_CNT = 2;

reg[2:0] hdr_rd_cnt = 0;
always @(posedge clk) begin
	if (rst) begin
		hdr_rd_cnt <= 0;
	end

	else begin
		if (hdr_rdreq) begin
			hdr_rd_cnt <= 1;
		end

		else if (hdr_rd_cnt >= HDR_WAIT_CNT) begin
			hdr_rd_cnt <= 0;
		end

		else if (hdr_rd_cnt > 0 &&
			       (hdr_rd_cnt < HDR_WAIT_CNT))  begin
			hdr_rd_cnt <= hdr_rd_cnt + 1;
		end
	end
end

// process to update wvb_rd_addr
always @(posedge clk) begin
	if (rst) begin
		wvb_rd_addr <= -1;
	end

	else begin

		if (hdr_rd_cnt == HDR_WAIT_CNT) begin
			wvb_rd_addr <= start_addr;
		end

		else if ((hdr_rd_cnt == 0) && wvb_rdreq) begin
			wvb_rd_addr <= wvb_rd_addr + 1;
		end

		else if (wvb_rddone) begin
			wvb_rd_addr <= stop_addr + 1;
		end

	end

end

endmodule
