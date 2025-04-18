module mDOM_wvb_hdr_bundle_4_fan_out
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

   input [105:0] bundle;
   output [48:0] evt_ltc;
   output [11:0] start_addr;
   output [11:0] stop_addr;
   output [1:0] trig_src;
   output [0:0] cnst_run;
   output [4:0] pre_conf;
   output [0:0] sync_rdy;
   output [18:0] bsum;
   output [2:0] bsum_len_sel;
   output [0:0] bsum_valid;
   output [0:0] local_coinc;

assign evt_ltc = bundle[48:0];
assign start_addr = bundle[60:49];
assign stop_addr = bundle[72:61];
assign trig_src = bundle[74:73];
assign cnst_run = bundle[75:75];
assign pre_conf = bundle[80:76];
assign sync_rdy = bundle[81:81];
assign bsum = bundle[100:82];
assign bsum_len_sel = bundle[103:101];
assign bsum_valid = bundle[104:104];
assign local_coinc = bundle[105:105];

endmodule
