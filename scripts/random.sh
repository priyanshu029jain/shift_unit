#!/usr/bin/env bash
# Compile and run a module's random self-checking testbench and print only
# the result: passed/total and the pass percentage.
#
# Usage: ./run random <module> [WIDTH] [NUM_TESTS]
#   ./run random barrel_shifter
#   ./run random logical_shift_unit 32 5000

set -euo pipefail

# Follow symlinks so the script also works when linked into a PATH folder,
# e.g. ln -s "$PWD/scripts/random.sh" ~/bin/random
SELF="${BASH_SOURCE[0]}"
while [ -L "$SELF" ]; do
    LINK="$(readlink "$SELF")"
    case "$LINK" in
        /*) SELF="$LINK" ;;
        *)  SELF="$(dirname "$SELF")/$LINK" ;;
    esac
done
ROOT="$(cd "$(dirname "$SELF")/.." && pwd)"   # scripts/ lives in the repo root

usage() {
    echo "Usage: ${RUN_CMD:-$0} <module> [WIDTH] [NUM_TESTS]" >&2
    echo >&2
    echo "Modules:" >&2
    for d in "$ROOT"/*/; do
        name="$(basename "$d")"
        [ -f "$d/${name}_random_tb.v" ] && echo "  $name" >&2
    done
    exit 1
}

[ $# -ge 1 ] && [ $# -le 3 ] || usage

MODULE="${1%/}"          # allow tab-completed "barrel_shifter/"
WIDTH="${2:-}"
NUM_TESTS="${3:-}"
DIR="$ROOT/$MODULE"
TB="${MODULE}_random_tb"

if [ ! -f "$DIR/$MODULE.v" ] || [ ! -f "$DIR/$TB.v" ]; then
    echo "Error: unknown module '$MODULE'" >&2
    echo >&2
    usage
fi

if [ -n "$WIDTH" ] && ! [[ "$WIDTH" =~ ^[0-9]+$ && "$WIDTH" -ge 2 ]]; then
    echo "Error: WIDTH must be a number >= 2 (got '$WIDTH')" >&2
    exit 1
fi

if [ -n "$NUM_TESTS" ] && ! [[ "$NUM_TESTS" =~ ^[0-9]+$ && "$NUM_TESTS" -ge 1 ]]; then
    echo "Error: NUM_TESTS must be a number >= 1 (got '$NUM_TESTS')" >&2
    exit 1
fi

for tool in iverilog vvp; do
    command -v "$tool" >/dev/null || { echo "Error: '$tool' not found in PATH" >&2; exit 1; }
done

cd "$DIR"

PARAMS=()
[ -n "$WIDTH" ]     && PARAMS+=(-P "$TB.WIDTH=$WIDTH")
[ -n "$NUM_TESTS" ] && PARAMS+=(-P "$TB.NUM_TESTS=$NUM_TESTS")

# Compiler messages are only shown if compilation fails
if ! LOG="$(iverilog ${PARAMS[@]+"${PARAMS[@]}"} -o "$TB.vvp" "$MODULE.v" "$TB.v" 2>&1)"; then
    echo "$LOG" >&2
    exit 1
fi

# The testbench ends with "ALL <n> TESTS PASSED ..." or "<f> OF <n> TESTS FAILED ..."
RESULT="$(vvp "$TB.vvp" 2>&1 | grep -E 'TESTS (PASSED|FAILED)' || true)"

if [[ "$RESULT" =~ ^ALL\ ([0-9]+)\ TESTS\ PASSED ]]; then
    TOTAL="${BASH_REMATCH[1]}"
    FAILED=0
elif [[ "$RESULT" =~ ^([0-9]+)\ OF\ ([0-9]+)\ TESTS\ FAILED ]]; then
    FAILED="${BASH_REMATCH[1]}"
    TOTAL="${BASH_REMATCH[2]}"
else
    echo "Error: simulation did not report a result" >&2
    exit 1
fi

PASSED=$((TOTAL - FAILED))
awk -v p="$PASSED" -v t="$TOTAL" 'BEGIN { printf "%d/%d passed (%.2f%%)\n", p, t, 100 * p / t }'

[ "$FAILED" -eq 0 ]
