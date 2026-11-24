#!/bin/sh
# Simulate MCU FMC accesses to the xdom DDR3 page DPRAM with Icarus Verilog
# (mdommb_rev1_fw issue #4).  See fmc_dpram_tb.v for what is simulated.
#
# usage: hdl/xdom/sim/run_fmc_dpram_sim.sh [REV] [PARAM=VALUE ...] [+vcd]
#
#   REV          git revision whose RTL to simulate (e.g. HEAD, i.e. before an
#                uncommitted fix).  Default: the working tree.  The testbench
#                and models always come from this directory.
#   PARAM=VALUE  fmc_dpram_tb parameters, e.g. ADDSET=1 NE_GAP=0 SEED=3
#                N_HIT_PAGES=24 CORRUPT_PPM=2000 VERBOSE=1 EXPECT_NO_VIOLATIONS=1
#   +vcd         write fmc_dpram_tb.vcd (top level and PG_DPRAM) in the build
#                directory
#
# Build files go to $BUILD_DIR (default: a new temporary directory).
#
# Examples:
#   run_fmc_dpram_sim.sh HEAD EXPECT_NO_VIOLATIONS=1    # before the fix: FAIL
#   run_fmc_dpram_sim.sh EXPECT_NO_VIOLATIONS=1         # with the fix: PASS
#   run_fmc_dpram_sim.sh HEAD NE_GAP=0 N_HIT_PAGES=24 CORRUPT_PPM=2000 SEED=21
set -e

SIM_DIR=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$SIM_DIR/../../.." && pwd)

REV=
case "${1:-}" in
  ""|*=*|+*) ;;
  *) REV=$1; shift ;;
esac

BUILD=${BUILD_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/fmc_dpram_sim.XXXXXX")}
mkdir -p "$BUILD"

RTL="hdl/mdommb_fw_rev1_top.v
hdl/xdom/xdom.v
hdl/crs_master/crs_master.v
hdl/sync/sync.v
hdl/negedge_detector/negedge_detector.v
hdl/posedge_detector/posedge_detector.v
hdl/task_reg/task_reg.v
hdl/one_shot/one_shot.v
hdl/periodic_trigger_gen/periodic_trigger_gen.v
hdl/n_channel_mux/n_channel_mux.v
hdl/rev_num/rev_num.v
hdl/inc/trigger_src/trigger_src_inc.v
hdl/bundles/mDOM_trig_bundle/mDOM_trig_bundle_fan_in.v
hdl/bundles/mDOM_trig_bundle/mDOM_trig_bundle_inc.v
hdl/bundles/mDOM_wvb_conf_bundle/mDOM_wvb_conf_bundle_fan_in.v
hdl/bundles/mDOM_wvb_conf_bundle/mDOM_wvb_conf_bundle_inc.v
hdl/bundles/mDOM_bsum_bundle/mDOM_bsum_bundle_fan_in.v
hdl/bundles/mDOM_bsum_bundle/mDOM_bsum_bundle_inc.v
hdl/DDR3/DDR3_pg_transfer_mux.v
hdl/DDR3/DDR3_DPRAM_transfer.v
hdl/DDR3/DDR3_pg_transfer_ctrl.v"

if [ -n "$REV" ]; then
  SRC=$BUILD/rev
  for f in $RTL; do
    mkdir -p "$SRC/$(dirname "$f")"
    git -C "$REPO" show "$REV:$f" > "$SRC/$f"
  done
else
  SRC=$REPO
fi
H=$SRC/hdl

# the FMC glue of the top level, used verbatim by the testbench
sed -n '/^wire i_fmc_wen_s;/,/^wire fmc_cen_mux/p' "$H/mdommb_fw_rev1_top.v" > "$BUILD/fmc_glue_from_top.vh"
if ! grep -q '^wire fmc_cen_mux' "$BUILD/fmc_glue_from_top.vh"; then
  echo "FMC glue not found in $H/mdommb_fw_rev1_top.v" >&2
  exit 1
fi

PARAMS=
PLUSARGS=
for a in "$@"; do
  case "$a" in
    +*) PLUSARGS="$PLUSARGS $a" ;;
    *) PARAMS="$PARAMS -Pfmc_dpram_tb.$a" ;;
  esac
done

iverilog -g2005 -o "$BUILD/fmc_dpram_tb.vvp" $PARAMS \
  -I "$BUILD" -I "$H/rev_num" -I "$H/inc/trigger_src" \
  -I "$H/bundles/mDOM_trig_bundle" -I "$H/bundles/mDOM_wvb_conf_bundle" \
  -I "$H/bundles/mDOM_bsum_bundle" \
  "$SIM_DIR/fmc_dpram_tb.v" "$SIM_DIR/fmc_dpram_models.v" \
  "$H/xdom/xdom.v" "$H/crs_master/crs_master.v" "$H/sync/sync.v" \
  "$H/negedge_detector/negedge_detector.v" "$H/posedge_detector/posedge_detector.v" \
  "$H/task_reg/task_reg.v" "$H/one_shot/one_shot.v" \
  "$H/periodic_trigger_gen/periodic_trigger_gen.v" "$H/n_channel_mux/n_channel_mux.v" \
  "$H/bundles/mDOM_trig_bundle/mDOM_trig_bundle_fan_in.v" \
  "$H/bundles/mDOM_wvb_conf_bundle/mDOM_wvb_conf_bundle_fan_in.v" \
  "$H/bundles/mDOM_bsum_bundle/mDOM_bsum_bundle_fan_in.v" \
  "$H/DDR3/DDR3_pg_transfer_mux.v" "$H/DDR3/DDR3_DPRAM_transfer.v" \
  "$H/DDR3/DDR3_pg_transfer_ctrl.v"

echo "simulating ${REV:-working tree} in $BUILD"
cd "$BUILD" && vvp -n fmc_dpram_tb.vvp $PLUSARGS
