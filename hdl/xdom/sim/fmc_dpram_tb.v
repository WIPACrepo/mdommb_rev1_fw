// fmc_dpram_tb.v  (mdommb_rev1_fw issue #4: rare single-bit errors in FMC
// hit buffer pages)
//
// Simulates MCU reads and writes of the xdom DDR3 page DPRAM over the FMC with
// the real RTL:
//   - the FMC glue of mdommb_fw_rev1_top.v, included verbatim from the top
//     level (run_fmc_dpram_sim.sh extracts it into fmc_glue_from_top.vh),
//   - xdom.v (task registers, read mux, DPRAMs) and crs_master.v,
//   - DDR3_pg_transfer_mux.v and DDR3_DPRAM_transfer.v / DDR3_pg_transfer_ctrl.v,
// with the IP replaced by the models in fmc_dpram_models.v.
//
// The MCU model follows STM32Workspace (xdom-hal fmc.c, mdom_fpga_hal.c,
// hit_buffer.c): FMC Mode A, fmc_ker_ck = 100 MHz, ADDSET/DATAST cycles,
// 16-bit bus.  A hit page is loaded by writing DPRAM_SEL, the DDR3 optype
// and the 32-bit page address, setting the DDR3 page task bit and polling it
// until clear, and then copying the 2048-word DPRAM with 32-bit MDMA reads
// (two 16-bit FMC reads each, a short pause after every 16 bytes).  The page
// is checked like _verify_page(): version, length, sync words and CRC, with
// up to two reloads.  User pages are written into the DPRAM over the FMC,
// stored to DDR3, reloaded and compared.
//
// The MCU is not synchronous to the FPGA: fmc_ker_ck and lclk are
// independent.  Each FMC pin has its own delay from the MCU clock edge to the
// FPGA logic (MCU output delay, board and FPGA input routing), drawn once per
// run (PIN_DLY_MIN..PIN_DLY_MAX, i.e. one board/build), plus a small random
// jitter per transition.  The FPGA read data reach the MCU FPGA_OUT_DLY after
// they change inside the FPGA, and the MCU flags any change within MCU_TSU of
// its sample point.
//
// NE_GAP selects how the FMC ends a read: with NE_GAP > 0, FMC_NEx rises with
// FMC_NOE and the next address follows NE_GAP cycles later; with NE_GAP = 0,
// FMC_NEx stays low and the next address follows on the same edge as FMC_NOE
// rises.
//
// XDOM_DDR3_PG (fmc_dpram_models.v) counts every address setup/hold violation
// on its ports, and the testbench attributes each port A violation to the FMC
// pin that changed last before it.  With CORRUPT_PPM > 0 a violation flips one
// bit of the word addressed just before or after the offending change with
// that probability (per million), as a stand-in for the data corruption the
// Spartan-7 data sheet warns of.
//
// Summary lines start with "RESULT", the last one PASS or FAIL.  FAIL means a
// page failed the MCU checks, a data mismatch went undetected, a user page or
// control register read back wrong, the MCU saw read data change within its
// setup time, or, with EXPECT_NO_VIOLATIONS=1, a DPRAM address violation.

`timescale 1ns/1fs

module fmc_dpram_tb;

parameter integer ADDSET = 3;              // fmc_ker_ck cycles (MCU 0x58: 3; before: 1)
parameter integer DATAST = 7;              // fmc_ker_ck cycles
parameter integer NE_GAP = 1;              // fmc_ker_ck cycles with NE high between accesses
parameter integer N_HIT_PAGES = 8;
parameter integer N_USER_PAGES = 1;
parameter integer CORRUPT_PPM = 0;
parameter integer EXPECT_NO_VIOLATIONS = 0;
parameter integer SEED = 1;
parameter integer VERBOSE = 0;
parameter real T_FMC = 10.000037;          // fmc_ker_ck (not locked to lclk)
parameter real T_LCLK = 8.333333;          // lclk, 120 MHz
parameter real PIN_DLY_MIN = 2.0;          // MCU clock edge -> FPGA logic, per pin
parameter real PIN_DLY_MAX = 6.0;
parameter real JITTER = 0.25;
parameter real FPGA_OUT_DLY = 15.0;        // FPGA read data -> MCU pins
parameter real MCU_TSU = 11.0;             // MCU data setup before NOE rises

integer seed = SEED;

function real urand(input real lo, input real hi);
  integer r;
  begin
    r = $random(seed) & 32'h7fffffff;
    urand = lo + (hi - lo) * (r % 1000000) / 1000000.0;
  end
endfunction

// ---------------------------------------------------------------------------
// clocks and reset
reg lclk = 1'b0;
reg fmc_ck = 1'b0;
reg lclk_rst = 1'b1;
initial begin
  #(urand(0.0, T_LCLK));
  forever #(T_LCLK / 2) lclk = !lclk;
end
initial begin
  #(urand(0.0, T_FMC));
  forever #(T_FMC / 2) fmc_ck = !fmc_ck;
end
initial begin
  #200 lclk_rst = 1'b0;
end

// ---------------------------------------------------------------------------
// FMC pins as seen by the FPGA logic (names as in mdommb_fw_rev1_top.v)
wire [15:0] i_fmc_din;
wire [15:0] i_fmc_dout;
reg  [11:0] i_fmc_a = 12'h0;
reg         i_fmc_oen = 1'b1;
wire        i_fmc_oen_ne;
reg         i_fmc_wen = 1'b1;
wire        i_fmc_wen_ne;
reg         i_fmc_cen = 1'b1;

// FMC_D: the FPGA drives it while it sees FMC_OEn low (as in the top level);
// otherwise the MCU's write data (or the last value) is on the bus.
reg  [15:0] mcu_d_at_fpga = 16'h0;
assign i_fmc_din = (i_fmc_oen == 1'b0) ? i_fmc_dout : mcu_d_at_fpga;

// ---- FMC glue, verbatim from hdl/mdommb_fw_rev1_top.v ----
`include "fmc_glue_from_top.vh"
// ---- end of FMC glue ----

// ---------------------------------------------------------------------------
// xdom, connected as in the top level (unused inputs tied off)
localparam N_CHANNELS = 24;
wire ddr3_ui_clk;
wire [27:0] xdom_pg_req_addr;
wire xdom_pg_optype;
wire xdom_pg_req;
wire xdom_pg_ack;
wire ddr3_sys_rst;
wire ddr3_cal_complete;
wire ddr3_ui_sync_rst;
wire [7:0] ddr3_dpram_addr;
wire xdom_ddr3_dpram_wren;
wire [127:0] ddr3_dpram_din;
wire [127:0] xdom_ddr3_dpram_dout;

xdom #(.N_CHANNELS(N_CHANNELS)) XDOM_0
(
  .clk(lclk),
  .rst(lclk_rst),
  .vnum(16'h2f),
  .wvb_armed({N_CHANNELS{1'b0}}),
  .wvb_overflow({N_CHANNELS{1'b0}}),
  .wvb_hdr_full({N_CHANNELS{1'b0}}),
  .wvb_not_empty({N_CHANNELS{1'b0}}),
  .wfms_in_buf({(N_CHANNELS*16){1'b0}}),
  .buf_wds_used({(N_CHANNELS*16){1'b0}}),
  .dpram_len_in(16'h0),
  .rdout_dpram_run(1'b0),
  .rdout_dpram_wren(1'b0),
  .rdout_dpram_wr_addr(8'h0),
  .rdout_dpram_data(128'h0),
  .adc_delay_tap_out({(N_CHANNELS*10){1'b0}}),
  .adc_spi_ack(1'b0),
  .adc_spi_rd_data(8'h0),
  .dac_spi_ack(1'b0),
  .slo_adc_ack(1'b0),
  .slo_adc_rd_data(19'h0),
  .ddr3_ui_clk(ddr3_ui_clk),
  .pg_req_addr(xdom_pg_req_addr),
  .pg_optype(xdom_pg_optype),
  .pg_req(xdom_pg_req),
  .pg_ack(xdom_pg_ack),
  .ddr3_sys_rst(ddr3_sys_rst),
  .ddr3_cal_complete(ddr3_cal_complete),
  .ddr3_ui_sync_rst(ddr3_ui_sync_rst),
  .ddr3_device_temp(12'h0),
  .ddr3_dpram_addr(ddr3_dpram_addr),
  .ddr3_dpram_wren(xdom_ddr3_dpram_wren),
  .ddr3_dpram_din(ddr3_dpram_din),
  .ddr3_dpram_dout(xdom_ddr3_dpram_dout),
  .hbuf_first_pg(16'h0),
  .hbuf_last_pg(16'h0),
  .hbuf_pg_clr_ack(1'b0),
  .hbuf_flush_ack(1'b0),
  .hbuf_rd_pg_num(16'h0),
  .hbuf_wr_pg_num(16'h0),
  .hbuf_n_used_pgs(16'h0),
  .hbuf_empty(1'b1),
  .hbuf_full(1'b0),
  .hbuf_buffered_data(1'b0),
  .hbuf_has_queued_page(1'b0),
  .disc_scaler_out({(N_CHANNELS*32){1'b0}}),
  .thresh_scaler_out({(N_CHANNELS*32){1'b0}}),
  .ltc_rd_data(48'h0),
  .ltc_rd_ack(1'b0),
  .icm_sync_rdy(1'b0),
  .icm_sync_err(1'b0),
  .expected_sync_ltc(48'h0),
  .received_sync_ltc(48'h0),
  .icm_sync_err_cnt(16'h0),
  .i2cm_0_ack(1'b0),
  .i2cm_0_rx_data(8'h0),
  .i2cm_0_i2c_acked(1'b0),
  .i2cm_0_rx_fifo_full(1'b0),
  .i2cm_0_rx_fifo_empty(1'b1),
  .i2cm_0_tx_fifo_full(1'b0),
  .i2cm_0_tx_fifo_empty(1'b1),
  .n_wvf_in_scdb_0(16'h0),
  .scdb_wds_used_0(16'h0),
  .n_wvf_in_scdb_1(16'h0),
  .scdb_wds_used_1(16'h0),
  .n_wvf_in_scdb_2(16'h0),
  .scdb_wds_used_2(16'h0),
  .overflow_fifo_data_count(16'h0),
  .overflow_start_ltc_out(49'h0),
  .overflow_end_ltc_out(49'h0),
  .overflow_channel_index_out(5'h0),
  .debug_txd(1'b1),
  .debug_rts_n(1'b0),
  .icm_rx(1'b1),
  .icm_cts(1'b0),
  .mcu_tx(1'b1),
  .mcu_rts_n(1'b0),

  // priority input / FMC
  .po_wr(lclk_fmc_wren),
  .po_en(!fmc_cen_mux),
  .po_a(fmc_addr_mux),
  .po_din(i_fmc_din_1),
  .po_dout(po_dout)
);

// DDR3 page transfer mux and controller, as in the top level (hit buffer idle)
wire ddr3_pg_req;
wire ddr3_pg_optype;
wire ddr3_pg_ack;
wire [27:0] ddr3_pg_req_addr;
wire [127:0] ddr3_dpram_dout;
wire ddr3_dpram_wren;
wire hbuf_pg_ack;

DDR3_pg_transfer_mux DDR3_MUX
(
  .clk(ddr3_ui_clk),
  .rst(ddr3_ui_sync_rst),
  .hbuf_pg_req(1'b0),
  .hbuf_pg_optype(1'b0),
  .hbuf_pg_ack(hbuf_pg_ack),
  .hbuf_pg_req_addr(28'h0),
  .hbuf_dpram_dout(128'h0),
  .xdom_pg_req(xdom_pg_req),
  .xdom_pg_optype(xdom_pg_optype),
  .xdom_pg_ack(xdom_pg_ack),
  .xdom_pg_req_addr(xdom_pg_req_addr),
  .xdom_dpram_dout(xdom_ddr3_dpram_dout),
  .xdom_dpram_wren(xdom_ddr3_dpram_wren),
  .ddr3_pg_req(ddr3_pg_req),
  .ddr3_pg_optype(ddr3_pg_optype),
  .ddr3_pg_ack(ddr3_pg_ack),
  .ddr3_pg_req_addr(ddr3_pg_req_addr),
  .ddr3_dpram_dout(ddr3_dpram_dout),
  .ddr3_dpram_wren(ddr3_dpram_wren)
);

wire [15:0] ddr3_dq;
wire [1:0] ddr3_dqs_n, ddr3_dqs_p;
wire [13:0] ddr3_addr;
wire [2:0] ddr3_ba;
wire ddr3_ras_n, ddr3_cas_n, ddr3_we_n, ddr3_reset_n;
wire [0:0] ddr3_ck_p, ddr3_ck_n, ddr3_cke, ddr3_cs_n, ddr3_odt;
wire [1:0] ddr3_dm;
wire [11:0] ddr3_device_temp;

DDR3_DPRAM_transfer DDR3_TRANSFER_0
(
  .ddr3_dq(ddr3_dq),
  .ddr3_dqs_n(ddr3_dqs_n),
  .ddr3_dqs_p(ddr3_dqs_p),
  .ddr3_addr(ddr3_addr),
  .ddr3_ba(ddr3_ba),
  .ddr3_ras_n(ddr3_ras_n),
  .ddr3_cas_n(ddr3_cas_n),
  .ddr3_we_n(ddr3_we_n),
  .ddr3_reset_n(ddr3_reset_n),
  .ddr3_ck_p(ddr3_ck_p),
  .ddr3_ck_n(ddr3_ck_n),
  .ddr3_cke(ddr3_cke),
  .ddr3_cs_n(ddr3_cs_n),
  .ddr3_dm(ddr3_dm),
  .ddr3_odt(ddr3_odt),
  .sys_clk_i(1'b0),
  .clk_ref_i(1'b0),
  .ui_clk(ddr3_ui_clk),
  .sys_rst(ddr3_sys_rst),
  .pg_req(ddr3_pg_req),
  .pg_optype(ddr3_pg_optype),
  .pg_req_addr(ddr3_pg_req_addr),
  .pg_ack(ddr3_pg_ack),
  .init_calib_complete(ddr3_cal_complete),
  .ui_clk_sync_rst(ddr3_ui_sync_rst),
  .device_temp(ddr3_device_temp),
  .dpram_dout(ddr3_dpram_dout),
  .dpram_din(ddr3_dpram_din),
  .dpram_addr(ddr3_dpram_addr),
  .dpram_wren(ddr3_dpram_wren)
);

defparam XDOM_0.PG_DPRAM.CORRUPT_PPM = CORRUPT_PPM;
defparam XDOM_0.PG_DPRAM.SEED = SEED + 1000;
defparam XDOM_0.PG_DPRAM.VERBOSE = VERBOSE;
defparam DDR3_TRANSFER_0.MIG_7_SERIES.SEED = SEED + 2000;

// ---------------------------------------------------------------------------
// MCU FMC model

// per-pin delay from the MCU clock edge to the FPGA logic, fixed for the run
real dly_a [0:11];
real dly_cen, dly_oen, dly_wen, dly_d;
integer j;
initial begin
  for (j = 0; j < 12; j = j + 1) dly_a[j] = urand(PIN_DLY_MIN, PIN_DLY_MAX);
  dly_cen = urand(PIN_DLY_MIN, PIN_DLY_MAX);
  dly_oen = urand(PIN_DLY_MIN, PIN_DLY_MAX);
  dly_wen = urand(PIN_DLY_MIN, PIN_DLY_MAX);
  dly_d = urand(PIN_DLY_MIN, PIN_DLY_MAX);
end

task drive_a(input [11:0] v);
  integer b;
  for (b = 0; b < 12; b = b + 1)
    i_fmc_a[b] <= #(dly_a[b] + urand(0.0, JITTER)) v[b];
endtask
task drive_cen(input v);
  i_fmc_cen <= #(dly_cen + urand(0.0, JITTER)) v;
endtask
task drive_oen(input v);
  i_fmc_oen <= #(dly_oen + urand(0.0, JITTER)) v;
endtask
task drive_wen(input v);
  i_fmc_wen <= #(dly_wen + urand(0.0, JITTER)) v;
endtask
task drive_d(input [15:0] v);
  mcu_d_at_fpga <= #(dly_d + urand(0.0, JITTER)) v;
endtask

// FPGA read data as seen at the MCU
reg [15:0] d_at_mcu = 16'hzzzz;
realtime t_d_at_mcu = 0.0;
always @(i_fmc_dout or i_fmc_oen)
  d_at_mcu <= #(FPGA_OUT_DLY) ((i_fmc_oen == 1'b0) ? i_fmc_dout : 16'hzzzz);
always @(d_at_mcu) t_d_at_mcu = $realtime;

integer n_access = 0, n_rd_setup_viol = 0;
real min_rd_margin = 1.0e9, min_dpram_rd_margin = 1.0e9;

// start a new access: on the same edge as the previous access ended when NE
// stays low between accesses, otherwise NE_GAP edges later
reg at_end_edge = 1'b0;
task begin_access;
  begin
    if (!(at_end_edge && NE_GAP == 0)) begin
      if (at_end_edge) repeat (NE_GAP) @(posedge fmc_ck);
      else @(posedge fmc_ck);
    end
    at_end_edge = 1'b0;
  end
endtask

task fmc_read(input [11:0] adr, output [15:0] dat);
  real margin;
  begin
    begin_access;
    drive_a(adr);
    drive_cen(1'b0);
    repeat (ADDSET) @(posedge fmc_ck);
    drive_oen(1'b0);
    repeat (DATAST) @(posedge fmc_ck);
    dat = d_at_mcu;
    margin = $realtime - t_d_at_mcu - MCU_TSU;
    if (margin < min_rd_margin) min_rd_margin = margin;
    if (adr[11] == 1'b0 && margin < min_dpram_rd_margin) min_dpram_rd_margin = margin;
    if (margin < 0.0 || ^dat === 1'bx) begin
      n_rd_setup_viol = n_rd_setup_viol + 1;
      if (n_rd_setup_viol <= 10)
        $display("%t MCU read of 0x%03h: data changed %0.2f ns before the sample (value %h)",
                 $realtime, adr, $realtime - t_d_at_mcu, dat);
    end
    drive_oen(1'b1);
    if (NE_GAP > 0) drive_cen(1'b1);
    n_access = n_access + 1;
    at_end_edge = 1'b1;
  end
endtask

task fmc_write(input [11:0] adr, input [15:0] dat);
  begin
    begin_access;
    drive_a(adr);
    drive_cen(1'b0);
    repeat (ADDSET) @(posedge fmc_ck);
    drive_wen(1'b0);
    drive_d(dat);
    repeat (DATAST) @(posedge fmc_ck);
    drive_wen(1'b1);
    if (NE_GAP > 0) drive_cen(1'b1);
    n_access = n_access + 1;
    at_end_edge = 1'b1;
  end
endtask

// idle bus (NE high) for n fmc_ker_ck cycles
task fmc_idle(input integer n);
  begin
    if (n > 0) begin
      @(posedge fmc_ck);
      drive_cen(1'b1);
      repeat (n - 1) @(posedge fmc_ck);
      at_end_edge = 1'b0;
    end
  end
endtask

// ---------------------------------------------------------------------------
// register helpers (STM32Workspace mdom_fpga_hal.c)
localparam [11:0] R_DPRAM_SEL = 12'hdf9, R_PG_OPTYPE = 12'hbcb, R_PG_ADDR_LO = 12'hbcc,
                  R_PG_ADDR_HI = 12'hbcd, R_PG_TASK = 12'hbca, R_DDR3_RST = 12'hbc9,
                  R_DDR3_CAL = 12'hbc8, R_VNUM = 12'hfff, R_HBUF_START_PG = 12'hbc4;

integer n_polls = 0;
task ddr3_page_op(input integer page, input optype);
  reg [15:0] v;
  reg [31:0] addr;
  begin
    addr = page << 11;
    if (optype == 1'b0) fmc_write(R_DPRAM_SEL, 16'h0);
    fmc_write(R_PG_OPTYPE, {15'h0, optype});
    // 32-bit write of DDR3_PG_TRANSFER_ADDR: low half, then high half
    fmc_write(R_PG_ADDR_LO, addr[15:0]);
    fmc_write(R_PG_ADDR_HI, addr[31:16]);
    fmc_write(R_PG_TASK, 16'h1);
    v = 16'h1;
    while (v[0] !== 1'b0) begin
      fmc_read(R_PG_TASK, v);
      n_polls = n_polls + 1;
      fmc_idle(1 + (($random(seed) & 32'h7fffffff) % 3));
    end
  end
endtask

// 32-bit MDMA copy of the DPRAM (two FMC accesses per word, a pause after
// every 16-byte buffer)
reg [15:0] pg [0:2047];
task mdma_read_page;
  integer w;
  reg [15:0] lo, hi;
  begin
    for (w = 0; w < 2048; w = w + 2) begin
      fmc_read(w[11:0], lo);
      fmc_read(w[11:0] + 12'h1, hi);
      pg[w] = lo;
      pg[w + 1] = hi;
      if (w % 8 == 6) fmc_idle(2 + (($random(seed) & 32'h7fffffff) % 4));
    end
  end
endtask

reg [15:0] upg [0:2047];
task mdma_write_page;
  integer w;
  begin
    for (w = 0; w < 2048; w = w + 2) begin
      fmc_write(w[11:0], upg[w]);
      fmc_write(w[11:0] + 12'h1, upg[w + 1]);
      if (w % 8 == 6) fmc_idle(2 + (($random(seed) & 32'h7fffffff) % 4));
    end
  end
endtask

// ---------------------------------------------------------------------------
// page contents (hbuf_ctrl.v page format) and CRC (as hit_buffer.c)
function [15:0] crc16_word(input [15:0] crc, input [15:0] w);
  integer b;
  reg [15:0] c;
  reg fb;
  begin
    c = crc;
    for (b = 15; b >= 0; b = b - 1) begin
      fb = c[15] ^ w[b];
      c = {c[14:0], 1'b0};
      if (fb) c = c ^ 16'h8005;
    end
    crc16_word = c;
  end
endfunction

reg [15:0] truth [0:2047];
task make_hit_page(input integer page);
  integer w, k;
  reg [15:0] crc;
  reg [127:0] q;
  begin
    truth[0] = 16'ha000;
    truth[1] = 16'h5555;
    truth[2] = 16'haaaa;
    truth[3] = 16'h5555;
    crc = 16'hffff;
    for (w = 4; w < 2044; w = w + 1) begin
      truth[w] = $random(seed);
      crc = crc16_word(crc, truth[w]);
    end
    truth[2044] = 16'haaaa;
    truth[2045] = 16'h5555;
    truth[2046] = 16'd2040;
    truth[2047] = crc;
    for (k = 0; k < 256; k = k + 1) begin
      for (w = 0; w < 8; w = w + 1) q[16*w +: 16] = truth[8*k + w];
      DDR3_TRANSFER_0.MIG_7_SERIES.mem[page * 256 + k] = q;
    end
  end
endtask

task get_ddr3_page(input integer page);
  integer w, k;
  reg [127:0] q;
  for (k = 0; k < 256; k = k + 1) begin
    q = DDR3_TRANSFER_0.MIG_7_SERIES.mem[page * 256 + k];
    for (w = 0; w < 8; w = w + 1) truth[8*k + w] = q[16*w +: 16];
  end
endtask

// _verify_page(): 0 ok, 1 checksum, 2 version, 3 length, 4 sync
function integer verify_page(input dummy);
  integer w;
  reg [15:0] crc;
  begin
    if (pg[0] !== 16'ha000) verify_page = 2;
    else if (pg[2046] < 4 || pg[2046] > 2044) verify_page = 3;
    else if (pg[1] !== 16'h5555 || pg[2] !== 16'haaaa || pg[3] !== 16'h5555 ||
             pg[2044] !== 16'haaaa || pg[2045] !== 16'h5555) verify_page = 4;
    else begin
      crc = 16'hffff;
      for (w = 4; w < 2044; w = w + 1) crc = crc16_word(crc, pg[w]);
      verify_page = (crc === pg[2047]) ? 0 : 1;
    end
  end
endfunction

// ---------------------------------------------------------------------------
// attribute each PG_DPRAM address violation to the FMC pin that changed last
// before it (as seen by the FPGA logic)
realtime t_oen_chg = -1.0e9, t_cen_chg = -1.0e9, t_a_chg = -1.0e9;
always @(i_fmc_oen) t_oen_chg = $realtime;
always @(i_fmc_cen) t_cen_chg = $realtime;
always @(i_fmc_a) t_a_chg = $realtime;
integer n_cause [0:3];
initial for (j = 0; j < 4; j = j + 1) n_cause[j] = 0;
integer n_viol_seen = 0;
always @(XDOM_0.PG_DPRAM.n_setup_a or XDOM_0.PG_DPRAM.n_hold_a) begin
  if (XDOM_0.PG_DPRAM.n_setup_a + XDOM_0.PG_DPRAM.n_hold_a == n_viol_seen) begin
    // no new violation
  end else if (t_oen_chg >= t_cen_chg && t_oen_chg >= t_a_chg)
    n_cause[i_fmc_oen ? 1 : 0] = n_cause[i_fmc_oen ? 1 : 0] + 1;
  else if (t_cen_chg >= t_a_chg)
    n_cause[2] = n_cause[2] + 1;
  else
    n_cause[3] = n_cause[3] + 1;
  n_viol_seen = XDOM_0.PG_DPRAM.n_setup_a + XDOM_0.PG_DPRAM.n_hold_a;
end

// ---------------------------------------------------------------------------
// test sequence
integer n_reads = 0, n_errs_detected = 0, n_recovered = 0, n_fatal = 0;
integer n_undetected = 0, n_user_mismatch = 0, n_reg_mismatch = 0;
integer n_err_crc = 0, n_err_ver = 0, n_err_len = 0, n_err_sync = 0;
integer viol_poll = 0, viol_mdma = 0, viol_wr = 0, v0;
integer p, attempt, st, w, nbad;
reg [15:0] v;
reg ok;

function integer pg_viol(input dummy);
  pg_viol = XDOM_0.PG_DPRAM.n_setup_a + XDOM_0.PG_DPRAM.n_hold_a;
endfunction

initial begin
  $timeformat(-9, 3, " ns", 16);
  if ($test$plusargs("vcd")) begin
    $dumpfile("fmc_dpram_tb.vcd");
    $dumpvars(1, fmc_dpram_tb);
    $dumpvars(1, fmc_dpram_tb.XDOM_0.PG_DPRAM);
  end
  wait (!lclk_rst);
  repeat (20) @(posedge lclk);

  // release the DDR3 controller and wait for calibration
  fmc_write(R_DDR3_RST, 16'h1);
  v = 16'h0;
  while (v[0] !== 1'b1) begin
    fmc_idle(20);
    fmc_read(R_DDR3_CAL, v);
  end

  // control registers
  fmc_read(R_VNUM, v);
  if (v !== 16'h2f) begin
    n_reg_mismatch = n_reg_mismatch + 1;
    $display("%t VNUM read %h", $realtime, v);
  end
  for (p = 0; p < 4; p = p + 1) begin
    fmc_write(R_HBUF_START_PG, 16'h1234 ^ (p * 16'h1111));
    fmc_read(R_HBUF_START_PG, v);
    if (v !== (16'h1234 ^ (p * 16'h1111))) begin
      n_reg_mismatch = n_reg_mismatch + 1;
      $display("%t HBUF_START_PG read %h", $realtime, v);
    end
  end

  // hit pages
  for (p = 0; p < N_HIT_PAGES; p = p + 1) begin
    make_hit_page(p);
    ok = 1'b0;
    for (attempt = 0; attempt < 3 && !ok; attempt = attempt + 1) begin
      v0 = pg_viol(0);
      ddr3_page_op(p, 1'b0);
      viol_poll = viol_poll + pg_viol(0) - v0;
      v0 = pg_viol(0);
      mdma_read_page;
      viol_mdma = viol_mdma + pg_viol(0) - v0;
      n_reads = n_reads + 1;
      st = verify_page(0);
      nbad = 0;
      for (w = 0; w < 2048; w = w + 1)
        if (pg[w] !== truth[w]) begin
          nbad = nbad + 1;
          if (st != 0)
            $display("%t page %0d read %0d: word %0d read %h expected %h (xor %h)",
                     $realtime, p, attempt + 1, w, pg[w], truth[w], pg[w] ^ truth[w]);
        end
      if (st == 0) begin
        ok = 1'b1;
        if (attempt > 0) n_recovered = n_recovered + 1;
        if (nbad != 0) begin
          n_undetected = n_undetected + 1;
          $display("%t page %0d: %0d wrong word(s) passed the page checks", $realtime, p, nbad);
        end
      end else begin
        n_errs_detected = n_errs_detected + 1;
        case (st)
          1: n_err_crc = n_err_crc + 1;
          2: n_err_ver = n_err_ver + 1;
          3: n_err_len = n_err_len + 1;
          4: n_err_sync = n_err_sync + 1;
        endcase
        $display("%t page %0d read %0d: verify status %0d (1 crc, 2 version, 3 length, 4 sync), %0d word(s) wrong",
                 $realtime, p, attempt + 1, st, nbad);
      end
    end
    if (!ok) n_fatal = n_fatal + 1;
  end

  // user pages: write over the FMC, store, reload, compare
  for (p = 0; p < N_USER_PAGES; p = p + 1) begin
    for (w = 0; w < 2048; w = w + 1) upg[w] = $random(seed);
    v0 = pg_viol(0);
    fmc_write(R_DPRAM_SEL, 16'h0);
    mdma_write_page;
    ddr3_page_op(N_HIT_PAGES + p, 1'b1);
    viol_wr = viol_wr + pg_viol(0) - v0;
    get_ddr3_page(N_HIT_PAGES + p);
    for (w = 0; w < 2048; w = w + 1)
      if (truth[w] !== upg[w]) begin
        n_user_mismatch = n_user_mismatch + 1;
        if (n_user_mismatch <= 10)
          $display("%t user page %0d word %0d stored %h expected %h", $realtime, p, w, truth[w], upg[w]);
      end
    v0 = pg_viol(0);
    ddr3_page_op(N_HIT_PAGES + p, 1'b0);
    mdma_read_page;
    viol_wr = viol_wr + pg_viol(0) - v0;
    for (w = 0; w < 2048; w = w + 1)
      if (pg[w] !== upg[w]) begin
        n_user_mismatch = n_user_mismatch + 1;
        if (n_user_mismatch <= 10)
          $display("%t user page %0d word %0d read back %h expected %h", $realtime, p, w, pg[w], upg[w]);
      end
  end

  // summary
  $display("RESULT config: ADDSET=%0d DATAST=%0d NE_GAP=%0d SEED=%0d CORRUPT_PPM=%0d pin delays %0.1f..%0.1f ns",
           ADDSET, DATAST, NE_GAP, SEED, CORRUPT_PPM, PIN_DLY_MIN, PIN_DLY_MAX);
  $display("RESULT fmc: %0d accesses, %0d task polls, MCU read setup violations %0d, min read margin %0.2f ns (DPRAM reads %0.2f ns)",
           n_access, n_polls, n_rd_setup_viol, min_rd_margin, min_dpram_rd_margin);
  $display("RESULT pg_dpram_violation_causes: OEn falling %0d, OEn rising %0d, CEn change %0d, address change %0d",
           n_cause[0], n_cause[1], n_cause[2], n_cause[3]);
  $display("RESULT pg_dpram_addr_violations: port A setup %0d hold %0d (polling %0d, hit page copy %0d, user pages %0d; %0.1f per hit page read); port B %0d",
           XDOM_0.PG_DPRAM.n_setup_a, XDOM_0.PG_DPRAM.n_hold_a, viol_poll, viol_mdma, viol_wr,
           1.0 * (viol_poll + viol_mdma) / (n_reads > 0 ? n_reads : 1),
           XDOM_0.PG_DPRAM.n_setup_b + XDOM_0.PG_DPRAM.n_hold_b);
  $display("RESULT rdout_dpram_addr_violations: %0d", XDOM_0.RDOUT_DPRAM.n_setup_b + XDOM_0.RDOUT_DPRAM.n_hold_b);
  $display("RESULT corruption_model: %0d bit flips injected", XDOM_0.PG_DPRAM.n_corrupt);
  $display("RESULT hit_pages: %0d pages, %0d reads, %0d failed checks (crc %0d version %0d length %0d sync %0d), %0d recovered by reload, %0d fatal, %0d undetected",
           N_HIT_PAGES, n_reads, n_errs_detected, n_err_crc, n_err_ver, n_err_len, n_err_sync,
           n_recovered, n_fatal, n_undetected);
  $display("RESULT user_pages: %0d pages, %0d mismatched words; control register mismatches %0d",
           N_USER_PAGES, n_user_mismatch, n_reg_mismatch);
  if (n_undetected == 0 && n_fatal == 0 && n_user_mismatch == 0 && n_reg_mismatch == 0 &&
      n_rd_setup_viol == 0 && n_errs_detected == 0 &&
      (!EXPECT_NO_VIOLATIONS || (pg_viol(0) == 0 &&
                                 XDOM_0.RDOUT_DPRAM.n_setup_b + XDOM_0.RDOUT_DPRAM.n_hold_b == 0)))
    $display("RESULT PASS");
  else
    $display("RESULT FAIL");
  $finish;
end

endmodule
