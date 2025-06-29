// Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2019.1 (win64) Build 2552052 Fri May 24 14:49:42 MDT 2019
// Date        : Sat May 24 15:44:03 2025
// Host        : i3DevBox running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               c:/Users/i3devmachine/mdom/updates/mdommb_rev1_fw/mDOM_mb_rev1.srcs/sources_1/ip/HBUF_DDR3_PG_DOUBLE_BUFFER/HBUF_DDR3_PG_DOUBLE_BUFFER_stub.v
// Design      : HBUF_DDR3_PG_DOUBLE_BUFFER
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7s100fgga676-2
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "blk_mem_gen_v8_4_3,Vivado 2019.1" *)
module HBUF_DDR3_PG_DOUBLE_BUFFER(clka, wea, addra, dina, clkb, addrb, doutb)
/* synthesis syn_black_box black_box_pad_pin="clka,wea[0:0],addra[9:0],dina[63:0],clkb,addrb[8:0],doutb[127:0]" */;
  input clka;
  input [0:0]wea;
  input [9:0]addra;
  input [63:0]dina;
  input clkb;
  input [8:0]addrb;
  output [127:0]doutb;
endmodule
