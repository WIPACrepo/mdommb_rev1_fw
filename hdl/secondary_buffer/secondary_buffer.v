// Aaron Fienberg
//
// mDOM secondary buffer
// 
// moves data from the channel buffers into a larger, shared buffer
// 

module secondary_buffer #(parameter P_DATA_WIDTH = 170,
                          parameter N_CHANNELS = 24,
                          parameter P_WVB_ADR_WIDTH = 9,
                          parameter P_SCDB_ADR_WIDTH = 12,
                          parameter P_WVB_HDR_WIDTH = 102,
                          parameter P_SCDB_HDR_WIDTH = 113,
                          parameter CHANNELS_PER_CYCLE = 8,
                          parameter P_OUTPUT_DATA_WIDTH = 85
                         )
(
  input clk,
  input rst,
  input en, //enable

  // 
  // Reader interface
  // 
  // Outputs
  output[P_OUTPUT_DATA_WIDTH-1:0] buf_data_out,
  output[P_SCDB_HDR_WIDTH-1:0] hdr_data_out,
  output buf_hdr_empty,

  // Inputs
  input buf_rdreq,
  input buf_hdr_rdreq,
  input buf_rddone,
  
  // 
  // WVB interface
  // 
  // Outputs
  output reg[N_CHANNELS-1:0] wvb_hdr_rdreq = 0,
  output reg[N_CHANNELS-1:0] wvb_rdreq = 0,
  output reg[N_CHANNELS-1:0] wvb_rddone = 0,

  // Inputs
  input[N_CHANNELS*P_DATA_WIDTH-1:0] wvb_data,
  input[N_CHANNELS*P_WVB_HDR_WIDTH-1:0] wvb_hdr_data,
  input[N_CHANNELS-1:0] wvb_hdr_empty,
  
  // 
  // Diagnostics
  // 
  output reg[15:0] n_wvf_in_buf = 0,
  output reg[15:0] buf_wds_used = 0
);

localparam P_RD_ADR_WIDTH = P_SCDB_ADR_WIDTH + 1;

// 
// input multiplexing
// 
reg[4:0] next_chan_index = 0;
reg[4:0] current_chan_index = 0;
reg[4:0] prev_chan_index = 0;

wire[P_DATA_WIDTH-1:0] wvb_data_mux_out;
wire[P_WVB_HDR_WIDTH-1:0] wvb_hdr_data_mux_out;
n_channel_mux #(.N_INPUTS(N_CHANNELS),
                .INPUT_WIDTH(P_DATA_WIDTH)) WVB_DATA_MUX
  (
   .in(wvb_data),
   .sel(current_chan_index),
   .out(wvb_data_mux_out)
  );
  
n_channel_mux #(.N_INPUTS(N_CHANNELS),
                .INPUT_WIDTH(P_WVB_HDR_WIDTH)) HDR_DATA_MUX
  (
   .in(wvb_hdr_data),
   .sel(current_chan_index),
   .out(wvb_hdr_data_mux_out)
  );

// register mux outputs
reg[P_DATA_WIDTH-1:0] wvb_data_mux_out_reg = 0;
reg[P_WVB_HDR_WIDTH-1:0] wvb_hdr_data_mux_out_reg = 0;
always @(posedge clk) begin
  if (rst || !en) begin
    wvb_data_mux_out_reg <= 0;
    wvb_hdr_data_mux_out_reg <= 0;
    prev_chan_index <= 0;
  end else begin
    wvb_data_mux_out_reg <= wvb_data_mux_out;
    wvb_hdr_data_mux_out_reg <= wvb_hdr_data_mux_out;
    prev_chan_index <= current_chan_index;
  end
end

// 
// output demultiplexing
// 
wire[N_CHANNELS-1:0] next_wvb_hdr_rdreq;
wire[N_CHANNELS-1:0] next_wvb_rdreq;
wire[N_CHANNELS-1:0] next_wvb_rddone;

generate
  genvar i_chan;
  for (i_chan = 0; i_chan < N_CHANNELS; i_chan = i_chan + 1) begin
    assign next_wvb_hdr_rdreq[i_chan] = next_chan_index == i_chan;
    assign next_wvb_rdreq[i_chan] = current_chan_index == i_chan;
    assign next_wvb_rddone[i_chan] = current_chan_index == i_chan;
  end
endgenerate 

// 
// channel waveform finder process
// 
reg wfm_ready = 0;
reg[4:0] next_base_query_channel = 0;
reg[4:0] query_channels[0:CHANNELS_PER_CYCLE - 1];
reg[CHANNELS_PER_CYCLE - 1:0] wfm_ready_for_channel = 0;

generate
  for (i_chan = 0; i_chan < CHANNELS_PER_CYCLE; i_chan = i_chan + 1) begin
    wire[4:0] query_channel = (next_base_query_channel + i_chan) % N_CHANNELS;
    always @(posedge clk) begin
      if (rst || !en) begin
        query_channels[i_chan] <= 0;
        wfm_ready_for_channel[i_chan] <= 0;
      end else begin
        query_channels[i_chan] <= query_channel;
        wfm_ready_for_channel[i_chan] <= !wvb_hdr_empty[query_channel];
      end
    end
  end
endgenerate

reg query_wfm_ready = 0;
reg[4:0] query_wfm_channel = 0;
integer i;
always @(*) begin
  query_wfm_ready = 0;
  query_wfm_channel = 0;
  for (i = 0; i < CHANNELS_PER_CYCLE; i = i + 1) begin
    if (!query_wfm_ready && wfm_ready_for_channel[i]) begin
      query_wfm_ready = 1;
      query_wfm_channel = query_channels[i];
    end
  end
end
 

// 
// Process that looks through channels in groups to determine which channel has
// a waveform available
// 

reg[3:0] channel_finder_fsm = 0;
localparam
  S_IDLE = 0,
  S_FIND_WFM = 1,
  S_WFM_READY = 2;

always @(posedge clk) begin
  if (rst || !en) begin
    channel_finder_fsm <= S_IDLE;

    wfm_ready <= 0;
    next_chan_index <= 0;
    next_base_query_channel <= 0;
  end else begin
    wfm_ready <= 0;

    case(channel_finder_fsm)
      S_IDLE: begin
        next_base_query_channel <= (next_base_query_channel + CHANNELS_PER_CYCLE) % N_CHANNELS;
        channel_finder_fsm <= S_FIND_WFM;
      end

      S_FIND_WFM: begin
        if (query_wfm_ready) begin
          wfm_ready <= 1;
          next_chan_index <= query_wfm_channel;
          next_base_query_channel <= (query_wfm_channel + 1) % N_CHANNELS; 
          channel_finder_fsm <= S_WFM_READY;
        end else begin
          next_base_query_channel <= (next_base_query_channel + CHANNELS_PER_CYCLE) % N_CHANNELS;
          channel_finder_fsm <= S_FIND_WFM;
        end
      end

      S_WFM_READY: begin
        wfm_ready <= 1;
        next_chan_index <= next_chan_index;
        next_base_query_channel <= (next_chan_index + 1) % N_CHANNELS;
        
        if (wvb_hdr_rdreq[next_chan_index]) begin
          wfm_ready <= 0;
          channel_finder_fsm <= S_FIND_WFM;
          next_base_query_channel <= (next_base_query_channel + CHANNELS_PER_CYCLE) % N_CHANNELS;
        end else begin
          channel_finder_fsm <= S_WFM_READY;
        end
      end

      default: begin
        channel_finder_fsm <= S_IDLE;
        wfm_ready <= 0;
        next_chan_index <= 0;
        next_base_query_channel <= 0;
      end
    
    endcase
  end
end

// 
// process for updating the secondary buffer write address
// 

reg[P_SCDB_ADR_WIDTH - 1:0] scdb_wr_addr = 0;
reg scdb_wren = 0;
always @(posedge clk) begin
  if (rst || !en) begin
    scdb_wr_addr <= 0;
  end else begin
    if (scdb_wren) begin
      scdb_wr_addr <= scdb_wr_addr + 1;
    end
  end
end

// 
// header fan out / fan in
// 

// WVB header fan out
wire[P_WVB_ADR_WIDTH-1:0] wvb_start_addr;
wire[P_WVB_ADR_WIDTH-1:0] wvb_stop_addr;
wire[48:0] evt_ltc;
wire[1:0] trig_src;
wire cnst_run;
wire[4:0] pre_conf;
wire icm_sync_rdy;
wire[18:0] bsum;
wire[2:0] bsum_len_sel;
wire bsum_valid;
wire local_coinc; 
wire partial_wfm;
wire continued_wfm;

mDOM_wvb_hdr_bundle_4_fan_out WVB_HDR_FAN_OUT (
  .bundle(wvb_hdr_data_mux_out_reg),
  .evt_ltc(evt_ltc),
  .start_addr(wvb_start_addr),
  .stop_addr(wvb_stop_addr),
  .trig_src(trig_src),
  .cnst_run(cnst_run),
  .pre_conf(pre_conf),
  .sync_rdy(icm_sync_rdy),
  .bsum(bsum),
  .bsum_len_sel(bsum_len_sel),
  .bsum_valid(bsum_valid),
  .local_coinc(local_coinc),
  .partial_wfm(partial_wfm),
  .continued_wfm(continued_wfm)
);

// SCDB hdr fan out
wire[P_SCDB_ADR_WIDTH-1:0] scdb_stop_addr;
wire[P_SCDB_ADR_WIDTH-1:0] reader_wfm_scdb_start_addr;
mDOM_scdb_hdr_bundle_fan_out SCDB_HDR_FAN_OUT ( 
  .bundle(hdr_data_out),
  .evt_ltc(),
  .start_addr(reader_wfm_scdb_start_addr),
  .stop_addr(scdb_stop_addr),
  .trig_src(),
  .cnst_run(),
  .pre_conf(),
  .sync_rdy(),
  .bsum(),
  .bsum_len_sel(),
  .bsum_valid(),
  .local_coinc(),
  .partial_wfm(),
  .continued_wfm(),
  .channel_idx()
);

// SCDB hdr fan in
wire[P_SCDB_HDR_WIDTH-1:0] scdb_hdr_bundle;
reg[P_SCDB_ADR_WIDTH-1:0] scdb_start_addr = 0;
mDOM_scdb_hdr_bundle_fan_in SCDB_HDR_FAN_IN(
  .bundle(scdb_hdr_bundle),
  .evt_ltc(evt_ltc),
  .start_addr(scdb_start_addr),
  .stop_addr(scdb_wr_addr),
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
  .channel_idx(prev_chan_index)
);

// 
// 
// process for determining the secondary buffer capacity and number of words used
//
// 

reg[P_SCDB_ADR_WIDTH-1:0] last_rd_addr = -1;
reg[P_SCDB_ADR_WIDTH-1:0] scdb_addr_diff = 0;
wire full_condition = (scdb_wr_addr == last_rd_addr) && scdb_wren;
reg full_reg = 0;
always @(posedge clk) begin
  if (rst || !en) begin
    last_rd_addr <= -1;
    scdb_addr_diff <= 0;
    full_reg <= 0;
  end else begin
    scdb_addr_diff <= scdb_wr_addr - (last_rd_addr + 1);
    full_reg <= full_reg && (scdb_wr_addr == last_rd_addr + 1);
    last_rd_addr <= last_rd_addr;

    if (full_condition) begin
      full_reg <= 1;
    end

    if (buf_rddone) begin
      last_rd_addr <= scdb_stop_addr;
      scdb_addr_diff <= scdb_wr_addr - (scdb_stop_addr + 1);
    end
  end
end

wire[P_WVB_ADR_WIDTH-1:0] wvb_addr_diff = wvb_stop_addr - wvb_start_addr;

wire[15:0] i_wds_used;
assign i_wds_used[15:P_SCDB_ADR_WIDTH] = full_reg ? 1 : 0;
assign i_wds_used[P_SCDB_ADR_WIDTH - 1:0] = scdb_addr_diff;
always @(posedge clk) begin
  buf_wds_used <= i_wds_used;
end

// the number of buffer words used plus the length of the wvb event 
// should be <= the total capacity of the secondary buffer
wire[P_SCDB_ADR_WIDTH:0] capacity_check_sum = (wvb_addr_diff + 1) + buf_wds_used;

wire sufficient_capacity = capacity_check_sum[P_SCDB_ADR_WIDTH] == 0;

// 
// secondary buffer write process
//

wire scdb_hdr_full;

reg[3:0] writer_fsm = 0;
localparam
  // S_IDLE = 0, // S_IDLE is already defined earlier in the file, for chan finder fsm
  S_HDR_WAIT = 1,
  S_HDR_RDY = 2,
  S_SAMPLE_WAIT = 3,
  S_WR_DATA = 4,
  S_CACHE_SAMPLES = 5,
  S_WAIT_FOR_CAPACITY = 6,
  S_WR_CACHED_SAMPLES = 7;

reg scdb_hdr_wren = 0;
reg[31:0] wr_cnt = 0;
reg[31:0] rd_cnt = 0;
reg[31:0] wait_cnt = 0;

reg[P_DATA_WIDTH-1:0] scdb_wr_data = 0;

reg[P_DATA_WIDTH-1:0] cached_samples[0:1];


localparam HDR_WAIT_CNT_MAX = 2;
localparam SAMPLE_WAIT_CNT_MAX = 1;
localparam CACHE_SAMPLES_WAIT_CNT_MAX = 3;
localparam WR_CACHED_SAMPLES_WAIT_CNT_MAX = 1;

always @(posedge clk) begin
  if (rst || !en) begin
    scdb_wren <= 0;
    scdb_hdr_wren <= 0;
    wvb_hdr_rdreq <= 0;
    wvb_rdreq <= 0;
    wvb_rddone <= 0;
    scdb_start_addr <= 0;
    current_chan_index <= 0;

    cached_samples[0] <= 0;
    cached_samples[1] <= 0;

    wr_cnt <= 0;
    rd_cnt <= 0;
    wait_cnt <= 0;

    writer_fsm <= S_IDLE;
  end else begin
    scdb_wren <= 0;
    scdb_wr_data <= 0;
    scdb_hdr_wren <= 0;
    wvb_hdr_rdreq <= 0;
    wvb_rdreq <= 0;
    wvb_rddone <= 0;
    scdb_start_addr <= scdb_start_addr;
    current_chan_index <= current_chan_index;

    cached_samples[0] <= cached_samples[0];
    cached_samples[1] <= cached_samples[1];
    
    case(writer_fsm)
      S_IDLE: begin
        wr_cnt <= 0;
        rd_cnt <= 0;
        wait_cnt <= 0;

        if (wfm_ready) begin
          current_chan_index <= next_chan_index;
          wvb_hdr_rdreq <= next_wvb_hdr_rdreq;
          writer_fsm <= S_HDR_WAIT;
        end else begin
          writer_fsm <= S_IDLE;
        end
      end

      S_HDR_WAIT: begin
        wait_cnt <= wait_cnt + 1; 

        if (wait_cnt >= 1) begin
          rd_cnt = rd_cnt + 1;
          wvb_rdreq <= next_wvb_rdreq;
        end 

        if (wait_cnt == HDR_WAIT_CNT_MAX) begin
          writer_fsm <= S_HDR_RDY;
        end else begin
          writer_fsm <= S_HDR_WAIT;
        end
      end

      S_HDR_RDY: begin
        scdb_start_addr <= scdb_wr_addr;
        wait_cnt <= 0;

        if (sufficient_capacity && !scdb_hdr_full) begin
          if (rd_cnt <= wvb_addr_diff) begin
            wvb_rdreq <= next_wvb_rdreq;
            rd_cnt <= rd_cnt + 1;
          end
          writer_fsm <= S_SAMPLE_WAIT;
        end else begin
          writer_fsm <= S_CACHE_SAMPLES;
        end
      end

      S_SAMPLE_WAIT: begin
        wait_cnt <= wait_cnt + 1;

        if (rd_cnt <= wvb_addr_diff) begin
          wvb_rdreq <= next_wvb_rdreq;
          rd_cnt <= rd_cnt + 1;
        end else begin
          rd_cnt <= rd_cnt;
        end

        if (wait_cnt == SAMPLE_WAIT_CNT_MAX) begin
          wait_cnt <= 0;
          writer_fsm <= S_WR_DATA;
        end else begin
          writer_fsm <= S_SAMPLE_WAIT;
        end
      end

      S_WR_DATA: begin
        wr_cnt <= wr_cnt + 1;
        scdb_wr_data <= wvb_data_mux_out_reg;
        scdb_wren <= 1;

        if (rd_cnt <= wvb_addr_diff) begin
          wvb_rdreq <= next_wvb_rdreq;
          rd_cnt <= rd_cnt + 1;
        end else begin
          rd_cnt <= rd_cnt;
        end

        // check whether this is the final write of this waveform
        if (wr_cnt >= wvb_addr_diff) begin
          scdb_hdr_wren <= 1;
          wvb_rddone <= next_wvb_rddone;

          wr_cnt <= 0;
          rd_cnt <= 0;
          wait_cnt <= 0;
          
          if (wfm_ready) begin
            current_chan_index <= next_chan_index;
            wvb_hdr_rdreq <= next_wvb_hdr_rdreq;
            writer_fsm <= S_HDR_WAIT;
          end else begin
            writer_fsm <= S_IDLE;
          end
        end else begin
          writer_fsm <= S_WR_DATA;
        end
      end

      S_CACHE_SAMPLES: begin
        rd_cnt <= rd_cnt;
        wait_cnt <= wait_cnt + 1;
        cached_samples[0] <= cached_samples[1];
        cached_samples[1] <= wvb_data_mux_out_reg;

        if (wait_cnt == CACHE_SAMPLES_WAIT_CNT_MAX) begin
          wait_cnt <= 0;
          writer_fsm <= S_WAIT_FOR_CAPACITY;
        end
      end

      S_WAIT_FOR_CAPACITY: begin
        writer_fsm <= S_WAIT_FOR_CAPACITY;
        wait_cnt <= 0;
        wr_cnt <= 0;
        rd_cnt <= rd_cnt;

        if (sufficient_capacity && !scdb_hdr_full) begin
          if (rd_cnt <= wvb_addr_diff) begin
            wvb_rdreq <= next_wvb_rdreq;
            rd_cnt <= rd_cnt + 1;
          end
          writer_fsm <= S_WR_CACHED_SAMPLES;
        end
      end

      S_WR_CACHED_SAMPLES: begin
        wait_cnt <= wait_cnt + 1;
        wr_cnt <= wr_cnt + 1;
        
        cached_samples[0] <= cached_samples[1];
        cached_samples[1] <= 0;
        scdb_wr_data <= cached_samples[0];
        scdb_wren <= 1;

        if (rd_cnt <= wvb_addr_diff) begin
          wvb_rdreq <= next_wvb_rdreq;
          rd_cnt <= rd_cnt + 1;
        end else begin
          rd_cnt <= rd_cnt;
        end

        // check whether this is the final write of this waveform
        if (wr_cnt >= wvb_addr_diff) begin
          scdb_hdr_wren <= 1;
          wvb_rddone <= next_wvb_rddone;

          wr_cnt <= 0;
          rd_cnt <= 0;
          wait_cnt <= 0;
          
          if (wfm_ready) begin
            current_chan_index <= next_chan_index;
            wvb_hdr_rdreq <= next_wvb_hdr_rdreq;
            writer_fsm <= S_HDR_WAIT;
          end else begin
            writer_fsm <= S_IDLE;
          end
        end else if (wait_cnt == WR_CACHED_SAMPLES_WAIT_CNT_MAX) begin
          wait_cnt <= SAMPLE_WAIT_CNT_MAX - 1;
          writer_fsm <= S_SAMPLE_WAIT;
        end else begin
          writer_fsm <= S_WR_CACHED_SAMPLES;
        end          
      end

      default: begin
        writer_fsm <= S_IDLE;
      end
    endcase
  end
end


// 
// secondary buffer rd addr process
// 
// keep in mind the read port is half as wide as the write port,
// so there are two read addresses per write address
// 
localparam HDR_WAIT_CNT = 2;

reg[2:0] hdr_rd_cnt = 0;
always @(posedge clk) begin
  if (rst || !en) begin
    hdr_rd_cnt <= 0;
  end else begin
    if (buf_hdr_rdreq) begin
      hdr_rd_cnt <= 1;
    end else if (hdr_rd_cnt >= HDR_WAIT_CNT) begin
      hdr_rd_cnt <= 0;
    end else if (hdr_rd_cnt > 0 && (hdr_rd_cnt < HDR_WAIT_CNT)) begin
			hdr_rd_cnt <= hdr_rd_cnt + 1;
		end
  end
end

// not that in the following logic,
// we have to shift left to account for the extra bit in the read address 
wire[P_RD_ADR_WIDTH - 1:0] final_stop_addr = {scdb_stop_addr, 1'b1};
wire[P_RD_ADR_WIDTH - 1:0] shifted_start_addr =  {reader_wfm_scdb_start_addr, 1'b0};
reg[P_RD_ADR_WIDTH - 1:0] scdb_rd_addr = 0;
always @(posedge clk) begin
  if (rst || !en) begin
    scdb_rd_addr <= -1;
  end else begin
    if (hdr_rd_cnt == HDR_WAIT_CNT) begin       
      scdb_rd_addr <= shifted_start_addr;
    end else if (buf_rddone) begin
      scdb_rd_addr <= final_stop_addr;
    end else if ((hdr_rd_cnt == 0) && buf_rdreq) begin
      if (scdb_rd_addr == final_stop_addr) begin
        scdb_rd_addr <= final_stop_addr;
      end else begin
        scdb_rd_addr <= scdb_rd_addr + 1;
      end
    end
  end
end

// 
// the underlying header fifo and sample buffer
//

wire[116:0] scdb_hdr_data_in = {{117-P_SCDB_HDR_WIDTH{1'b0}}, scdb_hdr_bundle};
wire[116:0] scdb_hdr_data_out;
wire[10:0] scdb_hdr_data_count;

reg[116:0] scdb_hdr_data_in_1 = 0;
reg scdb_hdr_wren_1 = 0;
always @(posedge clk) begin
  if (rst || !en) begin
    scdb_hdr_data_in_1 <= 0;
    scdb_hdr_wren_1 <= 0;
  end else begin
    scdb_hdr_data_in_1 <= scdb_hdr_data_in;
    scdb_hdr_wren_1 <= scdb_hdr_wren;
  end
end

FIFO_2048_117 SCDB_HDR_FIFO (
  .clk(clk),
  .srst(rst || !en),
  .din(scdb_hdr_data_in_1),
  .wr_en(scdb_hdr_wren_1),
  .rd_en(buf_hdr_rdreq),
  .empty(buf_hdr_empty),
  .full(scdb_hdr_full),
  .dout(scdb_hdr_data_out),
  .data_count(scdb_hdr_data_count)
);
assign hdr_data_out = scdb_hdr_data_out[P_SCDB_HDR_WIDTH-1:0];
always @(posedge clk) begin
  if (rst || !en) begin
    n_wvf_in_buf <= 0;
  end else begin
    if (scdb_hdr_full) begin
      n_wvf_in_buf <= 16'd2048;
    end else begin
      n_wvf_in_buf <= {5'b0, scdb_hdr_data_count};
    end
  end
end

reg[P_DATA_WIDTH-1:0] scdb_wr_data_1 = 0;
reg[P_SCDB_ADR_WIDTH - 1:0] scdb_wr_addr_1 = 0;
reg scdb_wren_1 = 0;
always @(posedge clk) begin
  if (rst || !en) begin
    scdb_wr_data_1 <= 0;
    scdb_wr_addr_1 <= 0;
    scdb_wren_1 <= 0;
  end else begin
    scdb_wr_data_1 <= scdb_wr_data;
    scdb_wr_addr_1 <= scdb_wr_addr;
    scdb_wren_1 <= scdb_wren;
  end
end

MDOM_SECONDARY_BUFFER SCDB(
  .clka(clk),
  .wea(scdb_wren_1),
  .addra(scdb_wr_addr_1),
  .dina(scdb_wr_data_1),
  .clkb(clk),
  .addrb(scdb_rd_addr),
  .doutb(buf_data_out)
);

endmodule
