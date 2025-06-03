// Aaron Fienberg
// Aug 2020
//
// mDOM hit buffer controller
//
//
// Transfers data from rdout DPRAM into DDR3 page DPRAM
// Sends full pages to DDR3 memory
//
// Reports rd page num and write pg num,
// rd pg is updated externally to free pages
//
// Page format replicates that of the D-Egg:
// 0:      0xA000 - Start of Memory Page Format 0
// 1:      0x5555 - Synchronization pattern
// 2:      0xAAAA - Synchronization pattern
// 3:      0x5555 - Synchronization pattern
// 4:      Waveform Packet Word 0
// 5:      Waveform Packet Word 1
// ...
// 2043:   Waveform Packet Word 2039
// 2044:   0xAAAA - Synchronization pattern
// 2045:   0x5555 - Synchronization pattern
// 2046:   0xAAAA - Synchronization pattern
// 2047:   CRC16  - CRC16 calculated on words 4-2043
//                  Checksum = 0x8005
//                  Polynomial = x^16 + x^15 + x^2 + 1
//                  Initial value = 0xFFFF
//
// 2 filler words of 0x0000 may
// appear between discrete waveform packets

module hbuf_ctrl
(
  input clk,
  input rst,
  input en, // enable

  // DDR3 pages to use for the hit buffer
  // hbuf_controller reads these values once when first enabled
  input[15:0] start_pg,
  input[15:0] stop_pg,
  // readback of internal first page and last page
  // when controller is running
  output[15:0] first_pg,
  output[15:0] last_pg,

  input flush_req,
  output reg flush_ack = 0,

  // "FIFO" status signals
  output empty,
  output full,
  output reg[15:0] rd_pg_num = 0,
  output reg[15:0] wr_pg_num = 0,
  output reg[15:0] n_used_pgs = 0,

  // interface to update the rd_pg
  input[15:0] pg_clr_cnt,
  input pg_clr_req,
  output reg pg_clr_ack = 0,

  // whether the controller has a partially filled memory page
  output reg buffered_data = 0,
  output reg has_queued_page = 0,

  // wvb reader DPRAM interface
  input[15:0] dpram_len_in,
  input rdout_dpram_run,
  output dpram_busy,
  input rdout_dpram_wren,
  input[7:0] rdout_dpram_wr_addr,
  input[127:0] rdout_dpram_data,

  // DDR3 DPRAM interface
  input ddr3_ui_clk,
  output[127:0] ddr3_dpram_dout,
  input[7:0] ddr3_dpram_rd_addr,

  // page transfer request
  input pg_ack,
  output reg pg_req = 0,
  output reg pg_optype = 0,
  output reg[27:0] pg_addr = 0
);

// instantiate the reader DPRAM and the DDR3 DPRAM


//
// wvb_reader readout double buffer
//
wire[15:0] dpram_len;
reg dpram_done = 0;
reg[8:0] rdout_dpram_rd_addr = 0;
wire[63:0] rdout_dpram_dout;
wire rdout_dpram_rd_busy;
double_buffer rdout_double_buffer(
  .rst(rst || !en),
  .wr_clk(clk),
  .wr_en(rdout_dpram_wren),
  .wr_addr(rdout_dpram_wr_addr),
  .wr_din(rdout_dpram_data),
  .dpram_len_in(dpram_len_in),
  .run(rdout_dpram_run),
  .wr_busy(dpram_busy),
  .rd_clk(clk),
  .rd_addr(rdout_dpram_rd_addr),
  .rd_dout(rdout_dpram_dout),
  .dpram_len_out(dpram_len),
  .done(dpram_done),
  .rd_busy(rdout_dpram_rd_busy),
  .any_busy()
);

//
// DDR3 page double buffer
//

reg pg_dpram_wren = 0;
reg[8:0] pg_dpram_wr_addr = 0;
reg[63:0] pg_dpram_din = 0;
wire[15:0] pg_dpram_len_in = 16'd2048;
wire[15:0] pg_dpram_len;
reg pg_dpram_run = 0;
wire pg_dpram_wr_busy;
reg pg_dpram_done = 0;
wire pg_dpram_rd_busy;
wire any_pg_busy;
double_buffer #(.P_WR_ADDR_WIDTH(9),
                .P_WR_DATA_WIDTH(64),
                .P_RD_ADDR_WIDTH(8),
                .P_RD_DATA_WIDTH(128),
                .P_SYNC_RD_ADDR(1))
ddr3_pg_double_buffer(
  .rst(rst || !en),
  .wr_clk(clk),
  .wr_en(pg_dpram_wren),
  .wr_addr(pg_dpram_wr_addr),
  .wr_din(pg_dpram_din),
  .dpram_len_in(pg_dpram_len_in),
  .run(pg_dpram_run),
  .wr_busy(pg_dpram_wr_busy),
  .rd_clk(ddr3_ui_clk),
  .rd_addr(ddr3_dpram_rd_addr),
  .rd_dout(ddr3_dpram_dout),
  .dpram_len_out(pg_dpram_len),
  .done(pg_dpram_done),
  .rd_busy(pg_dpram_rd_busy),
  .any_busy(any_pg_busy)
);

//
// logic and processes to handle n_pgs_used, start_pg, stop_pg,
// and rd_pg update requests
//

// calculate n_used_pages
reg[15:0] n_allocated_pgs = 0;
reg[15:0] i_n_used_pgs = 0;
always @(*) begin
  if (empty) begin
    i_n_used_pgs = 0;
  end

  else if (rd_pg_num == wr_pg_num) begin
    i_n_used_pgs = n_allocated_pgs;
  end

  else if (rd_pg_num > wr_pg_num) begin
    i_n_used_pgs = n_allocated_pgs + wr_pg_num - rd_pg_num;
  end

  else begin
    i_n_used_pgs = wr_pg_num - rd_pg_num;
  end
end

always @(posedge clk) begin
  n_used_pgs <= i_n_used_pgs;
end

// clip clear count at n_used_pgs
wire[15:0] clipped_clr_cnt = pg_clr_cnt > n_used_pgs ? n_used_pgs : pg_clr_cnt;

// register next_rd_pg, pg_clr_req, clipped_clr_cnt
reg pg_clr_req_pl = 0;
reg[15:0] next_rd_pg = 0;
reg full_clear_req = 0;
always @(posedge clk) begin
  full_clear_req <= 0;
  next_rd_pg <= rd_pg_num + clipped_clr_cnt;
  pg_clr_req_pl <= pg_clr_req;

  if (clipped_clr_cnt == n_allocated_pgs) begin
    // special case for a full clear (turn a full buffer into an empty one)
    full_clear_req <= 1;
  end
end

wire pg_clr_req_pe;
posedge_detector P_CLR_REQ_PE(.clk(clk), .rst_n(1'b1),
                              .a(pg_clr_req_pl), .y(pg_clr_req_pe));

wire en_pe;
posedge_detector EN_PE(.clk(clk), .rst_n(1'b1), .a(en), .y(en_pe));


reg[15:0] i_start_pg;
reg[15:0] i_stop_pg;
assign first_pg = i_start_pg;
assign last_pg = i_stop_pg;
// signal a full clear to the hbuf_ctrl FSM
reg full_clear = 0;

// register n_allocated pages, full_clear, i_start_pg, i_stop_pg
// and handle pg_clr requests
always @(posedge clk) begin
  full_clear <= 0;

  if (rst || !en) begin
    rd_pg_num <= 0;
    i_start_pg <= 0;
    i_stop_pg <= 0;
    pg_clr_ack <= 0;
    n_allocated_pgs <= 0;
  end

  else if (en_pe) begin
    rd_pg_num <= start_pg;
    i_start_pg <= start_pg;
    i_stop_pg <= stop_pg;
    n_allocated_pgs <= stop_pg - start_pg + 16'b1;
    if (pg_clr_req) begin
      // clear any requests sent while controller wasn't enabled
      pg_clr_ack <= 1;
    end
  end

  else if (pg_clr_req_pe && !pg_clr_ack) begin
    // update the read pg num
    if (full_clear_req) begin
      rd_pg_num <= rd_pg_num;
      full_clear <= 1;
    end

    else if (next_rd_pg > i_stop_pg) begin
      rd_pg_num <= next_rd_pg - n_allocated_pgs;
    end

    else begin
      rd_pg_num <= next_rd_pg;
    end

    pg_clr_ack <= 1;
  end

  else if (pg_clr_ack && !pg_clr_req) begin
    pg_clr_ack <= 0;
  end
end

// FSM states used by the writer and page fsms
localparam S_IDLE = 0,
           S_WR_HDR = 1,
           S_START_STREAM = 2,
           S_WR_DATA = 3,
           S_RDOUT_DPRAM_NOT_BUSY_WAIT = 4,
           S_WR_FTR = 5,
           S_SEND_PG = 6,
           S_INC_WR_PG = 7,
           S_FLUSH = 8,
           S_FLUSH_ACK = 9,
           S_FULL = 10,
           S_CRC_WAIT = 11,
           S_PRE_REQ_WAIT = 12,
           S_PG_DPRAM_BUSY_WAIT = 13,
           S_PG_DPRAM_NOT_BUSY_WAIT = 14;

//
// hbuf controller fsms
// separate writer & page fsms
//

reg[3:0] writer_fsm = S_IDLE;
reg[3:0] pg_fsm = S_IDLE;
assign full = pg_fsm == S_FULL;
assign empty = (!en) || ((rd_pg_num == wr_pg_num) && !full);

localparam DPRAM_RD_LATENCY = 2;
localparam LAST_PG_DPRAM_ADDR = 511;
// the address of the data currently presented during a stream
wire[8:0] stream_rd_addr = rdout_dpram_rd_addr - DPRAM_RD_LATENCY;

// dpram_len is in units of 16-bit words, we need it in units of 32-bit words
wire[9:0] half_dpram_len = dpram_len >> 1'b1;
// whether the 32-bit DPRAM len is odd; if so, we will need to zero-pad the last 64-bit word
wire odd_dpram_len = half_dpram_len[0] == 1'b1;
// calculate the required number of 64-bit reads
wire[8:0] shifted_dpram_len = half_dpram_len >> 1'b1;
wire[8:0] rd_side_dpram_len = odd_dpram_len ? shifted_dpram_len + 9'b1 : shifted_dpram_len;

reg[8:0] final_dpram_rd_addr = 0;
always @(posedge clk) begin
  // this is the quantity used in the state machine logic below
  final_dpram_rd_addr <= rd_side_dpram_len - 9'b1;
end

wire[15:0] next_wr_pg_num = wr_pg_num == i_stop_pg ? i_start_pg : wr_pg_num + 1;

// Mon 04/04/2022_13:46:04.97
// This is for Jim Braun's issue #11
// We need a register for the number
// of words written so that the software
// knows how many words to read during a
// flush.
// The hit buffer sometimes inserts
// two extra words of zeros at the end of
// waveform packets. Those are included
// in the number of valid words. The footer
// is not included in i_n_words_written.
reg [3:0] prev_fsm = 0;
reg [15:0] 	   i_n_words_written = 0;
always @(posedge clk) begin
    prev_fsm <= writer_fsm;
    if(rst || !en) begin
      i_n_words_written <= 16'd0;
    end

    else if(pg_dpram_wren) begin
      if(prev_fsm==S_WR_HDR) begin
	      i_n_words_written <= 16'd4;
      end else if(prev_fsm==S_WR_DATA) begin
	      i_n_words_written <= i_n_words_written + 16'h4;
      end
    end
end

// crc module
reg crc_rst = 1;
reg crc_en = 0;
wire[15:0] crc_out;
// reorder the words to simulate a 16-bit CRC
wire[63:0] crc_in = {pg_dpram_din[15:0],
                     pg_dpram_din[31:16],
                     pg_dpram_din[47:32],
                     pg_dpram_din[63:48]};
crc16_64b_parallel CRC
(
  .data_in(crc_in),
  .crc_en(crc_en),
  .crc_out(crc_out),
  .rst(crc_rst),
  .clk(clk)
);

localparam HDR = {16'h5555, 16'hAAAA, 16'h5555, 16'hA000};
wire[63:0] pg_ftr = {crc_out, i_n_words_written, 16'h5555, 16'hAAAA};

// synchronize pg_ack
wire pg_ack_s;
sync PGACKSYNC(.clk(clk), .rst_n(!rst), .a(pg_ack), .y(pg_ack_s));

reg[31:0] cnt = 0;
// state to return to after writing the header
reg[3:0] ret = S_IDLE;
reg writer_has_buffered_data = 0;
always @(posedge clk) begin
  if (rst || !en) begin
    dpram_done <= 0;
    flush_ack <= 0;
    rdout_dpram_rd_addr <= 0;

    pg_dpram_wr_addr <= LAST_PG_DPRAM_ADDR;
    pg_dpram_din <= 0;
    pg_dpram_wren <= 0;

    writer_has_buffered_data <= 0;

    crc_rst <= 1;
    crc_en <= 0;

    pg_dpram_run <= 0;

    cnt <= 0;
    ret <= S_IDLE;
    writer_fsm <= S_IDLE;
  end

  else begin
    pg_dpram_wren <= 0;
    dpram_done <= 0;

    flush_ack <= 0;

    crc_rst <= 0;
    crc_en <= 0;

    pg_dpram_run <= 0;

    case (writer_fsm)
      S_IDLE: begin
        ret <= S_IDLE;

        if (pg_dpram_wr_addr == LAST_PG_DPRAM_ADDR) begin
          writer_fsm <= S_WR_HDR;
        end

        else if (dpram_len != 0) begin
          cnt <= 0;
          rdout_dpram_rd_addr <= 0;

          writer_has_buffered_data <= 1;
          writer_fsm <= S_START_STREAM;
        end

        else if (flush_req) begin
          writer_fsm <= S_FLUSH;
        end

      end

      S_WR_HDR: begin
        pg_dpram_wr_addr <= 9'b0;
        pg_dpram_wren <= 1;
        pg_dpram_din <= HDR;

        crc_rst <= 1;

        writer_fsm <= ret;
      end

      S_START_STREAM: begin
        rdout_dpram_rd_addr <= rdout_dpram_rd_addr + 1;
        cnt <= cnt + 1;

        if (cnt >= DPRAM_RD_LATENCY - 1) begin
          writer_fsm <= S_WR_DATA;
        end
      end

      S_WR_DATA: begin
        rdout_dpram_rd_addr <= rdout_dpram_rd_addr + 1;

        pg_dpram_wr_addr <= pg_dpram_wr_addr + 1;
        pg_dpram_wren <= 1;

        pg_dpram_din <= rdout_dpram_dout;
        crc_en <= 1;

        if (stream_rd_addr == final_dpram_rd_addr) begin
          dpram_done <= 1;

          if (odd_dpram_len) begin
            pg_dpram_din <= {32'b0, rdout_dpram_dout[31:0]};
          end

          writer_fsm <= S_RDOUT_DPRAM_NOT_BUSY_WAIT;
        end

        else if (pg_dpram_wr_addr == LAST_PG_DPRAM_ADDR - 2) begin
          // after this page is shipped,
          // restart the stream at the correct addr
          rdout_dpram_rd_addr <= stream_rd_addr + 1;
          cnt <= 0;
          ret <= S_START_STREAM;
          writer_fsm <= S_CRC_WAIT;
        end
      end

      S_RDOUT_DPRAM_NOT_BUSY_WAIT: begin
        if (!rdout_dpram_rd_busy) begin
          if (pg_dpram_wr_addr == LAST_PG_DPRAM_ADDR - 1) begin
            ret <= S_IDLE;
            writer_fsm <= S_CRC_WAIT;
          end

          else begin
            writer_fsm <= S_IDLE;
          end
        end
      end

      S_CRC_WAIT: begin
        // wait one clock cycle for the CRC
        writer_fsm <= S_WR_FTR;
      end

      S_WR_FTR: begin
        pg_dpram_wr_addr <= pg_dpram_wr_addr + 1;
        pg_dpram_wren <= 1;
        pg_dpram_din <= pg_ftr;

        pg_dpram_run <= 1;
        writer_fsm <= S_PG_DPRAM_BUSY_WAIT;
      end

      S_PG_DPRAM_BUSY_WAIT: begin
        writer_fsm <= S_PG_DPRAM_BUSY_WAIT;

        if (pg_dpram_wr_busy) begin
          writer_has_buffered_data <= rdout_dpram_rd_busy;
          writer_fsm <= S_PG_DPRAM_NOT_BUSY_WAIT;
        end
      end

      S_PG_DPRAM_NOT_BUSY_WAIT: begin
        writer_fsm <= S_PG_DPRAM_NOT_BUSY_WAIT;

        if (!pg_dpram_wr_busy) begin
          writer_fsm <= S_WR_HDR;
        end
      end

      S_FLUSH: begin
        pg_dpram_wr_addr <= pg_dpram_wr_addr + 1;
        pg_dpram_wren <= 1;

        pg_dpram_din <= 64'b0;
        crc_en <= 1;

        if (pg_dpram_wr_addr == LAST_PG_DPRAM_ADDR - 2) begin
          ret <= S_FLUSH_ACK;
          writer_fsm <= S_CRC_WAIT;
        end
      end

      S_FLUSH_ACK: begin
        flush_ack <= 1;
        if (!flush_req) begin
          flush_ack <= 0;
          writer_fsm <= S_IDLE;
        end
      end

      default: begin
        writer_fsm <= S_IDLE;
      end
    endcase
  end
end

//
// hbuf controller page transfer fsm
//
reg[31:0] pg_wait_cnt = 0;
localparam PRE_REQ_WAIT_CNT_MAX = 5;

always @(posedge clk) begin
  if (rst || !en) begin
    pg_dpram_done <= 0;
    pg_req <= 0;
    pg_optype <= 0;
    pg_addr <= 0;
    wr_pg_num <= 0;
    pg_wait_cnt <= 0;
    pg_fsm <= S_IDLE;
  end else begin
    pg_dpram_done <= 0;
    pg_req <= 0;

    case (pg_fsm)
      S_IDLE: begin
        pg_wait_cnt <= 0;
        pg_fsm <= S_IDLE;

        if (en_pe) begin
          wr_pg_num <= start_pg;
        end

        if (pg_dpram_len != 0) begin
          pg_wait_cnt <= 1;
          pg_fsm <= S_PRE_REQ_WAIT;
        end
      end

      // wait a few clock cycles for the double buffer pg read address
      // to move through the synchronizer in the DDR3 clock domain
      S_PRE_REQ_WAIT: begin
        pg_wait_cnt <= pg_wait_cnt + 1;
        pg_fsm <= S_PRE_REQ_WAIT;

        if (pg_wait_cnt == PRE_REQ_WAIT_CNT_MAX) begin
          pg_fsm <= S_SEND_PG;
        end
      end

      S_SEND_PG: begin
        pg_addr <= (wr_pg_num << 27'd11);
        pg_optype <= 1'b1;
        pg_req <= 1;
        pg_fsm <= S_SEND_PG;

        if (pg_ack_s) begin
          pg_req <= 0;
          pg_dpram_done <= 1;
          pg_fsm <= S_PG_DPRAM_NOT_BUSY_WAIT;
        end
      end

      S_PG_DPRAM_NOT_BUSY_WAIT: begin
        pg_fsm <= S_PG_DPRAM_NOT_BUSY_WAIT;
        if (!pg_dpram_rd_busy) begin
          pg_fsm <= S_INC_WR_PG;
        end
      end

      S_INC_WR_PG: begin
        pg_fsm <= S_INC_WR_PG;
        if (!pg_ack_s) begin
          wr_pg_num <= next_wr_pg_num;
          if (next_wr_pg_num == rd_pg_num) begin
            pg_fsm <= S_FULL;
          end

          else begin
            pg_fsm <= S_IDLE;
          end
        end
      end

      S_FULL: begin
        if ((rd_pg_num != wr_pg_num) || full_clear) begin
          pg_fsm <= S_IDLE;
        end
      end
    endcase
  end
end

// handle buffered data signal
always @(*) begin
  buffered_data = writer_has_buffered_data;
end

// handle has_queued_page
always @(posedge clk) begin
  if (rst || !en) begin
    has_queued_page <= 0;
  end else begin
    has_queued_page <= any_pg_busy;
  end
end

endmodule
