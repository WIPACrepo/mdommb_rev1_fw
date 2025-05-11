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
   local_coinc,
   partial_wfm,
   continued_wfm
  );

`include "mDOM_wvb_hdr_bundle_4_inc.v"

   input [103:0] bundle;
   output [48:0] evt_ltc;
   output [9:0] start_addr;
   output [9:0] stop_addr;
   output [1:0] trig_src;
   output [0:0] cnst_run;
   output [4:0] pre_conf;
   output [0:0] sync_rdy;
   output [18:0] bsum;
   output [2:0] bsum_len_sel;
   output [0:0] bsum_valid;
   output [0:0] local_coinc;
   output [0:0] partial_wfm;
   output [0:0] continued_wfm;

assign evt_ltc = bundle[48:0];
assign start_addr = bundle[58:49];
assign stop_addr = bundle[68:59];
assign trig_src = bundle[70:69];
assign cnst_run = bundle[71:71];
assign pre_conf = bundle[76:72];
assign sync_rdy = bundle[77:77];
assign bsum = bundle[96:78];
assign bsum_len_sel = bundle[99:97];
assign bsum_valid = bundle[100:100];
assign local_coinc = bundle[101:101];
assign partial_wfm = bundle[102:102];
assign continued_wfm = bundle[103:103];

endmodule
