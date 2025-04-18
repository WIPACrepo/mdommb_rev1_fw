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
   local_coinc
  );

`include "mDOM_wvb_hdr_bundle_4_inc.v"

   output [105:0] bundle;
   input [48:0] evt_ltc;
   input [11:0] start_addr;
   input [11:0] stop_addr;
   input [1:0] trig_src;
   input [0:0] cnst_run;
   input [4:0] pre_conf;
   input [0:0] sync_rdy;
   input [18:0] bsum;
   input [2:0] bsum_len_sel;
   input [0:0] bsum_valid;
   input [0:0] local_coinc;

assign bundle[48:0] = evt_ltc;
assign bundle[60:49] = start_addr;
assign bundle[72:61] = stop_addr;
assign bundle[74:73] = trig_src;
assign bundle[75:75] = cnst_run;
assign bundle[80:76] = pre_conf;
assign bundle[81:81] = sync_rdy;
assign bundle[100:82] = bsum;
assign bundle[103:101] = bsum_len_sel;
assign bundle[104:104] = bsum_valid;
assign bundle[105:105] = local_coinc;


endmodule
