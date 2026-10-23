#!/usr/bin/env bash
# Compile and run a module's directed testbench, then open the waveform in GTKWave.
#
# Usage: ./simulate.sh <module> [WIDTH]
#   ./simulate.sh barrel_shifter
#   ./simulate.sh logical_shift_unit 8
#
# Set NO_WAVE=1 to run the simulation without opening GTKWave.

set -euo pipefail

# Follow symlinks so the script also works when linked into a PATH folder,
# e.g. ln -s "$PWD/simulate.sh" ~/bin/simulate
SELF="${BASH_SOURCE[0]}"
while [ -L "$SELF" ]; do
    LINK="$(readlink "$SELF")"
    case "$LINK" in
        /*) SELF="$LINK" ;;
        *)  SELF="$(dirname "$SELF")/$LINK" ;;
    esac
done
ROOT="$(cd "$(dirname "$SELF")" && pwd)"

usage() {
    echo "Usage: $0 <module> [WIDTH]"
    echo
    echo "Modules:"
    for d in "$ROOT"/*/; do
        name="$(basename "$d")"
        [ -f "$d/${name}_directed_tb.v" ] && echo "  $name"
    done
    exit 1
}

[ $# -ge 1 ] && [ $# -le 2 ] || usage

MODULE="${1%/}"          # allow tab-completed "barrel_shifter/"
WIDTH="${2:-}"
DIR="$ROOT/$MODULE"
TB="${MODULE}_directed_tb"

if [ ! -f "$DIR/$MODULE.v" ] || [ ! -f "$DIR/$TB.v" ]; then
    echo "Error: unknown module '$MODULE'"
    echo
    usage
fi

if [ -n "$WIDTH" ] && ! [[ "$WIDTH" =~ ^[0-9]+$ && "$WIDTH" -ge 2 ]]; then
    echo "Error: WIDTH must be a number >= 2 (got '$WIDTH')"
    exit 1
fi

for tool in iverilog vvp; do
    command -v "$tool" >/dev/null || { echo "Error: '$tool' not found in PATH"; exit 1; }
done

cd "$DIR"

PARAMS=()
[ -n "$WIDTH" ] && PARAMS=(-P "$TB.WIDTH=$WIDTH")

echo "==> Compiling $MODULE${WIDTH:+ (WIDTH=$WIDTH)}"
iverilog ${PARAMS[@]+"${PARAMS[@]}"} -o "$TB.vvp" "$MODULE.v" "$TB.v"

echo "==> Simulating"
vvp "$TB.vvp"

if [ "${NO_WAVE:-0}" = "1" ]; then
    echo "==> Waveform written to $MODULE/$TB.vcd"
    exit 0
fi

if ! command -v gtkwave >/dev/null; then
    echo "==> GTKWave not found in PATH; waveform written to $MODULE/$TB.vcd"
    exit 0
fi

echo "==> Opening $MODULE/$TB.vcd in GTKWave"
gtkwave "$TB.vcd" >/dev/null 2>&1 &
