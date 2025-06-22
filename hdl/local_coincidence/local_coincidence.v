/////////////////////////////////////////////////////////////////////////////////////
// T. Anderson Sat 05/21/2022_14:49:59.76
// Form a local coincidence condition, as per gitub WIPAC/gen2dom-fw Issue #16
//
// The positive edge of each trigger signal opens a coincidence window. The window
// of width lc_widow_width clock cycles.
/////////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module local_coincidence #(parameter N_CHANNELS=24)
   (
    input 		    clk,
    input 		    rst,
    input [15:0] 	    lc_window_width, // Width of coincidence window opened by each trigger input
    input [15:0] 	    n_lc_thr, // Threshold for required number of triggers in coincidence window
    input [N_CHANNELS-1:0]  trig, // Trigger components
    output [N_CHANNELS-1:0] local_coinc // These fire if the corresponding trigger is a component of the local coincidence
    );

   reg[N_CHANNELS-1:0] trig_prev = 0;
   always @(posedge clk) begin
      trig_prev <= trig;
   end
   wire[N_CHANNELS-1:0] trig_pe = trig & (~trig_prev);

   // Form the coincidence windows by extending the trig_pe signals
   wire [N_CHANNELS-1:0]    i_cw; // coincidence window
   genvar 		    i;
   generate
    for(i=0; i < N_CHANNELS; i=i+1) begin
      pulse_extender #(.P_N_WIDTH(16)) PULSE_EXTENDER_0
        (
          .clk(clk),
          .reset_n(!rst),
          .in(trig_pe[i]),
          .extend_len(lc_window_width),
          .out(i_cw[i])
        );
    end
   endgenerate

   // Make a sum to check for the coincidence
   integer    j;
   reg [15:0] coinc_level;
   always @(*)
     begin
        coinc_level = 0;
        for(j=0; j<N_CHANNELS; j=j+1)
          begin
             if(i_cw[j]==1'b1)
               coinc_level = coinc_level + 1;
          end
     end

   // Calculate the coincidence condition
   reg[N_CHANNELS-1:0] lc_out = 0;
   always @(posedge clk) begin
    lc_out <= coinc_level >= n_lc_thr ? i_cw : {N_CHANNELS{1'b0}};
   end

   assign local_coinc = lc_out;

endmodule
