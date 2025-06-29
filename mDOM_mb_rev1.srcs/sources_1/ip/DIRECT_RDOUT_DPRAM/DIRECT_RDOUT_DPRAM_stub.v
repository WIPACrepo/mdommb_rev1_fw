// Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2019.1 (win64) Build 2552052 Fri May 24 14:49:42 MDT 2019
// Date        : Sat May 10 14:02:19 2025
// Host        : i3DevBox running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               C:/Users/i3devmachine/mdom/updates/mdommb_rev1_fw/mDOM_mb_rev1.srcs/sources_1/ip/DIRECT_RDOUT_DPRAM/DIRECT_RDOUT_DPRAM_stub.v
// Design      : DIRECT_RDOUT_DPRAM
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7s100fgga676-2
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "blk_mem_gen_v8_4_3,Vivado 2019.1" *)
module DIRECT_RDOUT_DPRAM(clka, wea, addra, dina, clkb, addrb, doutb)
/* synthesis syn_black_box black_box_pad_pin="clka,wea[0:0],addra[7:0],dina[127:0],clkb,addrb[10:0],doutb[15:0]" */;
  input clka;
  input [0:0]wea;
  input [7:0]addra;
  input [127:0]dina;
  input clkb;
  input [10:0]addrb;
  output [15:0]doutb;
endmodule
