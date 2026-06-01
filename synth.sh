#!/usr/bin/env bash
set -euo pipefail

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

if ! command -v sv2v >/dev/null 2>&1; then
    echo "ERROR: sv2v not found" >&2
    exit 1
fi

if ! command -v yosys >/dev/null 2>&1; then
    echo "ERROR: yosys not found" >&2
    exit 1
fi

SYNTH_MODE="${SYNTH_MODE:-smoke}"
TOP_MODULE="${SYNTH_TOP:-socetlib_counter}"
OUT_DIR="${SYNTH_OUT_DIR:-synth_out}"

mkdir -p "$OUT_DIR"

echo "Starting synthesis"
echo "Mode: $SYNTH_MODE"
echo "Top module: $TOP_MODULE"
echo "Output directory: $OUT_DIR"

# ============================================================
# Smoke synthesis mode
# ============================================================
# This mode proves the open-source synthesis toolchain works:
#   FuseSoC build metadata -> sv2v -> Yosys -> reports
#
# It intentionally synthesizes a small known-good module instead of the full
# AFT chip, because full-chip AFT currently trips a Yosys/sv2v issue in the CSR logic.
# ============================================================

if [ "$SYNTH_MODE" = "smoke" ]; then
    echo "Running smoke synthesis"

    # Ensure FuseSoC generated sources exist.
    if [ ! -d "aft_out" ]; then
        echo "aft_out not found; running build first"
        ./build.sh
    fi

    SRC="$(find aft_out -name 'socetlib_counter.sv' | head -n 1 || true)"

    if [ -z "$SRC" ] || [ ! -f "$SRC" ]; then
        echo "Could not find socetlib_counter.sv; running build and trying again"
        ./build.sh
        SRC="$(find aft_out -name 'socetlib_counter.sv' | head -n 1 || true)"
    fi

    if [ -z "$SRC" ] || [ ! -f "$SRC" ]; then
        echo "ERROR: Could not find socetlib_counter.sv" >&2
        exit 1
    fi

    echo "Using source file: $SRC"

    echo "$SRC" > "$OUT_DIR/rtl_files.f"

    echo "Running sv2v"
    sv2v "$SRC" > "$OUT_DIR/converted.v"

    echo "Writing Yosys script"
    cat > "$OUT_DIR/synth.ys" <<EOF
read_verilog $OUT_DIR/converted.v
hierarchy -check -top $TOP_MODULE
proc
opt
fsm
opt
memory
opt
techmap
opt
stat
write_verilog $OUT_DIR/synth_netlist.v
EOF

    echo "Running Yosys"
    yosys -s "$OUT_DIR/synth.ys" | tee "$OUT_DIR/yosys.log"

    echo "Extracting area-style stats"
    grep -A80 "Printing statistics" "$OUT_DIR/yosys.log" > "$OUT_DIR/area_report.txt" || true

    echo "Smoke synthesis complete"
    echo "Reports written to $OUT_DIR/"
    exit 0
fi

# ============================================================
# Full synthesis mode
# ============================================================
# This attempts full-chip AFT synthesis using the FuseSoC .eda.yml.
# This path is experimental right now.
# ============================================================

if [ "$SYNTH_MODE" != "full" ]; then
    echo "ERROR: Unknown SYNTH_MODE='$SYNTH_MODE'. Use 'smoke' or 'full'." >&2
    exit 1
fi

echo "Running full-chip synthesis"

EDA_YML="${SYNTH_EDA_YML:-}"

if [ -z "$EDA_YML" ]; then
    EDA_YML="$(find aft_out -name "*.eda.yml" | head -n 1 || true)"
fi

if [ -z "$EDA_YML" ] || [ ! -f "$EDA_YML" ]; then
    echo "No .eda.yml found. Running build first to generate FuseSoC metadata."
    ./build.sh
    EDA_YML="$(find aft_out -name "*.eda.yml" | head -n 1 || true)"
fi

if [ -z "$EDA_YML" ] || [ ! -f "$EDA_YML" ]; then
    echo "ERROR: Could not find .eda.yml after build" >&2
    exit 1
fi

echo "Using EDA file: $EDA_YML"

python3 - "$EDA_YML" "$OUT_DIR/rtl_files.f" "$OUT_DIR/include_dirs.f" <<'PY'
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

    # Collect include directories from FuseSoC include files.
    if item.get("is_include_file", False):
        if os.path.exists(abs_path):
            inc_dir = os.path.dirname(abs_path)
            if inc_dir not in inc_dirs:
                inc_dirs.append(inc_dir)
        else:
            print(f"Warning: missing include file: {abs_path}")
        continue

    # Skip obvious non-synth / sim-only files.
    if (
        ("tb" in lower and "btb" not in lower)
        or "verification" in lower
        or "top_core" in lower
        or "sram_sim" in lower
        or "uvm" in lower
        or "test" in lower
    ):
        continue

    # Only source files for now.
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

if [ ! -s "$OUT_DIR/rtl_files.f" ]; then
    echo "ERROR: RTL filelist is empty" >&2
    exit 1
fi

echo "RTL filelist:"
cat "$OUT_DIR/rtl_files.f"

SV2V_INCLUDE_ARGS=""
while read -r inc_dir; do
    [ -z "$inc_dir" ] && continue
    SV2V_INCLUDE_ARGS="$SV2V_INCLUDE_ARGS -I$inc_dir"
done < "$OUT_DIR/include_dirs.f"

echo "Running sv2v"
sv2v -DNOIP -DSYNTHESIS -DSRAM $SV2V_INCLUDE_ARGS $(cat "$OUT_DIR/rtl_files.f") > "$OUT_DIR/converted.v"

echo "Writing Yosys script"
cat > "$OUT_DIR/synth.ys" <<EOF
read_verilog $OUT_DIR/converted.v
hierarchy -check -top $TOP_MODULE
proc
opt
fsm
opt
memory
opt
techmap
opt
stat
write_verilog $OUT_DIR/synth_netlist.v
EOF

echo "Running Yosys"
yosys -s "$OUT_DIR/synth.ys" | tee "$OUT_DIR/yosys.log"

echo "Extracting area-style stats"
grep -A80 "Printing statistics" "$OUT_DIR/yosys.log" > "$OUT_DIR/area_report.txt" || true

echo "Full-chip synthesis complete"
echo "Reports written to $OUT_DIR/"