// Aaron Fienberg
//
// mDOM waveform buffer read control format 3
// Like format 2 except no footer and bits for partial/continued wfms
// includes assumption that waveforms will be no longer than 1020 samples,
// DPRAM_ABORT_MODE logic is not required

// writes data in chunks of 8 16-bit words
//
// Writes 32-bit words; order of 16-bit sub-words within the 32-bit words
// set so that, when read as a sequence of 16-bit words through the
// direct readout DPRAM read port, the order will be as written below
//
// Waveform Format 3:
//
// CHANNEL      - [15] 1
//                [14:13] 0
//                [12] 1
//                [11:8] Waveform Format (3 for fmt_1)
//                [7:0]  Channel Number
// EVT_LEN      - Number of samples in the waveform
// HDR_0        - [15:11] - preconf
//                   [10] - cnst run mode
//                    [9] - local coinc
//                    [8] - partial wfm
//                    [7] - continued wfm
//                  [6:4] - 0
//                    [3] - icm_sync_rdy
//                    [2] - odd LTC bit (to get from 60 MHz to 120 MHz)
//                  [1:0] - trigger type (sw, thresh, disc, ext)
// LTC_2        - LTC[47:32] (60 MHz LTC)
// LTC_1        - LTC[31:16]
// LTC_0        - LTC[15:0]
// PAT_1        - [15] bsum_valid
//              - [14:12] bsum_len_sel
//              - [11:3] 0
//              - [2:0] bsum[18:16]
// PAT_0        - [15:0] bsum[15:0]
// ADC_WORD     - 16-bit int (sign extended from 12-bit ADC sample)
// DISC/TOT/EOE - [15:8] discriminator word
//              - [7:2] - 0
//              - [1] TOT bit
//              - [0] EOE bit
// .... (repeat of ADC_WORD, DISC/TOT/EOE words)
//
//

module wvb_rd_ctrl_fmt_3 #(parameter P_WVB_ADR_WIDTH = 10,
                           parameter P_DATA_WIDTH = 85,
                           parameter P_HDR_WIDTH = 104)
(
  input clk,
  input rst,

  // wvb_reader interface
  input req,
  input dpram_mode,
  output reg ack = 0,
  output rd_ctrl_more,

  // WVB interface
  input[P_DATA_WIDTH-1:0] wvb_data,
  input[P_HDR_WIDTH-1:0] hdr_data,
  output reg wvb_rdreq = 0,
  output reg wvb_rddone = 0,

  // DPRAM interface
  output reg[7:0] dpram_a = 0,
  output reg[127:0] dpram_data = 0,
  output reg dpram_wren = 0,
  output reg[15:0] dpram_len = 0
);

// fmt_3 assumes event lengths will never exceed one DPRAM
assign rd_ctrl_more = 0;

// header fan out
wire[P_WVB_ADR_WIDTH-1:0] start_addr;
wire[P_WVB_ADR_WIDTH-1:0] stop_addr;
wire[47:0] evt_ltc;
wire odd_ltc_bit;
wire[1:0] trig_src;
wire cnst_run;
wire[4:0] pre_conf;
wire icm_sync_rdy;
wire[18:0] bsum;
wire[2:0] bsum_len_sel;
wire bsum_valid;
wire local_coinc; // T. Anderson Sat 05/21/2022_14:32:00.75
wire partial_wfm;
wire continued_wfm;
wire[4:0] hdr_fan_out_channel_idx;

generate
  if (P_WVB_ADR_WIDTH == 12 && P_HDR_WIDTH == 113 && P_DATA_WIDTH == 85) begin
    mDOM_scdb_hdr_bundle_fan_out HDR_FAN_OUT (
      .bundle(hdr_data),
      .evt_ltc({evt_ltc, odd_ltc_bit}),
      .start_addr(start_addr),
      .stop_addr(stop_addr),
      .trig_src(trig_src),
      .cnst_run(cnst_run),
      .pre_conf(pre_conf),
      .sync_rdy(icm_sync_rdy),
      .bsum(bsum),
      .bsum_len_sel(bsum_len_sel),
      .bsum_valid(bsum_valid),
      .local_coinc(local_coinc),
      .partial_wfm(partial_wfm),
      .continued_wfm(continued_wfm),
      .channel_idx(hdr_fan_out_channel_idx)
    );
  end
  else begin
    invalid_p_adr_width invalid_module_conf();
  end
endgenerate

wire[7:0] payload_channel_idx = {3'b0, hdr_fan_out_channel_idx};

// calculate evt_len
wire[P_WVB_ADR_WIDTH-1:0] addr_diff = stop_addr - start_addr;
wire[12:0] words_written = addr_diff + 16'd1;
// shift left by 3 to get to units of samples
wire[15:0] evt_len = {words_written, 3'b0};

// decode wvb_data
wire[83:0] buffer_words = wvb_data[84:1];
wire wvb_eoe = wvb_data[0];
wire[7:0] discr_wd_array[0:3];
wire[11:0] adc_wd_array[0:3];
wire tot_array[0:3];
wire eoe_array[0:3];
wire[15:0] ext_adc_wd_array[0:3];
wire[31:0] sub_data_words[0:3];
wire[20:0] sub_buffer_words[0:3];

generate
  genvar i_wd;
  for (i_wd = 0; i_wd < 4; i_wd = i_wd + 1) begin
    assign sub_buffer_words[i_wd] = buffer_words[21*(i_wd + 1) - 1 : 21*i_wd];
    assign discr_wd_array[i_wd] = sub_buffer_words[i_wd][20:13];
    assign adc_wd_array[i_wd] = sub_buffer_words[i_wd][12:1];
    assign ext_adc_wd_array[i_wd] = {{4{adc_wd_array[i_wd][11]}}, adc_wd_array[i_wd]};
    assign tot_array[i_wd] = sub_buffer_words[i_wd][0];
    assign eoe_array[i_wd] = i_wd == 3 ? wvb_eoe : 0;

    // construct the data word for sample i_wd
    assign sub_data_words[i_wd] = {
      discr_wd_array[i_wd], 6'b0, tot_array[i_wd], eoe_array[i_wd], 
      ext_adc_wd_array[i_wd]
     }; 
  end
endgenerate

wire[15:0] hdr_0 = {pre_conf, cnst_run, local_coinc, partial_wfm, continued_wfm,
                    3'b0,
                    icm_sync_rdy, odd_ltc_bit, trig_src};

// constants
localparam L_FMT = 8'h93;
localparam L_DPRAM_A_LAST_DATA=8'd254;

// FSM logic
localparam
  S_IDLE = 0,
  S_HDR = 1,
  S_WAIT = 2,
  S_SAMPLE_WORD = 3,
  S_ACK = 4;

reg[3:0] fsm = S_IDLE;
reg[31:0] wait_cnt = 0;
// register evt_len for improved timing
reg[15:0] evt_len_reg = 0;

// each write has 8 groups of 16 bits per row
wire[127:0] evt_hdr = {
  bsum[15:0],
  bsum_valid, bsum_len_sel, 9'b0, bsum[18:16],
  evt_ltc[15:0], 
  evt_ltc[31:16],
  evt_ltc[47:32], 
  hdr_0,
  evt_len_reg,
  L_FMT, payload_channel_idx
};

wire[127:0] data_word = {
  sub_data_words[3],
  sub_data_words[2],
  sub_data_words[1],
  sub_data_words[0]
};

localparam WAIT_CNT_MAX = 5;

always @(posedge clk) begin
  if (rst) begin
    ack <= 0;
    wvb_rdreq <= 0;
    wvb_rddone <= 0;
    dpram_a <= 0;
    dpram_data <= 0;
    dpram_wren <= 0;
    dpram_len <= 0;

    wait_cnt <= 0;
    evt_len_reg <= 0;

    fsm <= S_IDLE;
  end

  else begin
    ack <= 0;
    dpram_wren <= 0;
    wvb_rddone <= 0;
    wvb_rdreq <= 0;

    case (fsm)
      S_IDLE: begin
        dpram_a <= 0;
        dpram_len <= 0;

        wait_cnt <= 0;
        evt_len_reg <= 0;

        if (req) begin
          wait_cnt <= 1;
          fsm <= S_WAIT;
        end
      end

      S_WAIT: begin
        evt_len_reg <= evt_len;
        wvb_rdreq <= 1;
        wait_cnt <= wait_cnt + 1;
        if (wait_cnt == WAIT_CNT_MAX) begin
          fsm <= S_HDR;
        end else begin
          fsm <= S_WAIT;
        end
      end

      S_HDR: begin
        dpram_data <= evt_hdr;
        dpram_wren <= 1;

        wvb_rdreq <= 1;
        fsm <= S_SAMPLE_WORD;
      end

      S_SAMPLE_WORD: begin
        dpram_data <= data_word;
        dpram_wren <= 1;
        dpram_a <= dpram_a + 1;
        
        wvb_rdreq <= 1;
        fsm <= S_SAMPLE_WORD;

        if ((dpram_a == L_DPRAM_A_LAST_DATA) || wvb_eoe)  begin
          // stop writing data if we reach end of DPRAM
          // or if we see the EOE
          wvb_rddone <= 1;
          wvb_rdreq <= 0;

          // convert to number of 16 bit words
          dpram_len <= (dpram_a + 16'd2) << 2'h3;
          ack <= 1;
          fsm <= S_ACK;
        end
      end

      S_ACK: begin
        dpram_len <= dpram_len;
        ack <= 1;

        if (!req) begin
          ack <= 0;
          dpram_len <= 0;
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
