# clocks and timing constraints

create_clock -name fpga_clk -period 50.000 [get_ports {FPGA_CLOCK_P}]
create_clock -name qosc_clk -period 50.000 [get_ports {QOSC_CLK_P1V8}]

# FMC IO constraints
#
# The STM32H7 drives the FMC asynchronously and sends no clock to the FPGA
# (STM32Workspace xdom-hal/src/fpga/fmc.c: Mode A, fmc_ker_ck = 100 MHz,
# DATAST = 7, ADDSET = 3 from MCU 0x58 and 1 before, BUSTURN = 0).  fmc_clk is
# only a virtual reference for the FMC ports.  Its 50 ns period limits the pin
# to pin paths (address -> read mux -> FMC_D, FMC_OEn -> FMC_D enable) to
# 48 ns, and the -datapath_only limits below cover the register segments.
#
# A read must drive FMC_D by DATAST * 10 - t_su (11) - board (1) = 58 ns after
# FMC_OEn falls, and the address is valid ADDSET * 10 ns before FMC_OEn falls.
# With the limits below, FMC_D is valid at the latest:
#   DPRAM words (address < 0x800): the address reaches xdom's dpram_adr
#     register within 8.333 ns and is captured by the next lclk edge, the DPRAM
#     samples it one lclk later and its output register one more, and FMC_D
#     follows within 16.667 ns: 8.333 + 3 * 8.333 + 16.667 = 50 ns after the
#     address, i.e. 40 ns (ADDSET = 1) or 20 ns (ADDSET = 3) after FMC_OEn.
#   Control registers: po_dout_1 loads on the third lclk edge after FMC_OEn
#     reaches SYNC_FMC_OEN_0 (8.333 ns), and FMC_D follows within 16.667 ns:
#     8.333 + 3 * 8.333 + 16.667 = 50 ns after FMC_OEn.  po_dout_1's input
#     settles within 16.667 ns of the address, before its earliest load edge.
# The DPRAMs take their xdom-side address from dpram_adr, never from the FMC
# pins directly: a block RAM address must meet setup and hold even on reads,
# or the stored data can be corrupted (DS189 note 7; mdommb_rev1_fw issue #4).
# If the MCU FMC timing changes, recheck these budgets.
create_clock -name fmc_clk -period 50
set_input_delay -clock fmc_clk 1.0 -max [get_ports FMC_A*]
set_input_delay -clock fmc_clk -1.0 -min [get_ports FMC_A*]
set_input_delay -clock fmc_clk 1.0 -max [get_ports FMC_D*]
set_input_delay -clock fmc_clk -1.0 -min [get_ports FMC_D*]
set_input_delay -clock fmc_clk 1.0 -max [get_ports FMC_*En]
set_input_delay -clock fmc_clk -1.0 -min [get_ports FMC_*En]

# FMC output constraint
set_output_delay -clock fmc_clk -max 1.0 [get_ports FMC_D*]
set_output_delay -clock fmc_clk -min -1.0 [get_ports FMC_D*]

# ICM input constraints
# see https://www.xilinx.com/support/documentation/data_sheets/ds189-spartan-7-data-sheet.pdf
# for info about Spartan 7 IO specs
# ICM clock is 60 MHz
create_clock -name icm_clk -period 16.667
set_input_delay -clock icm_clk -max 0.59 [get_ports FPGA_SYNC_*]
set_input_delay -clock icm_clk -min 0.39 [get_ports FPGA_SYNC_*]

# delays from FMC input to lclk registers should be < 1 clock cycle
set_max_delay -from [get_clocks fmc_clk] -to [get_clocks -of_objects [get_pins LCLK_ADCCLK_WIZ_0/inst/mmcm_adv_inst/CLKOUT0]] 8.333 -datapath_only
# except for path to po_dout_1, which can take 2 cycles
set_max_delay -from [get_clocks fmc_clk] -to [get_pins {po_dout_1_reg[*]/D}] 16.667 -datapath_only

# do not time most paths from lclk registers to FMC outputs
# exception is po_dout_1_reg, which is the one that really matters
#set_false_path -from [get_cells -hier -filter {NAME =~ * && IS_SEQUENTIAL && NAME !~ po_dout_1_reg*}] -to [get_clocks fmc_clk]
# just constrain all paths from lclk to FMC clk to be < 2 clock cycles max delay
# the above constraint works, but it selects a ton of paths. probably better to just constrain all the paths between the clocks
set_max_delay -from [get_clocks -of_objects [get_pins LCLK_ADCCLK_WIZ_0/inst/mmcm_adv_inst/CLKOUT0]] -to [get_clocks fmc_clk] 16.667 -datapath_only
set_false_path -from [get_clocks -of_objects [get_pins DDR3_TRANSFER_0/MIG_7_SERIES/u_mig_7series_0_mig/u_ddr3_infrastructure/gen_mmcm.mmcm_i/CLKFBOUT]] -to [get_clocks fmc_clk]
set_false_path -from [get_clocks -of_objects [get_pins DDR3_TRANSFER_0/MIG_7_SERIES/u_mig_7series_0_mig/u_ddr3_infrastructure/gen_mmcm.mmcm_i/CLKFBOUT]] -to [get_clocks fpga_clk]
set_false_path -from [get_clocks fpga_clk] -to [get_clocks -of_objects [get_pins DDR3_TRANSFER_0/MIG_7_SERIES/u_mig_7series_0_mig/u_ddr3_infrastructure/gen_mmcm.mmcm_i/CLKFBOUT]]

# from FMC to i_y_rd_addr in xdom
# these are paths where the FMC sets the address and the data is
# read through a UART. This is not something that we need to worry about
# set_false_path -from [get_pins {i_fmc_a_1_reg[*]/C}] -to [get_pins {XDOM_0/CRSM_0/i_y_rd_data_1_reg[*]/D}]
# set_false_path -from [get_pins {i_fmc_cen_1_reg/C}] -to [get_pins {XDOM_0/CRSM_0/i_y_rd_data_1_reg[*]/D}]
# similarly, we can ignore path from i_y_addr in CRSM to po_dout_1_reg. This would be
# setting the addr through a uart and then reading that data via the FMC
# set_false_path -from [get_pins {XDOM_0/CRSM_0/i_y_adr_reg[*]/C}] -to [get_pins {po_dout_1_reg[*]/D}]
# and from a_1/cen_1 to po_dout_1_reg or FMC outputs. The registered FMC addr & cen only matter
# for write operations
set_false_path -from [get_pins {i_fmc_a_1_reg[*]*/C}] -to [get_pins {po_dout_1_reg[*]/D}]
set_false_path -from [get_pins {i_fmc_cen_1_reg/C}] -to [get_pins {po_dout_1_reg[*]/D}]
set_false_path -from [get_pins {i_fmc_a_1_reg[*]/C}] -to [get_clocks fmc_clk]
set_false_path -from [get_pins {i_fmc_cen_1_reg/C}] -to [get_clocks fmc_clk]

# ignore paths that go directly from FMC clock to xdom registers.
# Write commands will always occur when oen == 1 and therefore use the registered
# fmc address, data, chip en, etc.
# (see fmc_addr_mux in top level module)
# IS_SEQUENTIAL selects the valid endpoints in xDOM
# The exception is XDOM_0/dpram_adr, which samples the FMC address pins for
# DPRAM reads and keeps the 8.333 ns limit above (see the read budget at the
# top of this section).
set_false_path -from [get_clocks fmc_clk] -to [get_cells -hier -filter {NAME =~ XDOM_0/* && IS_SEQUENTIAL && NAME !~ XDOM_0/dpram_adr_reg*}]




# set max delay from logic clock to DDR3 ui clock. DDR3 addrs, optypes must arrive before the synchronized pg_req.
# Use 12.308 ns delay, which is the period of the ddr3_ui_clk. This should ensure that all signals arrive in time
set_max_delay -from [get_clocks -of_objects [get_pins LCLK_ADCCLK_WIZ_0/inst/mmcm_adv_inst/CLKOUT0]] -to [get_clocks -of_objects [get_pins DDR3_TRANSFER_0/MIG_7_SERIES/u_mig_7series_0_mig/u_ddr3_infrastructure/gen_mmcm.mmcm_i/CLKFBOUT]] 12.308 -datapath_only
# max delay from DDR3 ui clock to logic clock can be two logic clock cycles
# this primarily affects sending the memory controller temperature reading to xDOM, but it also constrains handshake signals
set_max_delay -from [get_clocks -of_objects [get_pins DDR3_TRANSFER_0/MIG_7_SERIES/u_mig_7series_0_mig/u_ddr3_infrastructure/gen_mmcm.mmcm_i/CLKFBOUT]] -to [get_clocks -of_objects [get_pins LCLK_ADCCLK_WIZ_0/inst/mmcm_adv_inst/CLKOUT0]] 16.667 -datapath_only

# DDR input constraints are described in the following Xilinx forum thread
# https://forums.xilinx.com/t5/Timing-Analysis/How-to-constraint-Same-Edge-capture-edge-aligned-DDR-input/m-p/646009#M8411
# however, these seem to apply to source synchronous interfaces, which we won't be using in the mDOM
# instead, we'll run all SERDES off of a single clock inside the FPGA

# ATF todo: work out these constraints

# Below I'll try to define some reasonable constraints given this situation

# 375 MHz launch clock
# create_clock -name virt_clk -period 2.667

# setup and hold from datasheet page 17:
# https://www.ti.com/lit/ds/symlink/adc3424.pdf?ts=1593536289216&ref_url=https%253A%252F%252Fwww.ti.com%252Fproduct%252FADC3424
# t_su = 0.43 ns
# t_h = 0.48 ns
# The above are the specs at 125 MHz, which we may want to use
# max delay: UI/2 - setup time
#set_input_delay -clock virt_clk 0.237 [get_ports ADC*_D*]
# min delay: -UI/2 + hold time
#set_input_delay -clock virt_clk -0.187 -min [get_ports ADC*_D*]

#set_input_delay -clock virt_clk 0.237 [get_ports ADC*_D*] -clock_fall -add_delay
#set_input_delay -clock virt_clk -0.187 -min [get_ports ADC*_D*] -clock_fall -add_delay
