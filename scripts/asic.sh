#!/usr/bin/env bash
# ASIC analysis of a module on sky130_fd_sc_hd: Yosys synthesis (area,
# equivalence check) followed by OpenSTA (timing, power). Prints only the key
# numbers; the full reports are in <module>/synth/ and <module>/sta/.
#
# Usage: ./run asic <module|all> [WIDTH] [PERIOD_ns]
#   ./run asic barrel_shifter
#   ./run asic all 32 5

set -euo pipefail

# Follow symlinks so the script also works when linked into a PATH folder,
# e.g. ln -s "$PWD/scripts/asic.sh" ~/bin/asic
SELF="${BASH_SOURCE[0]}"
while [ -L "$SELF" ]; do
    LINK="$(readlink "$SELF")"
    case "$LINK" in
        /*) SELF="$LINK" ;;
        *)  SELF="$(dirname "$SELF")/$LINK" ;;
    esac
done
ROOT="$(cd "$(dirname "$SELF")/.." && pwd)"   # scripts/ lives in the repo root

MODULES=(logical_shift_unit circular_shift_unit arithmetic_shift_unit barrel_shifter)

usage() {
    echo "Usage: ${RUN_CMD:-$0} <module|all> [WIDTH] [PERIOD_ns]" >&2
    echo >&2
    echo "Modules:" >&2
    printf '  %s\n' "${MODULES[@]}" >&2
    exit 1
}

[ $# -ge 1 ] && [ $# -le 3 ] || usage

TARGET="${1%/}"
WIDTH="${2:-16}"
PERIOD="${3:-10}"

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

for tool in yosys sta; do
    command -v "$tool" >/dev/null || { echo "Error: '$tool' not found in PATH" >&2; exit 1; }
done

echo "ASIC analysis: sky130_fd_sc_hd (tt, 25 C, 1.8 V), WIDTH = $WIDTH, clock period = $PERIOD ns"

FAILED=0
for M in "${TARGETS[@]}"; do
    # ---- Synthesis: cells, area, equivalence
    if ! SYN="$(yosys -q -c "$ROOT/synthesis.tcl" -- "$M" "$WIDTH" 2>&1)"; then
        if ! grep -q "^$M " <<<"$SYN"; then   # crashed before the summary
            echo "$SYN" >&2
            exit 1
        fi
    fi
    read -r _ CELLS AREA EQUIV <<<"$(grep "^$M " <<<"$SYN")"

    # ---- Timing and power (OpenSTA always exits 0, so check its output)
    STA_OUT="$(MODULE="$M" WIDTH="$WIDTH" PERIOD="$PERIOD" sta -no_splash -exit "$ROOT/STA.tcl" 2>/dev/null)"
    ROW="$(grep "^$M " <<<"$STA_OUT" || true)"
    if [ -z "$ROW" ]; then
        echo "$STA_OUT" >&2
        exit 1
    fi
    read -r _ MAXD FMAX MIND SLACK DRV TIMING START _ END <<<"$ROW"

    # Power report "Total" row: internal, switching, leakage, total (W)
    PWR="$ROOT/$M/sta/${M}_${WIDTH}bit_power.rpt"
    read -r _ P_INT P_SW P_LEAK P_TOT _ <<<"$(grep '^Total ' "$PWR")"

    echo
    echo "$M"
    printf '  %-12s %.2f um^2  (%d cells)\n' "Area" "$AREA" "$CELLS"
    printf '  %-12s %s ns max  (Fmax %s MHz),  %s ns min\n' "Delay" "$MAXD" "$FMAX" "$MIND"
    printf '  %-12s %s  (slack %s ns),  transition %s\n' "Timing" "$TIMING" "$SLACK" "$DRV"
    printf '  %-12s %s -> %s\n' "Critical" "$START" "$END"
    awk -v t="$P_TOT" -v s="$P_SW" -v i="$P_INT" -v l="$P_LEAK" -v p="$PERIOD" 'BEGIN {
        printf "  %-12s %.2f uW  (switching %.2f uW, internal %.2f uW, leakage %.4f uW) at %s ns\n",
               "Power", t * 1e6, s * 1e6, i * 1e6, l * 1e6, p
    }'
    printf '  %-12s %s\n' "Equivalence" "$EQUIV"

    if [ "$EQUIV" != "PASS" ] || [ "$TIMING" != "MET" ] || [ "$DRV" != "OK" ]; then
        FAILED=$((FAILED + 1))
    fi
done

[ "$FAILED" -eq 0 ]
