// Aaron Fienberg
// August 2020
//
// mDOM waveform buffer reader
//
// cycles between multiple input channels
//
// the WVB reader transfers data from the waveform buffers to readout DPRAMs
// in 128-bit words
//

module wvb_reader #(parameter P_DATA_WIDTH = 22,
                    parameter N_CHANNELS = 2,
                    parameter P_WVB_ADR_WIDTH = 12,
                    parameter P_DPRAM_ADR_WIDTH = 8,
                    parameter P_HDR_WIDTH = 80,
                    parameter P_FMT = 0
                   )
(
  input clk,
  input rst,
  input en, //enable

  // DPRAM interface

  // Outputs
  output[127:0] dpram_data,
  output[P_DPRAM_ADR_WIDTH-1:0] dpram_addr,
  output dpram_wren,
  output[15:0] dpram_len,
  output dpram_run,

  // Inputs
  input dpram_busy,
  input dpram_mode,

  // WVB interface

  // Outputs
  output[N_CHANNELS-1:0] hdr_rdreq,
  output[N_CHANNELS-1:0] wvb_rdreq,
  output[N_CHANNELS-1:0] wvb_rddone,

  // Inputs
  input[N_CHANNELS*P_DATA_WIDTH-1:0] wvb_data,
  input[N_CHANNELS*P_HDR_WIDTH-1:0] hdr_data,
  input[N_CHANNELS-1:0] hdr_empty
);

// handle multiplexing/demultiplexing
(* max_fanout = 20 *) reg[4:0] chan_index = 0;
wire[P_DATA_WIDTH-1:0] wvb_data_mux_out;
wire[P_HDR_WIDTH-1:0] hdr_data_mux_out;
wire hdr_empty_mux_out;

// register signals going into muxes
// Note: currently not registering hdr_empty to simplify
// state machine logic
reg[N_CHANNELS*P_DATA_WIDTH-1:0] wvb_data_reg = 0;
reg[N_CHANNELS*P_HDR_WIDTH-1:0] hdr_data_reg = 0;
// reg[N_CHANNELS-1:0] hdr_empty_reg = 0;
// also register data coming out of the mux
reg[P_DATA_WIDTH-1:0] wvb_data_mux_out_reg = 0;
reg[P_HDR_WIDTH-1:0] hdr_data_mux_out_reg = 0;
// reg hdr_empty_mux_out_reg = 0;
always @(posedge clk) begin
  if (rst || !en) begin
    wvb_data_reg <= 0;
    hdr_data_reg <= 0;
    // hdr_empty_reg <= 0;
    wvb_data_mux_out_reg <= 0;
    hdr_data_mux_out_reg <= 0;
    // hdr_empty_mux_out_reg <= 0;
  end

  else begin
    wvb_data_reg <= wvb_data;
    hdr_data_reg <= hdr_data;
    // hdr_empty_reg <= hdr_empty;
    wvb_data_mux_out_reg <= wvb_data_mux_out;
    hdr_data_mux_out_reg <= hdr_data_mux_out;
    // hdr_empty_mux_out_reg <= hdr_empty_mux_out;
  end
end

n_channel_mux #(.N_INPUTS(N_CHANNELS),
                .INPUT_WIDTH(P_DATA_WIDTH)) WVB_DATA_MUX
  (
   .in(wvb_data_reg),
   .sel(chan_index),
   .out(wvb_data_mux_out)
  );

n_channel_mux #(.N_INPUTS(N_CHANNELS),
                .INPUT_WIDTH(P_HDR_WIDTH)) HDR_DATA_MUX
  (
   .in(hdr_data_reg),
   .sel(chan_index),
   .out(hdr_data_mux_out)
  );

n_channel_mux #(.N_INPUTS(N_CHANNELS),
                .INPUT_WIDTH(1)) HDR_EMPTY_MUX
  (
   .in(hdr_empty),
   .sel(chan_index),
   .out(hdr_empty_mux_out)
  );

reg i_hdr_rdreq = 0;
wire i_wvb_rdreq;
wire i_wvb_rddone;
generate
  genvar i;
  for (i = 0; i < N_CHANNELS; i = i + 1) begin : reader_demux
    assign hdr_rdreq[i] = i_hdr_rdreq && (chan_index == i);
    assign wvb_rdreq[i] = i_wvb_rdreq && (chan_index == i);
    assign wvb_rddone[i] = i_wvb_rddone && (chan_index == i);
  end
endgenerate

//
// Read controller instantiation
//

reg rd_ctrl_req = 0;
wire rd_ctrl_ack;
wire rd_ctrl_more; // not used as of rd_ctrl_fmt_3

// read controller
generate
if (P_FMT == 3 && (P_DATA_WIDTH == 85)) begin
  wvb_rd_ctrl_fmt_3 #(.P_WVB_ADR_WIDTH(P_WVB_ADR_WIDTH),
                      .P_HDR_WIDTH(P_HDR_WIDTH))
  RD_CTRL
   (
    .clk(clk),
    .rst(rst || !en),
    .req(rd_ctrl_req),
    .dpram_mode(dpram_mode),
    .ack(rd_ctrl_ack),
    .rd_ctrl_more(rd_ctrl_more),
    .wvb_data(wvb_data_mux_out_reg),
    .hdr_data(hdr_data_mux_out_reg),
    .wvb_rdreq(i_wvb_rdreq),
    .wvb_rddone(i_wvb_rddone),
    .dpram_a(dpram_addr),
    .dpram_data(dpram_data),
    .dpram_wren(dpram_wren),
    .dpram_len(dpram_len)
   );
end else begin
  invalid_p_adr_width invalid_module_conf();
end
endgenerate

posedge_detector PEDGE_ACK(.clk(clk), .rst_n(!rst), .a(rd_ctrl_ack), .y(dpram_run));

// FSM logic
reg[3:0] fsm = 0;
localparam
  S_IDLE = 0,
  S_RD_CTRL_REQ = 1,
  S_DPRAM_BUSY_WAIT = 2,
  S_DPRAM_DONE = 3;

always @(posedge clk) begin
  if (rst || !en) begin
    fsm <= S_IDLE;

    rd_ctrl_req <= 0;
    i_hdr_rdreq <= 0;
    chan_index <= 0;
  end

  else begin
    i_hdr_rdreq <= 0;

    case (fsm)
      S_IDLE: begin
        rd_ctrl_req <= 0;

        if (!hdr_empty_mux_out && !dpram_busy && !rd_ctrl_ack) begin
          i_hdr_rdreq <= 1;
          rd_ctrl_req <= 1;
          fsm <= S_RD_CTRL_REQ;
        end

        else begin
          // cycle to the next channel
          chan_index <= (chan_index + 1) % N_CHANNELS;
          fsm <= S_IDLE;
        end
      end

      S_RD_CTRL_REQ: begin
        rd_ctrl_req <= 1;
        // wait for ack
        if (rd_ctrl_ack) begin
          rd_ctrl_req <= 0;

          chan_index <= (chan_index + 1) % N_CHANNELS;
          fsm <= S_DPRAM_BUSY_WAIT;
        end
      end

      S_DPRAM_BUSY_WAIT: begin
        if (hdr_empty_mux_out) begin
            chan_index <= (chan_index + 1) % N_CHANNELS;
        end

        // wait for DPRAM to become busy
        if (dpram_busy) begin
          fsm <= S_DPRAM_DONE;
        end
      end

      S_DPRAM_DONE: begin
        if (hdr_empty_mux_out) begin
            chan_index <= (chan_index + 1) % N_CHANNELS;
        end

        // wait for DPRAM to be done (no longer busy)
        if (!dpram_busy) begin
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
