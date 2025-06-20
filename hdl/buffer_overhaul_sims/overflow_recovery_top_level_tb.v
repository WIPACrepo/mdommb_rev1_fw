//
// Top level mDOM sim exercising the automated overflow recovery logging
//
// 
// Note that ddr3_cal_complete is not asserted until ~130 microseconds,
// before this, the primary waveform buffers will overflow
//
// After data starts moving into the hit buffer, the channel buffers will clear 
// and the overflow recoveries will occur. We then read the overflow data out of x dom
//
// Run this for 600 usec to see the full process of all 24 channels entering overflow, recovering,
// and the overflow timestamps being read out of xdom

`timescale 1ps/1ps

//////////////////////////////////////////////////////////////////////////////////
// Test cases
//////////////////////////////////////////////////////////////////////////////////

module overflow_recovery_top_level_tb;

   localparam N_CHANNELS = 24;

   //////////////////////////////////////////////////////////////////////
   // I/O
   //////////////////////////////////////////////////////////////////////
   parameter CLK_PERIOD = 50000;
   reg clk;
   reg rst;

   // Connections
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire			ADC0_CLOCK_M;		// From UUT_0 of top.v
   wire			ADC0_CLOCK_P;		// From UUT_0 of top.v
   wire			ADC0_SEN;		// From UUT_0 of top.v
   wire			ADC0_SYSRF_M;		// From UUT_0 of top.v
   wire			ADC0_SYSRF_P;		// From UUT_0 of top.v
   wire			ADC1_CLOCK_M;		// From UUT_0 of top.v
   wire			ADC1_CLOCK_P;		// From UUT_0 of top.v
   wire			ADC1_SEN;		// From UUT_0 of top.v
   wire			ADC1_SYSRF_M;		// From UUT_0 of top.v
   wire			ADC1_SYSRF_P;		// From UUT_0 of top.v
   wire			ADC2_CLOCK_M;		// From UUT_0 of top.v
   wire			ADC2_CLOCK_P;		// From UUT_0 of top.v
   wire			ADC2_SEN;		// From UUT_0 of top.v
   wire			ADC2_SYSRF_M;		// From UUT_0 of top.v
   wire			ADC2_SYSRF_P;		// From UUT_0 of top.v
   wire			ADC3_CLOCK_M;		// From UUT_0 of top.v
   wire			ADC3_CLOCK_P;		// From UUT_0 of top.v
   wire			ADC3_SEN;		// From UUT_0 of top.v
   wire			ADC3_SYSRF_M;		// From UUT_0 of top.v
   wire			ADC3_SYSRF_P;		// From UUT_0 of top.v
   wire			ADC4_CLOCK_M;		// From UUT_0 of top.v
   wire			ADC4_CLOCK_P;		// From UUT_0 of top.v
   wire			ADC4_SEN;		// From UUT_0 of top.v
   wire			ADC4_SYSRF_M;		// From UUT_0 of top.v
   wire			ADC4_SYSRF_P;		// From UUT_0 of top.v
   wire			ADC5_CLOCK_M;		// From UUT_0 of top.v
   wire			ADC5_CLOCK_P;		// From UUT_0 of top.v
   wire			ADC5_SEN;		// From UUT_0 of top.v
   wire			ADC5_SYSRF_M;		// From UUT_0 of top.v
   wire			ADC5_SYSRF_P;		// From UUT_0 of top.v
   wire			ADC_RESET;		// From UUT_0 of top.v
   wire			ADC_SCLK;		// From UUT_0 of top.v
   wire			ADC_SDATA;		// From UUT_0 of top.v
   wire			AFE0_TPR;		// From UUT_0 of top.v
   wire			AFE1_TPR;		// From UUT_0 of top.v
   wire			AFE2_TPR;		// From UUT_0 of top.v
   wire			AFE3_TPR;		// From UUT_0 of top.v
   wire			AFE4_TPR;		// From UUT_0 of top.v
   wire			AFE5_TPR;		// From UUT_0 of top.v
   wire			DAC0_DIN;		// From UUT_0 of top.v
   wire			DAC0_SCLK;		// From UUT_0 of top.v
   wire			DAC0_nSYNC0;		// From UUT_0 of top.v
   wire			DAC0_nSYNC1;		// From UUT_0 of top.v
   wire			DAC0_nSYNC2;		// From UUT_0 of top.v
   wire			DAC1_DIN;		// From UUT_0 of top.v
   wire			DAC1_SCLK;		// From UUT_0 of top.v
   wire			DAC1_nSYNC0;		// From UUT_0 of top.v
   wire			DAC1_nSYNC1;		// From UUT_0 of top.v
   wire			DAC1_nSYNC2;		// From UUT_0 of top.v
   wire			DAC2_DIN;		// From UUT_0 of top.v
   wire			DAC2_SCLK;		// From UUT_0 of top.v
   wire			DAC2_nSYNC0;		// From UUT_0 of top.v
   wire			DAC2_nSYNC1;		// From UUT_0 of top.v
   wire			DAC2_nSYNC2;		// From UUT_0 of top.v
   wire			DCDC_SYNC;		// From UUT_0 of top.v
   wire			DDR3_CLK100_OUT;	// From UUT_0 of top.v
   wire			DDR3_VTT_S3;		// From UUT_0 of top.v
   wire			DDR3_VTT_S5;		// From UUT_0 of top.v
   wire			FMC_IRQ0;		// From UUT_0 of top.v
   wire			FMC_IRQ1;		// From UUT_0 of top.v
   wire			FMC_IRQ2;		// From UUT_0 of top.v
   wire			FMC_IRQ3;		// From UUT_0 of top.v
   wire			FPGA_CAL_TRIG_N;	// From UUT_0 of top.v, ...
   wire			FPGA_CAL_TRIG_P;	// From UUT_0 of top.v, ...
   wire			FPGA_I2C_SCL;		// From UUT_0 of top.v
   wire			FPGA_I2C_SDA;		// To/From UUT_0 of top.v
   wire			FPGA_UART_RTS;		// From UUT_0 of top.v
   wire			FPGA_UART_TX;		// From UUT_0 of top.v
   wire			FTD_UART_CTSn;		// From UUT_0 of top.v
   wire			FTD_UART_RXD;		// From UUT_0 of top.v
   wire			LED_GREEN;		// From UUT_0 of top.v
   wire			LED_ORANGE;		// From UUT_0 of top.v
   wire			LED_YELLOW;		// From UUT_0 of top.v
   wire			MON_ADC1_CONVn;		// From UUT_0 of top.v
   wire			MON_ADC1_CSn;		// From UUT_0 of top.v
   wire			MON_ADC1_SCLK;		// From UUT_0 of top.v
   wire			MON_ADC1_SDI;		// From UUT_0 of top.v
   wire			MON_ADC2_CONVn;		// From UUT_0 of top.v
   wire			MON_ADC2_CSn;		// From UUT_0 of top.v
   wire			MON_ADC2_SCLK;		// From UUT_0 of top.v
   wire			MON_ADC2_SDI;		// From UUT_0 of top.v
   wire			TRIG_OUT;		// From UUT_0 of top.v
   wire [13:0]		ddr3_addr;		// From UUT_0 of top.v
   wire [2:0]		ddr3_ba;		// From UUT_0 of top.v
   wire			ddr3_cas_n;		// From UUT_0 of top.v
   wire [0:0]		ddr3_ck_n;		// From UUT_0 of top.v
   wire [0:0]		ddr3_ck_p;		// From UUT_0 of top.v
   wire [0:0]		ddr3_cke;		// From UUT_0 of top.v
   wire [0:0]		ddr3_cs_n;		// From UUT_0 of top.v
   wire [1:0]		ddr3_dm;		// From UUT_0 of top.v
   wire [15:0]		ddr3_dq;		// To/From UUT_0 of top.v
   wire [1:0]		ddr3_dqs_n;		// To/From UUT_0 of top.v
   wire [1:0]		ddr3_dqs_p;		// To/From UUT_0 of top.v
   wire [0:0]		ddr3_odt;		// From UUT_0 of top.v
   wire			ddr3_ras_n;		// From UUT_0 of top.v
   wire			ddr3_reset_n;		// From UUT_0 of top.v
   wire			ddr3_we_n;		// From UUT_0 of top.v

   // End of automatics
   /*AUTOREGINPUT*/
   // Beginning of automatic reg inputs (for undeclared instantiated-module inputs)
   reg			ADC0_DA0M;		// To UUT_0 of top.v
   reg			ADC0_DA0P;		// To UUT_0 of top.v
   reg			ADC0_DA1M;		// To UUT_0 of top.v
   reg			ADC0_DA1P;		// To UUT_0 of top.v
   reg			ADC0_DB0M;		// To UUT_0 of top.v
   reg			ADC0_DB0P;		// To UUT_0 of top.v
   reg			ADC0_DB1M;		// To UUT_0 of top.v
   reg			ADC0_DB1P;		// To UUT_0 of top.v
   reg			ADC0_DC0M;		// To UUT_0 of top.v
   reg			ADC0_DC0P;		// To UUT_0 of top.v
   reg			ADC0_DC1M;		// To UUT_0 of top.v
   reg			ADC0_DC1P;		// To UUT_0 of top.v
   reg			ADC0_DCLK_M;		// To UUT_0 of top.v
   reg			ADC0_DCLK_P;		// To UUT_0 of top.v
   reg			ADC0_DD0M;		// To UUT_0 of top.v
   reg			ADC0_DD0P;		// To UUT_0 of top.v
   reg			ADC0_DD1M;		// To UUT_0 of top.v
   reg			ADC0_DD1P;		// To UUT_0 of top.v
   reg			ADC0_FCLK_M;		// To UUT_0 of top.v
   reg			ADC0_FCLK_P;		// To UUT_0 of top.v
   reg			ADC0_SDOUT;		// To UUT_0 of top.v
   reg			ADC1_DA0M;		// To UUT_0 of top.v
   reg			ADC1_DA0P;		// To UUT_0 of top.v
   reg			ADC1_DA1M;		// To UUT_0 of top.v
   reg			ADC1_DA1P;		// To UUT_0 of top.v
   reg			ADC1_DB0M;		// To UUT_0 of top.v
   reg			ADC1_DB0P;		// To UUT_0 of top.v
   reg			ADC1_DB1M;		// To UUT_0 of top.v
   reg			ADC1_DB1P;		// To UUT_0 of top.v
   reg			ADC1_DC0M;		// To UUT_0 of top.v
   reg			ADC1_DC0P;		// To UUT_0 of top.v
   reg			ADC1_DC1M;		// To UUT_0 of top.v
   reg			ADC1_DC1P;		// To UUT_0 of top.v
   reg			ADC1_DCLK_M;		// To UUT_0 of top.v
   reg			ADC1_DCLK_P;		// To UUT_0 of top.v
   reg			ADC1_DD0M;		// To UUT_0 of top.v
   reg			ADC1_DD0P;		// To UUT_0 of top.v
   reg			ADC1_DD1M;		// To UUT_0 of top.v
   reg			ADC1_DD1P;		// To UUT_0 of top.v
   reg			ADC1_FCLK_M;		// To UUT_0 of top.v
   reg			ADC1_FCLK_P;		// To UUT_0 of top.v
   reg			ADC2_DA0M;		// To UUT_0 of top.v
   reg			ADC2_DA0P;		// To UUT_0 of top.v
   reg			ADC2_DA1M;		// To UUT_0 of top.v
   reg			ADC2_DA1P;		// To UUT_0 of top.v
   reg			ADC2_DB0M;		// To UUT_0 of top.v
   reg			ADC2_DB0P;		// To UUT_0 of top.v
   reg			ADC2_DB1M;		// To UUT_0 of top.v
   reg			ADC2_DB1P;		// To UUT_0 of top.v
   reg			ADC2_DC0M;		// To UUT_0 of top.v
   reg			ADC2_DC0P;		// To UUT_0 of top.v
   reg			ADC2_DC1M;		// To UUT_0 of top.v
   reg			ADC2_DC1P;		// To UUT_0 of top.v
   reg			ADC2_DCLK_M;		// To UUT_0 of top.v
   reg			ADC2_DCLK_P;		// To UUT_0 of top.v
   reg			ADC2_DD0M;		// To UUT_0 of top.v
   reg			ADC2_DD0P;		// To UUT_0 of top.v
   reg			ADC2_DD1M;		// To UUT_0 of top.v
   reg			ADC2_DD1P;		// To UUT_0 of top.v
   reg			ADC2_FCLK_M;		// To UUT_0 of top.v
   reg			ADC2_FCLK_P;		// To UUT_0 of top.v
   reg			ADC3_DA0M;		// To UUT_0 of top.v
   reg			ADC3_DA0P;		// To UUT_0 of top.v
   reg			ADC3_DA1M;		// To UUT_0 of top.v
   reg			ADC3_DA1P;		// To UUT_0 of top.v
   reg			ADC3_DB0M;		// To UUT_0 of top.v
   reg			ADC3_DB0P;		// To UUT_0 of top.v
   reg			ADC3_DB1M;		// To UUT_0 of top.v
   reg			ADC3_DB1P;		// To UUT_0 of top.v
   reg			ADC3_DC0M;		// To UUT_0 of top.v
   reg			ADC3_DC0P;		// To UUT_0 of top.v
   reg			ADC3_DC1M;		// To UUT_0 of top.v
   reg			ADC3_DC1P;		// To UUT_0 of top.v
   reg			ADC3_DCLK_M;		// To UUT_0 of top.v
   reg			ADC3_DCLK_P;		// To UUT_0 of top.v
   reg			ADC3_DD0M;		// To UUT_0 of top.v
   reg			ADC3_DD0P;		// To UUT_0 of top.v
   reg			ADC3_DD1M;		// To UUT_0 of top.v
   reg			ADC3_DD1P;		// To UUT_0 of top.v
   reg			ADC3_FCLK_M;		// To UUT_0 of top.v
   reg			ADC3_FCLK_P;		// To UUT_0 of top.v
   reg			ADC4_DA0M;		// To UUT_0 of top.v
   reg			ADC4_DA0P;		// To UUT_0 of top.v
   reg			ADC4_DA1M;		// To UUT_0 of top.v
   reg			ADC4_DA1P;		// To UUT_0 of top.v
   reg			ADC4_DB0M;		// To UUT_0 of top.v
   reg			ADC4_DB0P;		// To UUT_0 of top.v
   reg			ADC4_DB1M;		// To UUT_0 of top.v
   reg			ADC4_DB1P;		// To UUT_0 of top.v
   reg			ADC4_DC0M;		// To UUT_0 of top.v
   reg			ADC4_DC0P;		// To UUT_0 of top.v
   reg			ADC4_DC1M;		// To UUT_0 of top.v
   reg			ADC4_DC1P;		// To UUT_0 of top.v
   reg			ADC4_DCLK_M;		// To UUT_0 of top.v
   reg			ADC4_DCLK_P;		// To UUT_0 of top.v
   reg			ADC4_DD0M;		// To UUT_0 of top.v
   reg			ADC4_DD0P;		// To UUT_0 of top.v
   reg			ADC4_DD1M;		// To UUT_0 of top.v
   reg			ADC4_DD1P;		// To UUT_0 of top.v
   reg			ADC4_FCLK_M;		// To UUT_0 of top.v
   reg			ADC4_FCLK_P;		// To UUT_0 of top.v
   reg			ADC5_DA0M;		// To UUT_0 of top.v
   reg			ADC5_DA0P;		// To UUT_0 of top.v
   reg			ADC5_DA1M;		// To UUT_0 of top.v
   reg			ADC5_DA1P;		// To UUT_0 of top.v
   reg			ADC5_DB0M;		// To UUT_0 of top.v
   reg			ADC5_DB0P;		// To UUT_0 of top.v
   reg			ADC5_DB1M;		// To UUT_0 of top.v
   reg			ADC5_DB1P;		// To UUT_0 of top.v
   reg			ADC5_DC0M;		// To UUT_0 of top.v
   reg			ADC5_DC0P;		// To UUT_0 of top.v
   reg			ADC5_DC1M;		// To UUT_0 of top.v
   reg			ADC5_DC1P;		// To UUT_0 of top.v
   reg			ADC5_DCLK_M;		// To UUT_0 of top.v
   reg			ADC5_DCLK_P;		// To UUT_0 of top.v
   reg			ADC5_DD0M;		// To UUT_0 of top.v
   reg			ADC5_DD0P;		// To UUT_0 of top.v
   reg			ADC5_DD1M;		// To UUT_0 of top.v
   reg			ADC5_DD1P;		// To UUT_0 of top.v
   reg			ADC5_FCLK_M;		// To UUT_0 of top.v
   reg			ADC5_FCLK_P;		// To UUT_0 of top.v
   reg			DISCR_OUT0;		// To UUT_0 of top.v
   reg			DISCR_OUT1;		// To UUT_0 of top.v
   reg			DISCR_OUT10;		// To UUT_0 of top.v
   reg			DISCR_OUT11;		// To UUT_0 of top.v
   reg			DISCR_OUT12;		// To UUT_0 of top.v
   reg			DISCR_OUT13;		// To UUT_0 of top.v
   reg			DISCR_OUT14;		// To UUT_0 of top.v
   reg			DISCR_OUT15;		// To UUT_0 of top.v
   reg			DISCR_OUT16;		// To UUT_0 of top.v
   reg			DISCR_OUT17;		// To UUT_0 of top.v
   reg			DISCR_OUT18;		// To UUT_0 of top.v
   reg			DISCR_OUT19;		// To UUT_0 of top.v
   reg			DISCR_OUT2;		// To UUT_0 of top.v
   reg			DISCR_OUT20;		// To UUT_0 of top.v
   reg			DISCR_OUT21;		// To UUT_0 of top.v
   reg			DISCR_OUT22;		// To UUT_0 of top.v
   reg			DISCR_OUT23;		// To UUT_0 of top.v
   reg			DISCR_OUT3;		// To UUT_0 of top.v
   reg			DISCR_OUT4;		// To UUT_0 of top.v
   reg			DISCR_OUT5;		// To UUT_0 of top.v
   reg			DISCR_OUT6;		// To UUT_0 of top.v
   reg			DISCR_OUT7;		// To UUT_0 of top.v
   reg			DISCR_OUT8;		// To UUT_0 of top.v
   reg			DISCR_OUT9;		// To UUT_0 of top.v
   reg			FMC_CEn;		// To UUT_0 of top.v
   reg			FMC_OEn;		// To UUT_0 of top.v
   reg			FMC_WEn;		// To UUT_0 of top.v
   reg			FPGA_CLOCK_N;		// To UUT_0 of top.v
   reg			FPGA_CLOCK_P;		// To UUT_0 of top.v
   reg			FPGA_GPIO_0;		// To UUT_0 of top.v
   reg			FPGA_GPIO_1;		// To UUT_0 of top.v
   reg			FPGA_SYNC_N;		// To UUT_0 of top.v
   reg			FPGA_SYNC_P;		// To UUT_0 of top.v
   reg			FPGA_UART_CTS;		// To UUT_0 of top.v
   reg			FPGA_UART_RX;		// To UUT_0 of top.v
   reg			FTD_UART_RTSn;		// To UUT_0 of top.v
   reg			FTD_UART_TXD;		// To UUT_0 of top.v
   reg			MCU_AFE_SEL;		// To UUT_0 of top.v
   reg			MCU_CAL_A0;		// To UUT_0 of top.v
   reg			MCU_CAL_A1;		// To UUT_0 of top.v
   reg			MCU_CAL_A2;		// To UUT_0 of top.v
   reg			MCU_CAL_A3;		// To UUT_0 of top.v
   reg			MCU_CAL_A4;		// To UUT_0 of top.v
   reg			MCU_CAL_MISO;		// To UUT_0 of top.v
   reg			MCU_CAL_MOSI;		// To UUT_0 of top.v
   reg			MCU_CAL_SS;		// To UUT_0 of top.v
   reg			MCU_USART6_RX;		// To UUT_0 of top.v
   reg			MCU_USART6_TX;		// To UUT_0 of top.v
   reg			MON_ADC1_SDO;		// To UUT_0 of top.v
   reg			MON_ADC2_SDO;		// To UUT_0 of top.v
   reg			QOSC_CLK_P1V8;		// To UUT_0 of top.v
   reg			TRIG_IN;		// To UUT_0 of top.v
   // End of automatics

   // Backplane
   wire [15:0] 		FMC_D;
   reg [11:0] 		FMC_A;
   reg [15:0] 		fmc_din;
   wire [15:0] 		fmc_dout;
   assign FMC_D = FMC_OEn==0 ? 16'hZZZZ : fmc_din;
   assign fmc_dout = FMC_D;


   //////////////////////////////////////////////////////////////////////
   // Clock Driver
   //////////////////////////////////////////////////////////////////////
   always @(clk)
     #(CLK_PERIOD / 2.0) clk <= !clk;
   always @(*) begin FPGA_CLOCK_P = clk; FPGA_CLOCK_N = !clk; end

   //////////////////////////////////////////////////////////////////////
   // Simulated interfaces
   //////////////////////////////////////////////////////////////////////

   //////////////////////////////////////////////////////////////////////
   // UUT
   //////////////////////////////////////////////////////////////////////
   top UUT_0(/*AUTOINST*/
             // Outputs
             .FTD_UART_CTSn		(FTD_UART_CTSn),
             .FTD_UART_RXD		(FTD_UART_RXD),
             .FPGA_UART_RTS		(FPGA_UART_RTS),
             .FPGA_UART_TX		(FPGA_UART_TX),
             .ADC0_CLOCK_P		(ADC0_CLOCK_P),
             .ADC0_CLOCK_M		(ADC0_CLOCK_M),
             .ADC0_SEN			(ADC0_SEN),
             .ADC1_CLOCK_P		(ADC1_CLOCK_P),
             .ADC1_CLOCK_M		(ADC1_CLOCK_M),
             .ADC1_SEN			(ADC1_SEN),
             .ADC2_CLOCK_P		(ADC2_CLOCK_P),
             .ADC2_CLOCK_M		(ADC2_CLOCK_M),
             .ADC2_SEN			(ADC2_SEN),
             .ADC3_CLOCK_M		(ADC3_CLOCK_M),
             .ADC3_SEN			(ADC3_SEN),
             .ADC4_CLOCK_P		(ADC4_CLOCK_P),
             .ADC4_CLOCK_M		(ADC4_CLOCK_M),
             .ADC4_SEN			(ADC4_SEN),
             .ADC5_CLOCK_P		(ADC5_CLOCK_P),
             .ADC5_CLOCK_M		(ADC5_CLOCK_M),
             .ADC5_SEN			(ADC5_SEN),
`ifdef MDOMREV1
             .ADC0_SYSRF_P		(ADC0_SYSRF_P),
             .ADC0_SYSRF_M		(ADC0_SYSRF_M),
             .ADC1_SYSRF_P		(ADC1_SYSRF_P),
             .ADC1_SYSRF_M		(ADC1_SYSRF_M),
             .ADC2_SYSRF_P		(ADC2_SYSRF_P),
             .ADC2_SYSRF_M		(ADC2_SYSRF_M),
             .ADC3_SYSRF_P		(ADC3_SYSRF_P),
             .ADC3_SYSRF_M		(ADC3_SYSRF_M),
             .ADC4_SYSRF_P		(ADC4_SYSRF_P),
             .ADC4_SYSRF_M		(ADC4_SYSRF_M),
             .ADC5_SYSRF_P		(ADC5_SYSRF_P),
             .ADC5_SYSRF_M		(ADC5_SYSRF_M),
`endif
             .ADC_RESET			(ADC_RESET),
             .ADC_SCLK			(ADC_SCLK),
             .ADC_SDATA			(ADC_SDATA),
             .DAC0_DIN			(DAC0_DIN),
             .DAC0_nSYNC0		(DAC0_nSYNC0),
             .DAC0_nSYNC1		(DAC0_nSYNC1),
             .DAC0_nSYNC2		(DAC0_nSYNC2),
             .DAC0_SCLK			(DAC0_SCLK),
             .DAC1_DIN			(DAC1_DIN),
             .DAC1_nSYNC0		(DAC1_nSYNC0),
             .DAC1_nSYNC1		(DAC1_nSYNC1),
             .DAC1_nSYNC2		(DAC1_nSYNC2),
             .DAC1_SCLK			(DAC1_SCLK),
             .DAC2_DIN			(DAC2_DIN),
             .DAC2_nSYNC0		(DAC2_nSYNC0),
             .DAC2_nSYNC1		(DAC2_nSYNC1),
             .DAC2_nSYNC2		(DAC2_nSYNC2),
             .DAC2_SCLK			(DAC2_SCLK),
             .FMC_IRQ3			(FMC_IRQ3),
             .FMC_IRQ2			(FMC_IRQ2),
             .FMC_IRQ1			(FMC_IRQ1),
             .FMC_IRQ0			(FMC_IRQ0),
             .LED_YELLOW		(LED_YELLOW),
             .LED_GREEN			(LED_GREEN),
             .LED_ORANGE		(LED_ORANGE),
             .TRIG_OUT			(TRIG_OUT),
`ifndef MDOMREV1
             .AFE0_TPR			(AFE0_TPR),
             .AFE1_TPR			(AFE1_TPR),
             .AFE2_TPR			(AFE2_TPR),
             .AFE3_TPR			(AFE3_TPR),
             .AFE4_TPR			(AFE4_TPR),
             .AFE5_TPR			(AFE5_TPR),
`endif
             .MON_ADC1_CONVn		(MON_ADC1_CONVn),
             .MON_ADC1_CSn		(MON_ADC1_CSn),
             .MON_ADC1_SCLK		(MON_ADC1_SCLK),
             .MON_ADC1_SDI		(MON_ADC1_SDI),
             .MON_ADC2_CONVn		(MON_ADC2_CONVn),
             .MON_ADC2_CSn		(MON_ADC2_CSn),
             .MON_ADC2_SCLK		(MON_ADC2_SCLK),
             .MON_ADC2_SDI		(MON_ADC2_SDI),
             .DCDC_SYNC			(DCDC_SYNC),
             .FPGA_I2C_SCL		(FPGA_I2C_SCL),
             .DDR3_CLK100_OUT		(DDR3_CLK100_OUT),
             .DDR3_VTT_S3		(DDR3_VTT_S3),
             .DDR3_VTT_S5		(DDR3_VTT_S5),
             .ddr3_addr			(ddr3_addr[13:0]),
             .ddr3_ba			(ddr3_ba[2:0]),
             .ddr3_ras_n		(ddr3_ras_n),
             .ddr3_cas_n		(ddr3_cas_n),
             .ddr3_we_n			(ddr3_we_n),
             .ddr3_reset_n		(ddr3_reset_n),
             .ddr3_ck_p			(ddr3_ck_p[0:0]),
             .ddr3_ck_n			(ddr3_ck_n[0:0]),
             .ddr3_cke			(ddr3_cke[0:0]),
             .ddr3_cs_n			(ddr3_cs_n[0:0]),
             .ddr3_dm			(ddr3_dm[1:0]),
             .ddr3_odt			(ddr3_odt[0:0]),
             // Inouts
             .FMC_D15			(FMC_D[15]),
             .FMC_D14			(FMC_D[14]),
             .FMC_D13			(FMC_D[13]),
             .FMC_D12			(FMC_D[12]),
             .FMC_D11			(FMC_D[11]),
             .FMC_D10			(FMC_D[10]),
             .FMC_D9			(FMC_D[9]),
             .FMC_D8			(FMC_D[8]),
             .FMC_D7			(FMC_D[7]),
             .FMC_D6			(FMC_D[6]),
             .FMC_D5			(FMC_D[5]),
             .FMC_D4			(FMC_D[4]),
             .FMC_D3			(FMC_D[3]),
             .FMC_D2			(FMC_D[2]),
             .FMC_D1			(FMC_D[1]),
             .FMC_D0			(FMC_D[0]),
             .FPGA_I2C_SDA		(FPGA_I2C_SDA),
             .ddr3_dq			(ddr3_dq[15:0]),
             .ddr3_dqs_n		(ddr3_dqs_n[1:0]),
             .ddr3_dqs_p		(ddr3_dqs_p[1:0]),
             // Inputs
             .QOSC_CLK_P1V8		(QOSC_CLK_P1V8),
             .FPGA_CLOCK_P		(FPGA_CLOCK_P),
             .FPGA_CLOCK_N		(FPGA_CLOCK_N),
             .FTD_UART_RTSn		(FTD_UART_RTSn),
             .FTD_UART_TXD		(FTD_UART_TXD),
             .FPGA_UART_CTS		(FPGA_UART_CTS),
             .FPGA_UART_RX		(FPGA_UART_RX),
             .FPGA_SYNC_P		(FPGA_SYNC_P),
             .FPGA_SYNC_N		(FPGA_SYNC_N),
             .FPGA_GPIO_0		(FPGA_GPIO_0),
             .FPGA_GPIO_1		(FPGA_GPIO_1),
             .MCU_USART6_TX		(MCU_USART6_TX),
             .MCU_USART6_RX		(MCU_USART6_RX),
             .MCU_CAL_A0		(MCU_CAL_A0),
`ifndef MDOMREV1
             .MCU_CAL_A1		(MCU_CAL_A1),
             .MCU_CAL_A2		(MCU_CAL_A2),
             .MCU_CAL_A3		(MCU_CAL_A3),
             .MCU_CAL_A4		(MCU_CAL_A4),
`endif
             .MCU_AFE_SEL		(MCU_AFE_SEL),
             .MCU_CAL_SS		(MCU_CAL_SS),
             .MCU_CAL_MOSI		(MCU_CAL_MOSI),
             .MCU_CAL_MISO		(MCU_CAL_MISO),
             .ADC0_DA0P			(ADC0_DA0P),
             .ADC0_DA0M			(ADC0_DA0M),
             .ADC0_DA1P			(ADC0_DA1P),
             .ADC0_DA1M			(ADC0_DA1M),
             .ADC0_DB0P			(ADC0_DB0P),
             .ADC0_DB0M			(ADC0_DB0M),
             .ADC0_DB1P			(ADC0_DB1P),
             .ADC0_DB1M			(ADC0_DB1M),
             .ADC0_DC0P			(ADC0_DC0P),
             .ADC0_DC0M			(ADC0_DC0M),
             .ADC0_DC1P			(ADC0_DC1P),
             .ADC0_DC1M			(ADC0_DC1M),
             .ADC0_DCLK_P		(ADC0_DCLK_P),
             .ADC0_DCLK_M		(ADC0_DCLK_M),
             .ADC0_DD0P			(ADC0_DD0P),
             .ADC0_DD0M			(ADC0_DD0M),
             .ADC0_DD1P			(ADC0_DD1P),
             .ADC0_DD1M			(ADC0_DD1M),
             .ADC0_FCLK_P		(ADC0_FCLK_P),
             .ADC0_FCLK_M		(ADC0_FCLK_M),
             .ADC0_SDOUT		(ADC0_SDOUT),
             .ADC1_DA0P			(ADC1_DA0P),
             .ADC1_DA0M			(ADC1_DA0M),
             .ADC1_DA1P			(ADC1_DA1P),
             .ADC1_DA1M			(ADC1_DA1M),
             .ADC1_DB0P			(ADC1_DB0P),
             .ADC1_DB0M			(ADC1_DB0M),
             .ADC1_DB1P			(ADC1_DB1P),
             .ADC1_DB1M			(ADC1_DB1M),
             .ADC1_DC0P			(ADC1_DC0P),
             .ADC1_DC0M			(ADC1_DC0M),
             .ADC1_DC1P			(ADC1_DC1P),
             .ADC1_DC1M			(ADC1_DC1M),
             .ADC1_DCLK_P		(ADC1_DCLK_P),
             .ADC1_DCLK_M		(ADC1_DCLK_M),
             .ADC1_DD0P			(ADC1_DD0P),
             .ADC1_DD0M			(ADC1_DD0M),
             .ADC1_DD1P			(ADC1_DD1P),
             .ADC1_DD1M			(ADC1_DD1M),
             .ADC1_FCLK_P		(ADC1_FCLK_P),
             .ADC1_FCLK_M		(ADC1_FCLK_M),
             .ADC2_DA0P			(ADC2_DA0P),
             .ADC2_DA0M			(ADC2_DA0M),
             .ADC2_DA1P			(ADC2_DA1P),
             .ADC2_DA1M			(ADC2_DA1M),
             .ADC2_DB0P			(ADC2_DB0P),
             .ADC2_DB0M			(ADC2_DB0M),
             .ADC2_DB1P			(ADC2_DB1P),
             .ADC2_DB1M			(ADC2_DB1M),
             .ADC2_DC0P			(ADC2_DC0P),
             .ADC2_DC0M			(ADC2_DC0M),
             .ADC2_DC1P			(ADC2_DC1P),
             .ADC2_DC1M			(ADC2_DC1M),
             .ADC2_DCLK_P		(ADC2_DCLK_P),
             .ADC2_DCLK_M		(ADC2_DCLK_M),
             .ADC2_DD0P			(ADC2_DD0P),
             .ADC2_DD0M			(ADC2_DD0M),
             .ADC2_DD1P			(ADC2_DD1P),
             .ADC2_DD1M			(ADC2_DD1M),
             .ADC2_FCLK_P		(ADC2_FCLK_P),
             .ADC2_FCLK_M		(ADC2_FCLK_M),
             .ADC3_DA0P			(ADC3_DA0P),
             .ADC3_DA0M			(ADC3_DA0M),
             .ADC3_DA1P			(ADC3_DA1P),
             .ADC3_DA1M			(ADC3_DA1M),
             .ADC3_DB0P			(ADC3_DB0P),
             .ADC3_DB0M			(ADC3_DB0M),
             .ADC3_DB1P			(ADC3_DB1P),
             .ADC3_DB1M			(ADC3_DB1M),
             .ADC3_DC0P			(ADC3_DC0P),
             .ADC3_DC0M			(ADC3_DC0M),
             .ADC3_DC1P			(ADC3_DC1P),
             .ADC3_DC1M			(ADC3_DC1M),
             .ADC3_DCLK_P		(ADC3_DCLK_P),
             .ADC3_DCLK_M		(ADC3_DCLK_M),
             .ADC3_DD0P			(ADC3_DD0P),
             .ADC3_DD0M			(ADC3_DD0M),
             .ADC3_DD1P			(ADC3_DD1P),
             .ADC3_DD1M			(ADC3_DD1M),
             .ADC3_FCLK_P		(ADC3_FCLK_P),
             .ADC3_FCLK_M		(ADC3_FCLK_M),
             .ADC4_DA0P			(ADC4_DA0P),
             .ADC4_DA0M			(ADC4_DA0M),
             .ADC4_DA1P			(ADC4_DA1P),
             .ADC4_DA1M			(ADC4_DA1M),
             .ADC4_DB0P			(ADC4_DB0P),
             .ADC4_DB0M			(ADC4_DB0M),
             .ADC4_DB1P			(ADC4_DB1P),
             .ADC4_DB1M			(ADC4_DB1M),
             .ADC4_DC0P			(ADC4_DC0P),
             .ADC4_DC0M			(ADC4_DC0M),
             .ADC4_DC1P			(ADC4_DC1P),
             .ADC4_DC1M			(ADC4_DC1M),
             .ADC4_DCLK_P		(ADC4_DCLK_P),
             .ADC4_DCLK_M		(ADC4_DCLK_M),
             .ADC4_DD0P			(ADC4_DD0P),
             .ADC4_DD0M			(ADC4_DD0M),
             .ADC4_DD1P			(ADC4_DD1P),
             .ADC4_DD1M			(ADC4_DD1M),
             .ADC4_FCLK_P		(ADC4_FCLK_P),
             .ADC4_FCLK_M		(ADC4_FCLK_M),
             .ADC5_DA0P			(ADC5_DA0P),
             .ADC5_DA0M			(ADC5_DA0M),
             .ADC5_DA1P			(ADC5_DA1P),
             .ADC5_DA1M			(ADC5_DA1M),
             .ADC5_DB0P			(ADC5_DB0P),
             .ADC5_DB0M			(ADC5_DB0M),
             .ADC5_DB1P			(ADC5_DB1P),
             .ADC5_DB1M			(ADC5_DB1M),
             .ADC5_DC0P			(ADC5_DC0P),
             .ADC5_DC0M			(ADC5_DC0M),
             .ADC5_DC1P			(ADC5_DC1P),
             .ADC5_DC1M			(ADC5_DC1M),
             .ADC5_DCLK_P		(ADC5_DCLK_P),
             .ADC5_DCLK_M		(ADC5_DCLK_M),
             .ADC5_DD0P			(ADC5_DD0P),
             .ADC5_DD0M			(ADC5_DD0M),
             .ADC5_DD1P			(ADC5_DD1P),
             .ADC5_DD1M			(ADC5_DD1M),
             .ADC5_FCLK_P		(ADC5_FCLK_P),
             .ADC5_FCLK_M		(ADC5_FCLK_M),
             .DISCR_OUT0		(DISCR_OUT0),
             .DISCR_OUT1		(DISCR_OUT1),
             .DISCR_OUT2		(DISCR_OUT2),
             .DISCR_OUT3		(DISCR_OUT3),
             .DISCR_OUT4		(DISCR_OUT4),
             .DISCR_OUT5		(DISCR_OUT5),
             .DISCR_OUT6		(DISCR_OUT6),
             .DISCR_OUT7		(DISCR_OUT7),
             .DISCR_OUT8		(DISCR_OUT8),
             .DISCR_OUT9		(DISCR_OUT9),
             .DISCR_OUT10		(DISCR_OUT10),
             .DISCR_OUT11		(DISCR_OUT11),
             .DISCR_OUT12		(DISCR_OUT12),
             .DISCR_OUT13		(DISCR_OUT13),
             .DISCR_OUT14		(DISCR_OUT14),
             .DISCR_OUT15		(DISCR_OUT15),
             .DISCR_OUT16		(DISCR_OUT16),
             .DISCR_OUT17		(DISCR_OUT17),
             .DISCR_OUT18		(DISCR_OUT18),
             .DISCR_OUT19		(DISCR_OUT19),
             .DISCR_OUT20		(DISCR_OUT20),
             .DISCR_OUT21		(DISCR_OUT21),
             .DISCR_OUT22		(DISCR_OUT22),
             .DISCR_OUT23		(DISCR_OUT23),
             .FMC_A11			(FMC_A[11]),
             .FMC_A10			(FMC_A[10]),
             .FMC_A9			(FMC_A[9]),
             .FMC_A8			(FMC_A[8]),
             .FMC_A7			(FMC_A[7]),
             .FMC_A6			(FMC_A[6]),
             .FMC_A5			(FMC_A[5]),
             .FMC_A4			(FMC_A[4]),
             .FMC_A3			(FMC_A[3]),
             .FMC_A2			(FMC_A[2]),
             .FMC_A1			(FMC_A[1]),
             .FMC_A0			(FMC_A[0]),
             .FMC_CEn			(FMC_CEn),
             .FMC_OEn			(FMC_OEn),
             .FMC_WEn			(FMC_WEn),
             .TRIG_IN			(TRIG_IN),
             .FPGA_CAL_TRIG_P		(FPGA_CAL_TRIG_P),
             .FPGA_CAL_TRIG_N		(FPGA_CAL_TRIG_N),
             .MON_ADC1_SDO		(MON_ADC1_SDO),
             .MON_ADC2_SDO		(MON_ADC2_SDO));

    // do not include the DDR3 simulation model
    // ddr3_model ddr3(
    //   .rst_n(ddr3_reset_n),
    //   .ck(ddr3_ck_p),
    //   .ck_n(ddr3_ck_n),
    //   .cke(ddr3_cke),
    //   .cs_n(ddr3_cs_n),
    //   .ras_n(ddr3_ras_n),
    //   .cas_n(ddr3_cas_n),
    //   .we_n(ddr3_we_n),
    //   .dm_tdqs(ddr3_dm),
    //   .ba(ddr3_ba),
    //   .addr(ddr3_addr),
    //   .dq(ddr3_dq),
    //   .dqs(ddr3_dqs_p),
    //   .dqs_n(ddr3_dqs_n),
    //   .tdqs_n(),
    //   .odt(ddr3_odt)
    // );

   //////////////////////////////////////////////////////////////////////
   // Testbench
   //////////////////////////////////////////////////////////////////////
   initial
     begin
        // Initializations
        clk = 1'b0;
        rst = 1'b1;
     end

   //////////////////////////////////////////////////////////////////////
   // Test case
   //////////////////////////////////////////////////////////////////////
   `ifdef TEST_CASE_1
   integer i;
   initial
     begin
        i = 0;
        FMC_CEn = 1'b1;
        FMC_WEn = 1'b1;
        FMC_OEn = 1'b1;
        FMC_A = 0;


        // Reset
        #(10 * CLK_PERIOD);
        rst = 1'b0;
        #(20* CLK_PERIOD);

        // Logging
        $display("");
        $display("------------------------------------------------------");
        $display("Test Case: TEST_CASE_1");

        #(10_000_000);

        @(posedge clk) FMC_WEn=1; FMC_OEn = 0; FMC_CEn=0; FMC_A=16'hfff; fmc_din=16'h0; #1;
        @(posedge clk) FMC_OEn = 1; FMC_CEn = 1; #1;
        $display("Reading the FW_VNUM reg");

        // set pre conf to 4 samples
        @(posedge clk) FMC_WEn=0; FMC_CEn=0; FMC_A=16'hbf0; fmc_din=16'h4; #1;
        @(posedge clk) FMC_WEn=1; FMC_CEn=1; fmc_din=0; FMC_A=0; #1;

        // set test conf to 256 samples
        @(posedge clk) FMC_WEn=0; FMC_CEn=0; FMC_A=16'hbf2; fmc_din=16'd256; #1;
        @(posedge clk) FMC_WEn=1; FMC_CEn=1; fmc_din=0; FMC_A=0; #1;

        // hbuf start page
        @(posedge clk) FMC_WEn=0; FMC_CEn=0; FMC_A=16'hbc4; fmc_din=16'd21; #1;
        @(posedge clk) FMC_WEn=1; FMC_CEn=1; fmc_din=16'd0; FMC_A=0; #1;
        // hbuf stop page
        @(posedge clk) FMC_WEn=0; FMC_CEn=0; FMC_A=16'hbc3; fmc_din=16'd10_021; #1;
        @(posedge clk) FMC_WEn=1; FMC_CEn=1; fmc_din=16'd0; FMC_A=0; #1;

        // Enable hbuf controller
        @(posedge clk) FMC_WEn=0; FMC_CEn=0; FMC_A=16'hbc5; fmc_din=16'h1; #1;
        @(posedge clk) FMC_WEn=1; FMC_CEn=1; fmc_din=0; FMC_A=0; #1;

        // enable wvb reader
        @(posedge clk) FMC_WEn=0; FMC_CEn=0; FMC_A=16'hdf4; fmc_din=16'h1; #1;
        @(posedge clk) FMC_WEn=1; FMC_CEn=1; fmc_din=0; FMC_A=0; #1;

        // wait 50 microseconds
        // read the overflow fifo data count; it should be 0
        #(50_000_000);
        @(posedge clk) FMC_WEn=1; FMC_OEn <= 0; FMC_CEn<=0; FMC_A=16'hb89; fmc_din=16'h0; #1;
        @(posedge clk) #1;
        @(posedge clk) FMC_OEn=1; FMC_CEn=1; #1;

        // wait 450 microseconds
        #(450_000_000);
        // after all are in overflow, read overflow count,
        // then read the first overflow data out, then empty the overflow fifo
        // read data count
        @(posedge clk) FMC_WEn=1; FMC_OEn <= 0; FMC_CEn<=0; FMC_A=16'hb89; fmc_din=16'h0; #1;
        @(posedge clk) #1;
        @(posedge clk) FMC_OEn=1; FMC_CEn=1; #1;

        // pop one out of the fifo
        @(posedge clk) FMC_WEn=0; FMC_CEn=0; FMC_A=16'hb88; fmc_din=16'h1; #1;
        @(posedge clk) FMC_WEn=1; FMC_CEn=1; fmc_din=0; FMC_A=0; #1;

        // read data count
        @(posedge clk) FMC_WEn=1; FMC_OEn <= 0; FMC_CEn<=0; FMC_A=16'hb89; fmc_din=16'h0; #1;
        @(posedge clk) #1;
        @(posedge clk) FMC_OEn=1; FMC_CEn=1; #1;
        // read the data
        @(posedge clk) FMC_WEn=1; FMC_OEn <= 0; FMC_CEn<=0; FMC_A=16'hb87; fmc_din=16'h0; #1;
        @(posedge clk) #1;
        @(posedge clk) FMC_OEn=1; FMC_CEn=1; #1;
        @(posedge clk) FMC_WEn=1; FMC_OEn <= 0; FMC_CEn<=0; FMC_A=16'hb86; fmc_din=16'h0; #1;
        @(posedge clk) #1;
        @(posedge clk) FMC_OEn=1; FMC_CEn=1; #1;
        @(posedge clk) FMC_WEn=1; FMC_OEn <= 0; FMC_CEn<=0; FMC_A=16'hb85; fmc_din=16'h0; #1;
        @(posedge clk) #1;
        @(posedge clk) FMC_OEn=1; FMC_CEn=1; #1;
        @(posedge clk) FMC_WEn=1; FMC_OEn <= 0; FMC_CEn<=0; FMC_A=16'hb84; fmc_din=16'h0; #1;
        @(posedge clk) #1;
        @(posedge clk) FMC_OEn=1; FMC_CEn=1; #1;
        @(posedge clk) FMC_WEn=1; FMC_OEn <= 0; FMC_CEn<=0; FMC_A=16'hb83; fmc_din=16'h0; #1;
        @(posedge clk) #1;
        @(posedge clk) FMC_OEn=1; FMC_CEn=1; #1;
        @(posedge clk) FMC_WEn=1; FMC_OEn <= 0; FMC_CEn<=0; FMC_A=16'hb82; fmc_din=16'h0; #1;
        @(posedge clk) #1;
        @(posedge clk) FMC_OEn=1; FMC_CEn=1; #1;
        @(posedge clk) FMC_WEn=1; FMC_OEn <= 0; FMC_CEn<=0; FMC_A=16'hb81; fmc_din=16'h0; #1;
        @(posedge clk) #1;
        @(posedge clk) FMC_OEn=1; FMC_CEn=1; #1;

        // pop a few more events off the fifo
        @(posedge clk) FMC_WEn=0; FMC_CEn=0; FMC_A=16'hb88; fmc_din=16'h1; #1;
        @(posedge clk) FMC_WEn=1; FMC_CEn=1; fmc_din=0; FMC_A=0; #1;
        @(posedge clk) FMC_WEn=0; FMC_CEn=0; FMC_A=16'hb88; fmc_din=16'h1; #1;
        @(posedge clk) FMC_WEn=1; FMC_CEn=1; fmc_din=0; FMC_A=0; #1;
        @(posedge clk) FMC_WEn=0; FMC_CEn=0; FMC_A=16'hb88; fmc_din=16'h1; #1;
        @(posedge clk) FMC_WEn=1; FMC_CEn=1; fmc_din=0; FMC_A=0; #1;
        @(posedge clk) FMC_WEn=0; FMC_CEn=0; FMC_A=16'hb88; fmc_din=16'h1; #1;
        @(posedge clk) FMC_WEn=1; FMC_CEn=1; fmc_din=0; FMC_A=0; #1;
        @(posedge clk) FMC_WEn=0; FMC_CEn=0; FMC_A=16'hb88; fmc_din=16'h1; #1;
        @(posedge clk) FMC_WEn=1; FMC_CEn=1; fmc_din=0; FMC_A=0; #1;
        @(posedge clk) FMC_WEn=0; FMC_CEn=0; FMC_A=16'hb88; fmc_din=16'h1; #1;
        @(posedge clk) FMC_WEn=1; FMC_CEn=1; fmc_din=0; FMC_A=0; #1;
        @(posedge clk) FMC_WEn=0; FMC_CEn=0; FMC_A=16'hb88; fmc_din=16'h1; #1;
        @(posedge clk) FMC_WEn=1; FMC_CEn=1; fmc_din=0; FMC_A=0; #1;
        @(posedge clk) FMC_WEn=0; FMC_CEn=0; FMC_A=16'hb88; fmc_din=16'h1; #1;
        @(posedge clk) FMC_WEn=1; FMC_CEn=1; fmc_din=0; FMC_A=0; #1;
        @(posedge clk) FMC_WEn=0; FMC_CEn=0; FMC_A=16'hb88; fmc_din=16'h1; #1;
        @(posedge clk) FMC_WEn=1; FMC_CEn=1; fmc_din=0; FMC_A=0; #1;
        @(posedge clk) FMC_WEn=0; FMC_CEn=0; FMC_A=16'hb88; fmc_din=16'h1; #1;
        @(posedge clk) FMC_WEn=1; FMC_CEn=1; fmc_din=0; FMC_A=0; #1;
        @(posedge clk) FMC_WEn=0; FMC_CEn=0; FMC_A=16'hb88; fmc_din=16'h1; #1;
        @(posedge clk) FMC_WEn=1; FMC_CEn=1; fmc_din=0; FMC_A=0; #1;
        @(posedge clk) FMC_WEn=0; FMC_CEn=0; FMC_A=16'hb88; fmc_din=16'h1; #1;
        @(posedge clk) FMC_WEn=1; FMC_CEn=1; fmc_din=0; FMC_A=0; #1;
        @(posedge clk) FMC_WEn=0; FMC_CEn=0; FMC_A=16'hb88; fmc_din=16'h1; #1;
        @(posedge clk) FMC_WEn=1; FMC_CEn=1; fmc_din=0; FMC_A=0; #1;
        @(posedge clk) FMC_WEn=0; FMC_CEn=0; FMC_A=16'hb88; fmc_din=16'h1; #1;
        @(posedge clk) FMC_WEn=1; FMC_CEn=1; fmc_din=0; FMC_A=0; #1;
        @(posedge clk) FMC_WEn=0; FMC_CEn=0; FMC_A=16'hb88; fmc_din=16'h1; #1;
        @(posedge clk) FMC_WEn=1; FMC_CEn=1; fmc_din=0; FMC_A=0; #1;
        @(posedge clk) FMC_WEn=0; FMC_CEn=0; FMC_A=16'hb88; fmc_din=16'h1; #1;
        @(posedge clk) FMC_WEn=1; FMC_CEn=1; fmc_din=0; FMC_A=0; #1;
        @(posedge clk) FMC_WEn=0; FMC_CEn=0; FMC_A=16'hb88; fmc_din=16'h1; #1;
        @(posedge clk) FMC_WEn=1; FMC_CEn=1; fmc_din=0; FMC_A=0; #1;
        @(posedge clk) FMC_WEn=0; FMC_CEn=0; FMC_A=16'hb88; fmc_din=16'h1; #1;
        @(posedge clk) FMC_WEn=1; FMC_CEn=1; fmc_din=0; FMC_A=0; #1;
        @(posedge clk) FMC_WEn=0; FMC_CEn=0; FMC_A=16'hb88; fmc_din=16'h1; #1;
        @(posedge clk) FMC_WEn=1; FMC_CEn=1; fmc_din=0; FMC_A=0; #1;
        @(posedge clk) FMC_WEn=0; FMC_CEn=0; FMC_A=16'hb88; fmc_din=16'h1; #1;
        @(posedge clk) FMC_WEn=1; FMC_CEn=1; fmc_din=0; FMC_A=0; #1;
        @(posedge clk) FMC_WEn=0; FMC_CEn=0; FMC_A=16'hb88; fmc_din=16'h1; #1;
        @(posedge clk) FMC_WEn=1; FMC_CEn=1; fmc_din=0; FMC_A=0; #1;
        @(posedge clk) FMC_WEn=0; FMC_CEn=0; FMC_A=16'hb88; fmc_din=16'h1; #1;
        @(posedge clk) FMC_WEn=1; FMC_CEn=1; fmc_din=0; FMC_A=0; #1;
        @(posedge clk) FMC_WEn=0; FMC_CEn=0; FMC_A=16'hb88; fmc_din=16'h1; #1;
        @(posedge clk) FMC_WEn=1; FMC_CEn=1; fmc_din=0; FMC_A=0; #1;
     end
   `endif

// trigger the 24 channels, one after another, periodically
wire[48:0] ltc = UUT_0.ltc;
wire lclk = UUT_0.lclk;
localparam TRIGGER_PERIOD = 256;
generate
genvar i_chan;
for (i_chan = 0; i_chan < 24; i_chan = i_chan + 1) begin
  always @(posedge lclk) begin
    if (ltc >= 599 + i_chan && (ltc - 599 - i_chan) % TRIGGER_PERIOD == 0
        && (ltc < 12_600  || ltc > 59_649) // stop triggers after 100 microseconds, restart after overflow recovery
    ) begin
      #1;
      force UUT_0.waveform_acq_gen[i_chan].WFM_ACQ.WVB.trig = 1'b1;
      #20000;
      release UUT_0.waveform_acq_gen[i_chan].WFM_ACQ.WVB.trig;
    end
  end
end
endgenerate

// take control of DDR3 page transfer handshakes
// so we don't need to simulate the memory interface
// this speeds up the simulation considerably
wire pg_transfer_req = UUT_0.hbuf_pg_req;
wire pg_transfer_ack = UUT_0.hbuf_pg_ack;
always @(posedge lclk) begin
  // only start acknowledging handshakes after 
  // all buffers have overflowed
  if (ltc > 7019) begin
    if (pg_transfer_req && !pg_transfer_ack) begin
      #(CLK_PERIOD * 2 + 1000);
      $display("Forcing pg_transfer_ack high");
      force UUT_0.hbuf_pg_ack = 1'b1;
    end else if (!pg_transfer_req && pg_transfer_ack) begin
      #(CLK_PERIOD * 2 + 1000);
      $display("Forcing pg_transfer_ack low");
      force UUT_0.hbuf_pg_ack = 1'b0;
    end
  end
end


endmodule

// Local Variables:
// verilog-library-flags:("-y ../hdl/")
// End:

