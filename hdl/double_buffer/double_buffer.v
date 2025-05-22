// double buffer for the mDOM data readout pipeline
//
// used in the hit buffer controller such that the waveform buffer reader can
// operate continously even while the hit buffer controller is consuming
// its output data
//
// Also used to allow the hit buffer controller to continuously pack
// waveform payloads into page DPRAMs even while complete pages are being shipped
//
// Allows for separate read clocks and write clocks,
// but note that all internal logic operates in the write clock domain.


module double_buffer
#(
  parameter P_WR_ADDR_WIDTH = 8,
  parameter P_WR_DATA_WIDTH = 128,
  parameter P_RD_ADDR_WIDTH = 9,
  parameter P_RD_DATA_WIDTH = 64,
  parameter P_SYNC_RD_ADDR = 0
)
(
  input rst,

  // writer interface
  input wr_clk,
  input wr_en,
  input[P_WR_ADDR_WIDTH - 1:0] wr_addr,
  input[P_WR_DATA_WIDTH - 1:0] wr_din,
  input[15:0] dpram_len_in,
  input run,
  output wr_busy,

  // reader interface
  input rd_clk,
  input[P_RD_ADDR_WIDTH - 1:0] rd_addr,
  input[P_RD_DATA_WIDTH - 1:0] rd_dout,
  output[15:0] dpram_len_out,
  input done,
  output rd_busy
);

wire clk = wr_clk;

// RBD signal processes for each buffer
reg wr_buffer_index = 0;
reg rd_buffer_index = 0;

wire[1:0] busy;
wire[15:0] dpram_lens[0:1];
generate
  genvar i;
  for (i = 0; i < 2; i = i + 1) begin
    wire run_i = run && wr_buffer_index == i;
    wire done_i = done && rd_buffer_index == i;
    reg busy_i = 0;
    
    reg[15:0] dpram_len_i = 0;
    always @(posedge clk) begin
      if (rst) begin
        busy_i <= 0;
        dpram_len_i <= 0;
      end else begin
        if (run_i) begin
          dpram_len_i <= dpram_len_in;
          busy_i <= 1;
        end else if (done_i) begin
          busy_i <= 0;
          dpram_len_i <= 0;
        end
      end
    end

    assign busy[i] = busy_i;
    assign dpram_lens[i] = dpram_len_i;
  end
endgenerate

assign wr_busy = busy[wr_buffer_index];
assign rd_busy = busy[rd_buffer_index];
assign dpram_len_out = dpram_lens[rd_buffer_index];

localparam 
  S_IDLE = 0,
  S_BUSY_WAIT = 1,
  S_NOT_BUSY_WAIT = 2;

// writer process
reg[2:0] wr_fsm = S_IDLE;
always @(posedge clk) begin
  if (rst) begin
    wr_buffer_index <= 0;
  end else begin
    case (wr_fsm)
      S_IDLE: begin
        wr_fsm <= S_IDLE;
        if (run && !wr_busy) begin
          wr_fsm <= S_BUSY_WAIT;
        end
      end

      S_BUSY_WAIT: begin
        wr_fsm <= S_BUSY_WAIT;
        if (wr_busy) begin
          wr_buffer_index <= wr_buffer_index + 1;
          wr_fsm <= S_IDLE;
        end
      end

      default: begin
        wr_fsm <= S_IDLE;
      end
    endcase
  end
end

// reader process
reg[2:0] rd_fsm = S_IDLE;
always @(posedge clk) begin
  if (rst) begin
    rd_buffer_index <= 0;
  end else begin
    case (rd_fsm)
      S_IDLE: begin
        rd_fsm <= S_IDLE;
        if (done && rd_busy) begin
          rd_fsm <= S_NOT_BUSY_WAIT;
        end
      end

      S_NOT_BUSY_WAIT: begin
        rd_fsm <= S_NOT_BUSY_WAIT;

        if (!rd_busy) begin
          rd_buffer_index <= rd_buffer_index + 1;
          rd_fsm <= S_IDLE;
        end
      end

      default: begin
        rd_fsm <= S_IDLE;
      end
    endcase
  end
end

wire[P_WR_ADDR_WIDTH:0] internal_wr_addr = {wr_buffer_index, wr_addr};

wire internal_rd_addr_msb;
generate
  if (P_SYNC_RD_ADDR) begin
    sync RD_ADDR_MSB_SYNC(.clk(rd_clk), .rst_n(1'b1), .a(rd_buffer_index), .y(internal_rd_addr_msb));
  end else begin
    assign internal_rd_addr_msb = rd_buffer_index;
  end
endgenerate
wire[P_RD_ADDR_WIDTH:0] internal_rd_addr = {internal_rd_addr_msb, rd_addr};

generate
  if (P_WR_ADDR_WIDTH == 8 && P_RD_ADDR_WIDTH == 9 &&
      P_WR_DATA_WIDTH == 128 && P_RD_DATA_WIDTH == 64) begin
    HBUF_RDOUT_DOUBLE_BUFFER DOUBLE_BUFFER_DPRAM(
      .addra(internal_wr_addr),
      .clka(wr_clk),
      .dina(wr_din),
      .wea(wr_en),
      .addrb(internal_rd_addr),
      .clkb(rd_clk),
      .doutb(rd_dout)
    );
  end else begin
    // TODO: support DDR3 page double buffer as well
    unsupported_parameter_set invalid_module_conf();
  end
endgenerate

endmodule