module mDOM_wvb_hdr_bundle_4_fan_in
  (
   bundle,
   evt_ltc,
   start_addr,
   stop_addr,
   trig_src,
   cnst_run,
   pre_conf,
   sync_rdy,
   bsum,
   bsum_len_sel,
   bsum_valid,
   local_coinc,
   partial_wfm,
   continued_wfm
  );

`include "mDOM_wvb_hdr_bundle_4_inc.v"

   output [101:0] bundle;
   input [48:0] evt_ltc;
   input [8:0] start_addr;
   input [8:0] stop_addr;
   input [1:0] trig_src;
   input [0:0] cnst_run;
   input [4:0] pre_conf;
   input [0:0] sync_rdy;
   input [18:0] bsum;
   input [2:0] bsum_len_sel;
   input [0:0] bsum_valid;
   input [0:0] local_coinc;
   input [0:0] partial_wfm;
   input [0:0] continued_wfm;

assign bundle[48:0] = evt_ltc;
assign bundle[57:49] = start_addr;
assign bundle[66:58] = stop_addr;
assign bundle[68:67] = trig_src;
assign bundle[69:69] = cnst_run;
assign bundle[74:70] = pre_conf;
assign bundle[75:75] = sync_rdy;
assign bundle[94:76] = bsum;
assign bundle[97:95] = bsum_len_sel;
assign bundle[98:98] = bsum_valid;
assign bundle[99:99] = local_coinc;
assign bundle[100:100] = partial_wfm;
assign bundle[101:101] = continued_wfm;


endmodule
