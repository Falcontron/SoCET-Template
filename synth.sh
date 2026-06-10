#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# synth.sh
# ============================================================
#
# This script runs the synthesis/reporting stage for the template.
#
# Current default flow:
#
#   rtl/counter.sv
#       -> sv2v SystemVerilog conversion
#       -> Yosys generic synthesis
#       -> Nangate45 / FreePDK45 Liberty-mapped synthesis
#       -> mapped Verilog + JSON netlist
#       -> utilization / area report
#       -> OpenSTA timing report using a basic SDC file
#       -> rough area/leakage power report
#
# The default target is intentionally simple because this repository is
# a CI/CD template. Larger SoCET repos can override the variables in
# config.env or provide SYNTH_CMD for a completely custom synthesis flow.
#
# ============================================================

if [ ! -f "./config.env" ]; then
    echo "ERROR: config.env not found" >&2
    exit 1
fi

source ./config.env

if [ "${SYNTH_ENABLED:-1}" != "1" ]; then
    echo "Synthesis disabled by config.env, skipping"
    exit 0
fi

if [ -n "${SYNTH_CMD:-}" ]; then
    echo "Running custom synthesis command"
    bash -lc "$SYNTH_CMD"
    exit 0
fi

check_tool() {
    local tool="$1"

    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "ERROR: $tool not found" >&2
        exit 1
    fi
}

check_file() {
    local file="$1"
    local description="$2"

    if [ ! -f "$file" ]; then
        echo "ERROR: $description not found: $file" >&2
        exit 1
    fi
}

check_tool sv2v
check_tool yosys
check_tool sta
check_tool python3

# ============================================================
# User-configurable synthesis variables
# ============================================================
#
# These defaults match the small counter example in this template repo.
# Future repos can override them in config.env.
#
# SYNTH_MODE:
#   smoke = synthesize the explicitly listed RTL sources
#   full  = synthesize RTL sources extracted from a FuseSoC .eda.yml file
#
# ============================================================

SYNTH_MODE="${SYNTH_MODE:-smoke}"
TOP_MODULE="${SYNTH_TOP:-counter}"
OUT_DIR="${SYNTH_OUT_DIR:-synth_out}"

LIBERTY_FILE="${SYNTH_LIBERTY:-flow/lib/NangateOpenCellLibrary_typical.lib}"
SDC_FILE="${SYNTH_SDC:-flow/constraints/counter.sdc}"
OPENSTA_SCRIPT="${SYNTH_OPENSTA_SCRIPT:-flow/scripts/opensta_counter.tcl}"

RTL_FILELIST="$OUT_DIR/rtl_files.f"
INCLUDE_DIR_FILELIST="$OUT_DIR/include_dirs.f"
CONVERTED_VERILOG="$OUT_DIR/converted.v"
YOSYS_SCRIPT="$OUT_DIR/synth.ys"
YOSYS_LOG="$OUT_DIR/synth.log"
MAPPED_NETLIST="$OUT_DIR/synth_mapped.v"
SYNTH_JSON="$OUT_DIR/synth.json"
UTIL_REPORT="$OUT_DIR/utilization.rpt"
AREA_REPORT="$OUT_DIR/area_report.txt"
TIMING_REPORT="$OUT_DIR/timing.rpt"
POWER_REPORT="$OUT_DIR/power.rpt"
OPENSTA_LOG="$OUT_DIR/opensta.log"

mkdir -p "$OUT_DIR"

echo "Starting synthesis"
echo "Mode: $SYNTH_MODE"
echo "Top module: $TOP_MODULE"
echo "Output directory: $OUT_DIR"
echo "Liberty file: $LIBERTY_FILE"
echo "SDC file: $SDC_FILE"

check_file "$LIBERTY_FILE" "Liberty file"
check_file "$SDC_FILE" "SDC timing constraints file"
check_file "$OPENSTA_SCRIPT" "OpenSTA script"

# ============================================================
# Build RTL filelist
# ============================================================

if [ "$SYNTH_MODE" = "smoke" ]; then
    echo "Running smoke synthesis file collection"

    if [ -z "${SYNTH_SRCS:-}" ]; then
        echo "ERROR: SYNTH_MODE=smoke but SYNTH_SRCS is empty" >&2
        exit 1
    fi

    : > "$RTL_FILELIST"
    : > "$INCLUDE_DIR_FILELIST"

    for src in ${SYNTH_SRCS}; do
        check_file "$src" "synthesis source"
        echo "$src" >> "$RTL_FILELIST"
    done

elif [ "$SYNTH_MODE" = "full" ]; then
    echo "Running full synthesis file collection"

    EDA_YML="${SYNTH_EDA_YML:-}"

    if [ -z "$EDA_YML" ]; then
        EDA_YML="$(find "${FUSESOC_BUILD_ROOT:-build_out}" -name "*.eda.yml" | head -n 1 || true)"
    fi

    if [ -z "$EDA_YML" ] || [ ! -f "$EDA_YML" ]; then
        echo "No .eda.yml found."
        echo "Running build first to generate FuseSoC metadata."
        ./build.sh
        EDA_YML="$(find "${FUSESOC_BUILD_ROOT:-build_out}" -name "*.eda.yml" | head -n 1 || true)"
    fi

    if [ -z "$EDA_YML" ] || [ ! -f "$EDA_YML" ]; then
        echo "ERROR: Could not find .eda.yml after build" >&2
        exit 1
    fi

    echo "Using EDA file: $EDA_YML"

    python3 - "$EDA_YML" "$RTL_FILELIST" "$INCLUDE_DIR_FILELIST" <<'PY'
import os
import sys
import yaml

eda_yml = sys.argv[1]
rtl_out_file = sys.argv[2]
inc_out_file = sys.argv[3]

eda_dir = os.path.dirname(os.path.abspath(eda_yml))

with open(eda_yml) as fp:
    eda = yaml.safe_load(fp)

files = []
inc_dirs = []

for item in eda.get("files", []):
    path = item.get("name", "")
    if not path:
        continue

    lower = path.lower()
    abs_path = os.path.abspath(os.path.join(eda_dir, path))

    if item.get("is_include_file", False):
        if os.path.exists(abs_path):
            inc_dir = os.path.dirname(abs_path)
            if inc_dir not in inc_dirs:
                inc_dirs.append(inc_dir)
        else:
            print(f"Warning: missing include file: {abs_path}")
        continue

    # Skip common simulation-only sources.
    if (
        ("tb" in lower and "btb" not in lower)
        or "verification" in lower
        or "uvm" in lower
        or "test" in lower
    ):
        continue

    if not (path.endswith(".sv") or path.endswith(".v")):
        continue

    if os.path.exists(abs_path):
        files.append(abs_path)
    else:
        print(f"Warning: missing source file: {abs_path}")

files = list(dict.fromkeys(files))
inc_dirs = list(dict.fromkeys(inc_dirs))

with open(rtl_out_file, "w") as fp:
    for f in files:
        fp.write(f + "\n")

with open(inc_out_file, "w") as fp:
    for d in inc_dirs:
        fp.write(d + "\n")

print(f"Wrote {len(files)} RTL files to {rtl_out_file}")
print(f"Wrote {len(inc_dirs)} include dirs to {inc_out_file}")
PY

else
    echo "ERROR: Unknown SYNTH_MODE='$SYNTH_MODE'. Use 'smoke' or 'full'." >&2
    exit 1
fi

if [ ! -s "$RTL_FILELIST" ]; then
    echo "ERROR: RTL filelist is empty" >&2
    exit 1
fi

echo "RTL filelist:"
cat "$RTL_FILELIST"

# ============================================================
# SystemVerilog to Verilog conversion
# ============================================================

SV2V_INCLUDE_ARGS=""

if [ -f "$INCLUDE_DIR_FILELIST" ]; then
    while read -r inc_dir; do
        [ -z "$inc_dir" ] && continue
        SV2V_INCLUDE_ARGS="$SV2V_INCLUDE_ARGS -I$inc_dir"
    done < "$INCLUDE_DIR_FILELIST"
fi

echo "Running sv2v"
sv2v -DNOIP -DSYNTHESIS -DSRAM $SV2V_INCLUDE_ARGS $(cat "$RTL_FILELIST") > "$CONVERTED_VERILOG"

# ============================================================
# Yosys library-mapped synthesis
# ============================================================
#
# The important mapping steps are:
#
#   dfflibmap -liberty <lib>
#   abc       -liberty <lib>
#
# dfflibmap maps sequential elements to cells from the Liberty file.
# abc maps combinational logic to cells from the Liberty file.
#
# ============================================================

echo "Writing Yosys script"

cat > "$YOSYS_SCRIPT" <<EOF
read_verilog $CONVERTED_VERILOG

hierarchy -check -top $TOP_MODULE

proc
opt
fsm
opt
memory
opt

techmap
opt

dfflibmap -liberty $LIBERTY_FILE
abc -liberty $LIBERTY_FILE

clean

write_verilog -noattr $MAPPED_NETLIST
write_json $SYNTH_JSON

tee -o $UTIL_REPORT stat -liberty $LIBERTY_FILE
EOF

echo "Running Yosys mapped synthesis"
yosys -l "$YOSYS_LOG" "$YOSYS_SCRIPT"

# Keep the old area_report.txt name for compatibility with any existing
# scripts or habits, but also write the clearer utilization.rpt name.
cp "$UTIL_REPORT" "$AREA_REPORT"

# ============================================================
# OpenSTA timing report
# ============================================================

echo "Running OpenSTA timing analysis"

export STA_TOP="$TOP_MODULE"
export STA_LIBERTY="$LIBERTY_FILE"
export STA_NETLIST="$MAPPED_NETLIST"
export STA_SDC="$SDC_FILE"
export STA_TIMING_REPORT="$TIMING_REPORT"

# Save both:
#   opensta.log = complete OpenSTA console log
#   timing.rpt  = timing report generated by the Tcl script
sta -exit "$OPENSTA_SCRIPT" | tee "$OPENSTA_LOG"

if [ ! -s "$TIMING_REPORT" ]; then
    echo "WARNING: OpenSTA did not produce a non-empty timing report."
    echo "See $OPENSTA_LOG for details."

    {
        echo "Timing report was not generated."
        echo "See $OPENSTA_LOG for OpenSTA output."
    } > "$TIMING_REPORT"
fi

# ============================================================
# Rough power report
# ============================================================
#
# This is not signoff power.
#
# With no VCD/SAIF switching activity, we cannot estimate meaningful
# dynamic power. However, the Liberty file contains per-cell leakage
# information, and the mapped netlist contains cell instance counts.
#
# This report therefore gives:
#
#   * mapped cell counts
#   * total cell area from Liberty
#   * total leakage power from Liberty
#
# That gives CI a stable numeric power/area artifact today, while leaving
# a clear path to add VCD/SAIF-based dynamic power later.
#
# ============================================================

echo "Generating rough area/leakage power report"

python3 - "$LIBERTY_FILE" "$MAPPED_NETLIST" "$POWER_REPORT" "$TOP_MODULE" <<'PY'
import re
import sys
from collections import Counter

liberty_path = sys.argv[1]
netlist_path = sys.argv[2]
report_path = sys.argv[3]
top_module = sys.argv[4]

with open(liberty_path, "r", errors="ignore") as fp:
    liberty = fp.read()

cell_info = {}

# Match one Liberty cell block at a time. This is intentionally simple,
# but works well for the Nangate45 Liberty file used by this template.
cell_pattern = re.compile(r"cell\s*\(([^)]+)\)\s*\{", re.MULTILINE)
matches = list(cell_pattern.finditer(liberty))

for idx, match in enumerate(matches):
    cell_name = match.group(1).strip()
    start = match.end()
    end = matches[idx + 1].start() if idx + 1 < len(matches) else len(liberty)
    block = liberty[start:end]

    area_match = re.search(r"\barea\s*:\s*([0-9.eE+-]+)\s*;", block)
    leakage_match = re.search(r"\bcell_leakage_power\s*:\s*([0-9.eE+-]+)\s*;", block)

    area = float(area_match.group(1)) if area_match else 0.0
    leakage = float(leakage_match.group(1)) if leakage_match else 0.0

    cell_info[cell_name] = {
        "area": area,
        "leakage": leakage,
    }

with open(netlist_path, "r", errors="ignore") as fp:
    netlist = fp.read()

counts = Counter()

# Yosys mapped Verilog typically emits instances like:
#
#   DFFR_X1 _123_ (
#   NAND2_X1 _456_ (
#
# Only count cell names that exist in the Liberty file.
instance_pattern = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_$]*)\s+(?:\\?[A-Za-z_.$][A-Za-z0-9_.$]*)\s*\(", re.MULTILINE)

for match in instance_pattern.finditer(netlist):
    cell_type = match.group(1)
    if cell_type in cell_info:
        counts[cell_type] += 1

total_area = 0.0
total_leakage = 0.0

for cell_type, count in counts.items():
    total_area += count * cell_info[cell_type]["area"]
    total_leakage += count * cell_info[cell_type]["leakage"]

with open(report_path, "w") as fp:
    fp.write("Basic power report\n")
    fp.write("==================\n\n")
    fp.write(f"Top module: {top_module}\n")
    fp.write(f"Liberty:    {liberty_path}\n")
    fp.write(f"Netlist:    {netlist_path}\n\n")

    fp.write("Report type\n")
    fp.write("-----------\n")
    fp.write("This is a rough Liberty/netlist-based report for CI visibility.\n")
    fp.write("No VCD/SAIF switching activity file was provided, so dynamic power is not estimated.\n")
    fp.write("The leakage values below come from cell_leakage_power in the Liberty file.\n\n")

    fp.write("Summary\n")
    fp.write("-------\n")
    fp.write(f"Mapped cell instances: {sum(counts.values())}\n")
    fp.write(f"Total cell area:       {total_area:.6f}\n")
    fp.write(f"Total leakage power:   {total_leakage:.12g}\n")
    fp.write("Leakage units:         Liberty library units\n\n")

    fp.write("Cell breakdown\n")
    fp.write("--------------\n")
    fp.write(f"{'Cell':<20} {'Count':>8} {'Area/Cell':>14} {'Leak/Cell':>16} {'Total Area':>14} {'Total Leak':>16}\n")
    fp.write(f"{'-' * 20} {'-' * 8} {'-' * 14} {'-' * 16} {'-' * 14} {'-' * 16}\n")

    for cell_type in sorted(counts):
        count = counts[cell_type]
        area = cell_info[cell_type]["area"]
        leakage = cell_info[cell_type]["leakage"]
        fp.write(
            f"{cell_type:<20} "
            f"{count:>8d} "
            f"{area:>14.6f} "
            f"{leakage:>16.8g} "
            f"{count * area:>14.6f} "
            f"{count * leakage:>16.8g}\n"
        )

    fp.write("\nNotes\n")
    fp.write("-----\n")
    fp.write("* This is not signoff power.\n")
    fp.write("* Dynamic/internal/switching power requires activity data such as VCD or SAIF.\n")
    fp.write("* This report is intended to make CI artifacts useful before activity-based power is added.\n")
PY

echo "Synthesis complete"
echo "Reports written to $OUT_DIR/"
echo
echo "Generated files:"
echo "  $YOSYS_LOG"
echo "  $MAPPED_NETLIST"
echo "  $SYNTH_JSON"
echo "  $UTIL_REPORT"
echo "  $AREA_REPORT"
echo "  $TIMING_REPORT"
echo "  $POWER_REPORT"
echo "  $OPENSTA_LOG"