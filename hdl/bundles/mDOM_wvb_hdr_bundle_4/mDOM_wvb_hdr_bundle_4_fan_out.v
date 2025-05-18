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

   input [101:0] bundle;
   output [48:0] evt_ltc;
   output [8:0] start_addr;
   output [8:0] stop_addr;
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
assign start_addr = bundle[57:49];
assign stop_addr = bundle[66:58];
assign trig_src = bundle[68:67];
assign cnst_run = bundle[69:69];
assign pre_conf = bundle[74:70];
assign sync_rdy = bundle[75:75];
assign bsum = bundle[94:76];
assign bsum_len_sel = bundle[97:95];
assign bsum_valid = bundle[98:98];
assign local_coinc = bundle[99:99];
assign partial_wfm = bundle[100:100];
assign continued_wfm = bundle[101:101];

endmodule
