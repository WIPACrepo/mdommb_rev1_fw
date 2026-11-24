// Simulation models for fmc_dpram_tb.v (mdommb_rev1_fw issue #4)
//
// Behavioral stand-ins for the IP that xdom.v and DDR3_DPRAM_transfer.v
// instantiate, so that the real xdom, crs_master and DDR3 page transfer RTL
// can be simulated without the Xilinx libraries:
//
//   XDOM_DDR3_PG         xdom DDR3 page DPRAM (2048x16 port A on lclk,
//                        256x128 port B on the DDR3 UI clock).  Both ports
//                        always enabled, WRITE_FIRST, primitive output
//                        registers (two-cycle reads), as in the IP (.xci).
//   DIRECT_RDOUT_DPRAM   direct readout DPRAM (256x128 write, 2048x16 read
//                        with output register)
//   mig_7series_0        MIG native UI: random app_rdy/app_wdf_rdy
//                        back-pressure, refresh-like stalls, random read
//                        latency, in-order read data, page memory
//   ft232r_proc_buffered the unused UARTs (held in reset in xdom)
//
// Both DPRAM models check every address change against their clock and count
// setup and hold violations: a change within TSU before or TH after a rising
// edge.  A change in the same time step as the edge (a register updating on
// that edge) is synchronous and is not counted.  The Spartan-7 data sheet
// (DS189, block RAM switching characteristics, note 7) says that the ADDR
// setup and hold times must be met whenever EN is asserted, even when WE is
// deasserted, or block RAM data corruption is possible.  The real effect of a
// violation on the stored data is not specified, so XDOM_DDR3_PG can model it
// as a single-bit flip, with probability CORRUPT_PPM per million violations,
// in the word addressed just before or just after the offending change.
// CORRUPT_PPM = 0 only counts the violations.

`timescale 1ns/1fs

module XDOM_DDR3_PG
(
  input clka,
  input [0:0] wea,
  input [10:0] addra,
  input [15:0] dina,
  output reg [15:0] douta = 16'h0,
  input clkb,
  input [0:0] web,
  input [7:0] addrb,
  input [127:0] dinb,
  output reg [127:0] doutb = 128'h0
);

parameter real TSU = 0.45;        // ns, ADDR setup to clock (DS189 order of magnitude)
parameter real TH = 0.35;         // ns, ADDR hold after clock
parameter integer CORRUPT_PPM = 0;
parameter integer SEED = 1;
parameter integer VERBOSE = 0;

reg [15:0] mem [0:2047];
integer i;
initial for (i = 0; i < 2048; i = i + 1) mem[i] = 16'h0;

// port A: WRITE_FIRST, output register
reg [15:0] a_q = 16'h0;
always @(posedge clka) begin
  if (wea[0]) begin
    mem[addra] <= dina;
    a_q <= dina;
  end else begin
    a_q <= mem[addra];
  end
  douta <= a_q;
end

// port B: WRITE_FIRST, output register
reg [127:0] b_q = 128'h0;
integer k;
always @(posedge clkb) begin
  if (web[0]) begin
    for (k = 0; k < 8; k = k + 1) mem[{addrb, k[2:0]}] <= dinb[16*k +: 16];
    b_q <= dinb;
  end else begin
    for (k = 0; k < 8; k = k + 1) b_q[16*k +: 16] <= mem[{addrb, k[2:0]}];
  end
  doutb <= b_q;
end

// ---------------------------------------------------------------------------
// address timing checks (port A is the FMC side; port B is synchronous)
integer n_setup_a = 0, n_hold_a = 0, n_setup_b = 0, n_hold_b = 0;
integer n_corrupt = 0;
integer seed = SEED;
realtime t_edge_a = -1.0e9, t_chg_a = -1.0e9;
realtime t_edge_b = -1.0e9, t_chg_b = -1.0e9;
reg [10:0] a_prev = 11'h0, a_before_chg = 11'h0, a_at_edge = 11'h0;
reg [7:0] b_prev = 8'h0;

task corrupt(input [10:0] a0, input [10:0] a1, input [127:0] why, input real dt);
  reg [10:0] a;
  integer b, r;
  begin
    if (VERBOSE && n_setup_a + n_hold_a <= 20)
      $display("%t XDOM_DDR3_PG: port A address %0s violation: addra 0x%03h -> 0x%03h %0.3f ns %0s the clka edge",
               $realtime, why, a0, a1, dt, (why == "setup") ? "before" : "after");
    r = $random(seed);
    if (CORRUPT_PPM > 0 && ((r & 32'h7fffffff) % 1000000) < CORRUPT_PPM) begin
      r = $random(seed);
      a = r[0] ? a1 : a0;
      b = (($random(seed)) & 32'h7fffffff) % 16;
      mem[a] = mem[a] ^ (16'h1 << b);
      n_corrupt = n_corrupt + 1;
      if (VERBOSE)
        $display("%t XDOM_DDR3_PG: corruption model flipped word %0d bit %0d", $realtime, a, b);
    end
  end
endtask

always @(posedge clka) begin
  t_edge_a = $realtime;
  a_at_edge = addra;
  if (t_chg_a < t_edge_a && t_chg_a > t_edge_a - TSU) begin
    n_setup_a = n_setup_a + 1;
    corrupt(a_before_chg, addra, "setup", t_edge_a - t_chg_a);
  end
end

always @(addra) begin
  if ($realtime > t_edge_a && $realtime < t_edge_a + TH) begin
    n_hold_a = n_hold_a + 1;
    corrupt(a_at_edge, addra, "hold", $realtime - t_edge_a);
  end
  if ($realtime != t_edge_a) begin
    // asynchronous (not clocked) change
    t_chg_a = $realtime;
    a_before_chg = a_prev;
  end
  a_prev = addra;
end

always @(posedge clkb) begin
  t_edge_b = $realtime;
  if (t_chg_b < t_edge_b && t_chg_b > t_edge_b - TSU) n_setup_b = n_setup_b + 1;
end
always @(addrb) begin
  if ($realtime > t_edge_b && $realtime < t_edge_b + TH) n_hold_b = n_hold_b + 1;
  if ($realtime != t_edge_b) t_chg_b = $realtime;
  b_prev = addrb;
end

endmodule


module DIRECT_RDOUT_DPRAM
(
  input clka,
  input [0:0] wea,
  input [7:0] addra,
  input [127:0] dina,
  input clkb,
  input [10:0] addrb,
  output reg [15:0] doutb = 16'h0
);

parameter real TSU = 0.45;
parameter real TH = 0.35;

reg [15:0] mem [0:2047];
integer i, k;
initial for (i = 0; i < 2048; i = i + 1) mem[i] = 16'h0;

always @(posedge clka)
  if (wea[0])
    for (k = 0; k < 8; k = k + 1) mem[{addra, k[2:0]}] <= dina[16*k +: 16];

reg [15:0] b_q = 16'h0;
always @(posedge clkb) begin
  b_q <= mem[addrb];
  doutb <= b_q;
end

integer n_setup_b = 0, n_hold_b = 0;
realtime t_edge_b = -1.0e9, t_chg_b = -1.0e9;
always @(posedge clkb) begin
  t_edge_b = $realtime;
  if (t_chg_b < t_edge_b && t_chg_b > t_edge_b - TSU) n_setup_b = n_setup_b + 1;
end
always @(addrb) begin
  if ($realtime > t_edge_b && $realtime < t_edge_b + TH) n_hold_b = n_hold_b + 1;
  if ($realtime != t_edge_b) t_chg_b = $realtime;
end

endmodule


// MIG 7-series native user interface model (no DDR3 pins are driven)
module mig_7series_0
(
  input sys_rst,
  output [13:0] ddr3_addr,
  output [2:0] ddr3_ba,
  output ddr3_cas_n,
  output [0:0] ddr3_ck_n,
  output [0:0] ddr3_ck_p,
  output [0:0] ddr3_cke,
  output ddr3_ras_n,
  output ddr3_we_n,
  inout [15:0] ddr3_dq,
  inout [1:0] ddr3_dqs_n,
  inout [1:0] ddr3_dqs_p,
  output ddr3_reset_n,
  output [0:0] ddr3_cs_n,
  output [1:0] ddr3_dm,
  output [0:0] ddr3_odt,
  output reg init_calib_complete = 1'b0,
  output [11:0] device_temp,
  input [27:0] app_addr,
  input [2:0] app_cmd,
  input app_en,
  input [127:0] app_wdf_data,
  input app_wdf_end,
  input app_wdf_wren,
  output reg [127:0] app_rd_data = 128'h0,
  output app_rd_data_end,
  output reg app_rd_data_valid = 1'b0,
  output reg app_rdy = 1'b0,
  output reg app_wdf_rdy = 1'b0,
  input app_sr_req,
  input app_ref_req,
  input app_zq_req,
  output app_sr_active,
  output app_ref_ack,
  output app_zq_ack,
  input [15:0] app_wdf_mask,
  output reg ui_clk = 1'b0,
  output reg ui_clk_sync_rst = 1'b1,
  input sys_clk_i,
  input clk_ref_i
);

parameter real T_UI = 12.307692;   // 81.25 MHz
parameter integer N_BURSTS = 8192; // 32 pages of 256 x 128 bits
parameter integer RDY_PCT = 80;
parameter integer SEED = 7;

assign ddr3_addr = 14'h0;
assign ddr3_ba = 3'h0;
assign ddr3_cas_n = 1'b1;
assign ddr3_ck_n = 1'b1;
assign ddr3_ck_p = 1'b0;
assign ddr3_cke = 1'b0;
assign ddr3_ras_n = 1'b1;
assign ddr3_we_n = 1'b1;
assign ddr3_reset_n = 1'b0;
assign ddr3_cs_n = 1'b1;
assign ddr3_dm = 2'b0;
assign ddr3_odt = 1'b0;
assign device_temp = 12'd2000;
assign app_rd_data_end = app_rd_data_valid;
assign app_sr_active = 1'b0;
assign app_ref_ack = 1'b0;
assign app_zq_ack = 1'b0;

initial #(3.1) forever #(T_UI / 2) ui_clk = !ui_clk;

reg [127:0] mem [0:N_BURSTS-1];
integer seed = SEED;
integer cyc = 0;

// reset and calibration
integer rst_cnt = 0;
always @(posedge ui_clk) begin
  if (!sys_rst) begin
    rst_cnt <= 0;
    ui_clk_sync_rst <= 1'b1;
    init_calib_complete <= 1'b0;
  end else begin
    if (rst_cnt < 400) rst_cnt <= rst_cnt + 1;
    ui_clk_sync_rst <= rst_cnt < 20;
    init_calib_complete <= rst_cnt >= 300;
  end
end

// command, write data and read return queues
reg [27:0] rq_addr [0:255];
integer rq_time [0:255];
integer rq_wr = 0, rq_rd = 0;
reg [27:0] wc_addr [0:255];
integer wc_wr = 0, wc_rd = 0;
reg [127:0] wd_data [0:255];
integer wd_wr = 0, wd_rd = 0;
integer stall = 0;

function integer burst(input [27:0] a);
  burst = (a >> 3) % N_BURSTS;
endfunction

always @(posedge ui_clk) begin
  cyc = cyc + 1;
  if (ui_clk_sync_rst || !init_calib_complete) begin
    app_rdy <= 1'b0;
    app_wdf_rdy <= 1'b0;
    app_rd_data_valid <= 1'b0;
  end else begin
    // accept on the values the controller saw at this edge
    if (app_en && app_rdy) begin
      if (app_cmd == 3'd1) begin
        rq_addr[rq_wr % 256] = app_addr;
        rq_time[rq_wr % 256] = cyc + 10 + (($random(seed) & 32'h7fffffff) % 20);
        rq_wr = rq_wr + 1;
      end else if (app_cmd == 3'd0) begin
        wc_addr[wc_wr % 256] = app_addr;
        wc_wr = wc_wr + 1;
      end
    end
    if (app_wdf_wren && app_wdf_rdy) begin
      wd_data[wd_wr % 256] = app_wdf_data;
      wd_wr = wd_wr + 1;
    end
    while (wc_rd < wc_wr && wd_rd < wd_wr) begin
      mem[burst(wc_addr[wc_rd % 256])] = wd_data[wd_rd % 256];
      wc_rd = wc_rd + 1;
      wd_rd = wd_rd + 1;
    end

    // back-pressure, with occasional refresh-like stalls
    if (stall > 0) stall = stall - 1;
    else if ((($random(seed) & 32'h7fffffff) % 1000) < 5) stall = 10 + (($random(seed) & 32'h7fffffff) % 30);
    app_rdy <= (stall == 0) && ((($random(seed) & 32'h7fffffff) % 100) < RDY_PCT) && (rq_wr - rq_rd < 32);
    app_wdf_rdy <= (($random(seed) & 32'h7fffffff) % 100) < RDY_PCT;

    // in-order read return with random gaps
    if (rq_rd < rq_wr && rq_time[rq_rd % 256] <= cyc && (($random(seed) & 32'h7fffffff) % 100) < 90) begin
      app_rd_data <= mem[burst(rq_addr[rq_rd % 256])];
      app_rd_data_valid <= 1'b1;
      rq_rd = rq_rd + 1;
    end else begin
      app_rd_data_valid <= 1'b0;
    end
  end
end

endmodule


// The xdom UARTs are held in reset; tie their outputs off.
module ft232r_proc_buffered
(
  input clk,
  input rst,
  input txd,
  output rxd,
  input rts_n,
  output cts_n,
  output [11:0] logic_adr,
  output [15:0] logic_wr_data,
  output logic_wr_req,
  output logic_rd_req,
  input [15:0] logic_rd_data,
  input logic_ack,
  output err_req,
  output [31:0] err_data,
  input err_ack
);
assign rxd = 1'b1;
assign cts_n = 1'b1;
assign logic_adr = 12'h0;
assign logic_wr_data = 16'h0;
assign logic_wr_req = 1'b0;
assign logic_rd_req = 1'b0;
assign err_req = 1'b0;
assign err_data = 32'h0;
endmodule
