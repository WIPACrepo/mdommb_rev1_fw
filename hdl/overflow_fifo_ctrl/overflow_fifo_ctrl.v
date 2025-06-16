// Aaron Fienberg
//
// overflow fifo controller
//
// handles recording channel overflow deadtimes
//
// includes a FIFO for data storage and logic for handshaking with the
// channel waveform acquisition modules
//

module overflow_fifo_ctrl #(parameter N_CHANNELS = 24,
                            parameter P_LTC_WIDTH = 48)
(
  input clk,
  input rst,

  // waveform acquisition module interface
  input[N_CHANNELS-1:0] req,
  input[N_CHANNELS*P_LTC_WIDTH-1:0] overflow_start_ltc,
  input[N_CHANNELS*P_LTC_WIDTH-1:0] overflow_end_ltc,

  output reg[N_CHANNELS-1:0] ack = 0,

  // xdom / FIFO interface
  input rd_req,

  output[15:0] overflow_fifo_count,
  output[P_LTC_WIDTH-1:0] overflow_start_ltc_out,
  output[P_LTC_WIDTH-1:0] overflow_end_ltc_out,
  output[4:0] channel_index_out
);

// register mux inputs
reg[4:0] channel_index = 0;
reg[N_CHANNELS-1:0] one_hot_channel_index = 0;
integer i;
always @(*) begin
  for (i = 0; i < N_CHANNELS; i = i + 1) begin
    one_hot_channel_index[i] = channel_index == i;
  end
end

reg[N_CHANNELS*P_LTC_WIDTH-1:0] overflow_start_ltc_mux_in = 0;
reg[N_CHANNELS*P_LTC_WIDTH-1:0] overflow_end_ltc_mux_in = 0;
reg[N_CHANNELS-1:0] req_mux_in = 0;

// register mux inputs
// always @(posedge clk) begin
//   overflow_start_ltc_mux_in <= overflow_start_ltc;
//   overflow_end_ltc_mux_in <= overflow_end_ltc;
//   req_mux_in <= req;
// end

// do not register mux inputs
always @(*) begin
  overflow_start_ltc_mux_in = overflow_start_ltc;
  overflow_end_ltc_mux_in = overflow_end_ltc;
  req_mux_in = req;
end

wire[P_LTC_WIDTH-1:0] overflow_start_ltc_mux_out;
wire[P_LTC_WIDTH-1:0] overflow_end_ltc_mux_out;
wire req_mux_out;

n_channel_mux #(.N_INPUTS(N_CHANNELS),
                .INPUT_WIDTH(P_LTC_WIDTH)) LTC_START_MUX
  (
   .in(overflow_start_ltc_mux_in),
   .sel(channel_index),
   .out(overflow_start_ltc_mux_out)
  );

n_channel_mux #(.N_INPUTS(N_CHANNELS),
                .INPUT_WIDTH(P_LTC_WIDTH)) LTC_END_MUX
  (
   .in(overflow_end_ltc_mux_in),
   .sel(channel_index),
   .out(overflow_end_ltc_mux_out)
  );

n_channel_mux #(.N_INPUTS(N_CHANNELS),
                .INPUT_WIDTH(1)) REQ_MUX
  (
   .in(req_mux_in),
   .sel(channel_index),
   .out(req_mux_out)
  );

// register mux outputs as well
reg[P_LTC_WIDTH-1:0] overflow_start_ltc_reg = 0;
reg[P_LTC_WIDTH-1:0] overflow_end_ltc_reg = 0;
reg req_reg = 0;
always @(posedge clk) begin
  overflow_start_ltc_reg <= overflow_start_ltc_mux_out;
  overflow_end_ltc_reg <= overflow_end_ltc_mux_out;
  req_reg <= req_mux_out;
end

//
// controller fsm
//
reg fifo_wren = 0;
reg[102:0] fifo_din = 0;
reg[N_CHANNELS-1:0] i_ack = 0;
wire fifo_full;

localparam
  S_IDLE = 0,
  S_QUERY = 1,
  S_WRITE = 2,
  S_ACK = 3,
  S_FULL = 4;
reg[2:0] fsm = S_IDLE;

always @(posedge clk) begin
  if (rst) begin
    fifo_wren <= 0;
    fifo_din <= 0;
    i_ack <= 0;
    channel_index <= 0;

    fsm <= S_IDLE;
  end else begin
    fifo_wren <= 0;
    i_ack <= 0;
    fifo_din <= 0;

    case (fsm)
      // after changing the channel index, we need to wait another clock cycle
      // for the registered mux outputs to reflect the change
      // so, typically, we alternate between S_QUERY and S_IDLE, waiting one full
      // clock cycle after changing the channel index before checking whether req_reg is asserted
      S_IDLE: begin
        if (fifo_full) begin
          fsm <= S_FULL;
        end else begin
          fsm <= S_QUERY;
        end
      end

      S_QUERY: begin
        if (req_reg) begin
          fsm <= S_WRITE;
        end else begin
          channel_index <= (channel_index + 1) % N_CHANNELS;
          fsm <= S_IDLE;
        end
      end

      S_WRITE: begin
        fifo_din <= {overflow_start_ltc_reg,
                     overflow_end_ltc_reg,
                     channel_index};
        fifo_wren <= 1;
        fsm <= S_ACK;
      end

      S_ACK: begin
        i_ack <= one_hot_channel_index;
        fsm <= S_ACK;

        if (!req_reg) begin
          i_ack <= 0;
          channel_index <= (channel_index + 1) % N_CHANNELS;
          if (fifo_full) begin
            fsm <= S_FULL;
          end else begin
            fsm <= S_IDLE;
          end
        end
      end

      S_FULL: begin
        fsm <= S_FULL;

        if (!fifo_full) begin
          fsm <= S_IDLE;
        end
      end

      default: begin
        fsm <= S_IDLE;
      end
    endcase
  end
end

// underlying fifo
wire[8:0] data_count;
wire fifo_empty;
wire[102:0] fifo_dout;
OVERFLOW_FIFO overflow_fifo_storage (
  .clk(clk),
  .srst(rst),
  .full(fifo_full),
  .din(fifo_din),
  .wr_en(fifo_wren),
  .empty(fifo_empty),
  .dout(fifo_dout),
  .rd_en(rd_req),
  .data_count(data_count)
);

// output wiring
always @(posedge clk) begin
  ack <= i_ack;
end

assign overflow_fifo_count = {6'b0, fifo_full, data_count};
assign overflow_start_ltc_out = fifo_dout[(2*P_LTC_WIDTH + 5) - 1:P_LTC_WIDTH +5];
assign overflow_end_ltc_out = fifo_dout[(P_LTC_WIDTH + 5) - 1:5];
assign channel_index_out = fifo_dout[4:0];

endmodule