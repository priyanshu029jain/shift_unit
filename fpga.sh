#!/usr/bin/env bash
# FPGA analysis of a module with Vivado (fpga.tcl): synthesis, place and route,
# then the key utilization, timing and power numbers. The full reports are in
# <module>/fpga/.
#
# Usage: ./fpga.sh <module|all> [WIDTH] [PERIOD_ns] [part]
#   ./fpga.sh barrel_shifter
#   ./fpga.sh all 32 5 xc7z020clg400-1
#
# Vivado is found in this order:
#   1. $VIVADO, if set (path to vivado or vivado.bat)
#   2. vivado on PATH (Linux, or Git Bash on Windows)
#   3. under WSL, the newest C:\AMDDesignTools\*\Vivado or C:\Xilinx\*\Vivado install

set -euo pipefail

# Follow symlinks so the script also works when linked into a PATH folder,
# e.g. ln -s "$PWD/fpga.sh" ~/bin/fpga
SELF="${BASH_SOURCE[0]}"
while [ -L "$SELF" ]; do
    LINK="$(readlink "$SELF")"
    case "$LINK" in
        /*) SELF="$LINK" ;;
        *)  SELF="$(dirname "$SELF")/$LINK" ;;
    esac
done
ROOT="$(cd "$(dirname "$SELF")" && pwd)"

MODULES=(logical_shift_unit circular_shift_unit arithmetic_shift_unit barrel_shifter)

usage() {
    echo "Usage: $0 <module|all> [WIDTH] [PERIOD_ns] [part]" >&2
    echo >&2
    echo "Modules:" >&2
    printf '  %s\n' "${MODULES[@]}" >&2
    exit 1
}

[ $# -ge 1 ] && [ $# -le 4 ] || usage

TARGET="${1%/}"
WIDTH="${2:-16}"
PERIOD="${3:-10}"
PART="${4:-xc7a35tcpg236-1}"

if [ "$TARGET" = "all" ]; then
    TARGETS=("${MODULES[@]}")
elif [[ " ${MODULES[*]} " == *" $TARGET "* ]]; then
    TARGETS=("$TARGET")
else
    echo "Error: unknown module '$TARGET'" >&2
    echo >&2
    usage
fi

if ! [[ "$WIDTH" =~ ^[0-9]+$ && "$WIDTH" -ge 2 ]]; then
    echo "Error: WIDTH must be a number >= 2 (got '$WIDTH')" >&2
    exit 1
fi
if ! [[ "$PERIOD" =~ ^[0-9]*\.?[0-9]+$ ]] || awk -v p="$PERIOD" 'BEGIN { exit !(p <= 0) }'; then
    echo "Error: PERIOD must be a positive number of ns (got '$PERIOD')" >&2
    exit 1
fi

# ---- Find Vivado -------------------------------------------------------------

USE_CMD=0     # 1 = Windows vivado.bat started from WSL through cmd.exe
if [ -n "${VIVADO:-}" ]; then
    VIV="$VIVADO"
    [[ "$VIV" == *.bat ]] && grep -qi microsoft /proc/version 2>/dev/null && USE_CMD=1
elif command -v vivado >/dev/null; then
    VIV="vivado"
elif grep -qi microsoft /proc/version 2>/dev/null; then
    VIV="$(ls -d /mnt/c/AMDDesignTools/*/Vivado/bin/vivado.bat /mnt/c/Xilinx/Vivado/*/bin/vivado.bat 2>/dev/null | sort -V | tail -1 || true)"
    USE_CMD=1
else
    VIV=""
fi
if [ -z "$VIV" ]; then
    echo "Error: Vivado not found. Put it on PATH or set VIVADO=/path/to/vivado" >&2
    exit 1
fi

# ---- Run fpga.tcl ------------------------------------------------------------

echo "FPGA analysis: Vivado, part $PART, WIDTH = $WIDTH, clock period = $PERIOD ns (running...)"

# Vivado writes a .Xil/ scratch folder into the working directory (git-ignored)
cd "$ROOT"
ARGS=(-mode batch -nojournal -nolog -notrace)
if [ "$USE_CMD" = 1 ]; then
    OUT="$(cmd.exe /c "$(wslpath -w "$VIV")" "${ARGS[@]}" -source "$(wslpath -w "$ROOT/fpga.tcl")" \
           -tclargs "$TARGET" "$WIDTH" "$PERIOD" "$PART" 2>&1 | tr -d '\r' || true)"
else
    OUT="$("$VIV" "${ARGS[@]}" -source "$ROOT/fpga.tcl" \
           -tclargs "$TARGET" "$WIDTH" "$PERIOD" "$PART" 2>&1 || true)"
fi

# fpga.tcl reports bad arguments (e.g. a part that isn't installed) as "Error: ..."
if grep -q '^Error: ' <<<"$OUT" && ! grep -q "^${TARGETS[0]} " <<<"$OUT"; then
    grep -A2 '^Error: ' <<<"$OUT" >&2
    exit 1
fi

# ---- Summary -----------------------------------------------------------------

FAILED=0
for M in "${TARGETS[@]}"; do
    ROW="$(grep "^$M " <<<"$OUT" || true)"
    if [ -z "$ROW" ]; then
        echo "Error: Vivado did not finish $M. Last lines of its output:" >&2
        tail -20 <<<"$OUT" >&2
        exit 1
    fi
    read -r _ LUTS MUXF FFS PATH_NS LOGIC LEVELS FMAX SETUP HOLD TIMING P_DYN P_TOT FROM _ TO <<<"$ROW"

    # Device size, for utilization as a percentage
    UTIL="$ROOT/$M/fpga/${M}_${WIDTH}bit_utilization.rpt"
    AVAIL="$(awk -F'|' '/^\| Slice LUTs/ { gsub(/ /, "", $6); print $6; exit }' "$UTIL")"

    echo
    echo "$M"
    awk -v l="$LUTS" -v a="$AVAIL" -v m="$MUXF" -v f="$FFS" 'BEGIN {
        printf "  %-11s %d LUTs (%.2f%% of device), %d F7/F8 muxes  (+%d wrapper FFs)\n",
               "Resources", l, 100 * l / a, m, f
    }'
    printf '  %-11s %s ns reg-to-reg  (logic %s ns, %s levels),  Fmax %s MHz\n' \
           "Delay" "$PATH_NS" "$LOGIC" "$LEVELS" "$FMAX"
    printf '  %-11s %s  (setup slack %s ns, hold slack %s ns)\n' "Timing" "$TIMING" "$SETUP" "$HOLD"
    printf '  %-11s %s -> %s\n' "Critical" "$FROM" "$TO"
    printf '  %-11s %s mW dynamic,  %s mW total (incl. device static)\n' "Power" "$P_DYN" "$P_TOT"

    [ "$TIMING" = "MET" ] || FAILED=$((FAILED + 1))
done

[ "$FAILED" -eq 0 ]
