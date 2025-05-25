-- Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2019.1 (win64) Build 2552052 Fri May 24 14:49:42 MDT 2019
-- Date        : Fri Apr 18 12:25:23 2025
-- Host        : i3DevBox running 64-bit major release  (build 9200)
-- Command     : write_vhdl -force -mode synth_stub -rename_top MDOM_CHANNEL_HDR_FIFO -prefix
--               MDOM_CHANNEL_HDR_FIFO_ BUILT_IN_FIFO_512_108_stub.vhdl
-- Design      : BUILT_IN_FIFO_512_108
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7s100fgga676-2
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity MDOM_CHANNEL_HDR_FIFO is
  Port ( 
    clk : in STD_LOGIC;
    srst : in STD_LOGIC;
    din : in STD_LOGIC_VECTOR ( 107 downto 0 );
    wr_en : in STD_LOGIC;
    rd_en : in STD_LOGIC;
    dout : out STD_LOGIC_VECTOR ( 107 downto 0 );
    full : out STD_LOGIC;
    empty : out STD_LOGIC;
    data_count : out STD_LOGIC_VECTOR ( 6 downto 0 )
  );

end MDOM_CHANNEL_HDR_FIFO;

architecture stub of MDOM_CHANNEL_HDR_FIFO is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "clk,srst,din[107:0],wr_en,rd_en,dout[107:0],full,empty,data_count[6:0]";
attribute x_core_info : string;
attribute x_core_info of stub : architecture is "fifo_generator_v13_2_4,Vivado 2019.1";
begin
end;
