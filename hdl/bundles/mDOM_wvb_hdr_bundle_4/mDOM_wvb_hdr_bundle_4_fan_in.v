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

   output [103:0] bundle;
   input [48:0] evt_ltc;
   input [9:0] start_addr;
   input [9:0] stop_addr;
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
assign bundle[58:49] = start_addr;
assign bundle[68:59] = stop_addr;
assign bundle[70:69] = trig_src;
assign bundle[71:71] = cnst_run;
assign bundle[76:72] = pre_conf;
assign bundle[77:77] = sync_rdy;
assign bundle[96:78] = bsum;
assign bundle[99:97] = bsum_len_sel;
assign bundle[100:100] = bsum_valid;
assign bundle[101:101] = local_coinc;
assign bundle[102:102] = partial_wfm;
assign bundle[103:103] = continued_wfm;


endmodule
