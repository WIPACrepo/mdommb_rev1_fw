module mDOM_scdb_hdr_bundle_fan_in
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
   continued_wfm,
   channel_idx
  );

`include "mDOM_scdb_hdr_bundle_inc.v"

   output [110:0] bundle;
   input [48:0] evt_ltc;
   input [10:0] start_addr;
   input [10:0] stop_addr;
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
   input [4:0] channel_idx;

assign bundle[48:0] = evt_ltc;
assign bundle[59:49] = start_addr;
assign bundle[70:60] = stop_addr;
assign bundle[72:71] = trig_src;
assign bundle[73:73] = cnst_run;
assign bundle[78:74] = pre_conf;
assign bundle[79:79] = sync_rdy;
assign bundle[98:80] = bsum;
assign bundle[101:99] = bsum_len_sel;
assign bundle[102:102] = bsum_valid;
assign bundle[103:103] = local_coinc;
assign bundle[104:104] = partial_wfm;
assign bundle[105:105] = continued_wfm;
assign bundle[110:106] = channel_idx;


endmodule
