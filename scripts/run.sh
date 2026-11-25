#!/bin/bash
# Times every tool on every case, interleaved in one hyperfine run per size so background noise hits them equally.
# Waits for a quiet machine before each size: on macOS, AC power and a 1-minute load under $MAX_LOAD;
# on Linux, only the load. QUIET=0 skips the wait (CI runners can't be made quiet).
#
# Usage: REUBEN=/path/to/reuben [BASELINE=/path/to/older/reuben] [HASH_CASE=1] [QUIET=0] scripts/run.sh [sizes...]
# Results: results/latest/<size>.{json,txt}, conditions-<size>.txt and table.md.
set -euo pipefail
B=$(cd "$(dirname "$0")/.." && pwd)
cd "$B"
: "${REUBEN:?set REUBEN to the reuben binary to measure}"
MAX_LOAD=${MAX_LOAD:-3.5}
OUT=results/latest
HC=$B/.hugocache
rm -rf "$OUT"
mkdir -p "$OUT" "$HC"

quiet() {
  local l ac=1
  if [ "${QUIET:-1}" = 0 ]; then
    echo "quiet: check skipped (QUIET=0)"
    return
  fi
  for _ in $(seq 1 60); do
    if [ "$(uname -s)" = Darwin ]; then
      l=$(sysctl -n vm.loadavg | awk '{print $2}')
      ac=$(pmset -g batt | grep -c "AC Power" || true)
    else
      l=$(awk '{print $1}' /proc/loadavg)
    fi
    if [ "$ac" = 1 ] && awk "BEGIN{exit !($l < $MAX_LOAD)}"; then
      echo "quiet: load $l"
      return
    fi
    sleep 20
  done
  echo "WARNING: machine never got quiet (load $l, AC $ac)"
}

{
  echo "date: $(date -u +%Y-%m-%dT%H:%MZ)"
  if [ "$(uname -s)" = Darwin ]; then
    echo "machine: $(sysctl -n machdep.cpu.brand_string), $(($(sysctl -n hw.memsize) / 1073741824)) GiB, macOS $(sw_vers -productVersion)"
  else
    echo "machine: $(awk -F': ' '/^model name/ {print $2; exit}' /proc/cpuinfo), $(nproc) cores, $(awk '/^MemTotal/ {printf "%d", $2 / 1048576 + 0.5}' /proc/meminfo) GiB, $(. /etc/os-release && echo "$PRETTY_NAME")"
  fi
  [ "${GITHUB_ACTIONS:-}" = true ] && echo "runner: github-actions"
  echo "reuben: $("$REUBEN" --version)"
  [ -n "${BASELINE:-}" ] && echo "baseline: $("$BASELINE" --version)"
  echo "hugo: $(hugo version)"
  echo "zola: $(zola --version)"
  echo "hyperfine: $(hyperfine --version)"
} > "$OUT/versions.txt"

for N in ${*:-10 50 1000 10000}; do
  quiet | tee "$OUT/conditions-$N.txt"
  runs=15
  [ "$N" -ge 10000 ] && runs=5
  c=$B/cases
  cmds=()
  [ -n "${BASELINE:-}" ] && cmds+=(-n "reuben baseline, bare" "$BASELINE build --root $c/reuben-bare-$N")
  cmds+=(
    -n "reuben, bare" "$REUBEN build --root $c/reuben-bare-$N"
    -n "reuben, bare, footnote back-links off" "$REUBEN build --root $c/reuben-bare-noback-$N"
    -n "reuben, bare + checks" "$REUBEN build --root $c/reuben-bare-checks-$N"
    -n "hugo, bare, highlighting on" "hugo --quiet --source $c/hugo-bare-$N --cacheDir $HC"
    -n "hugo, bare, highlighting off" "hugo --quiet --source $c/hugo-nohl-$N --cacheDir $HC"
    -n "zola, bare, highlighting on" "zola --root $c/zola-bare-$N build"
    -n "zola, bare, highlighting off" "zola --root $c/zola-nohl-$N build"
  )
  prep="rm -rf $c/reuben-bare-$N/dist $c/reuben-bare-noback-$N/dist $c/reuben-bare-checks-$N/dist $c/hugo-bare-$N/public $c/hugo-nohl-$N/public $c/zola-bare-$N/public $c/zola-nohl-$N/public"
  if [ "${HASH_CASE:-0}" = 1 ]; then
    # Reuben only: older binaries reject the [assets] table.
    cmds+=(-n "reuben, bare, hashing on" "$REUBEN build --root $c/reuben-bare-hash-$N")
    prep="$prep $c/reuben-bare-hash-$N/dist"
  fi
  hyperfine -N --warmup 2 --runs "$runs" --export-json "$OUT/$N.json" \
    --prepare "$prep" \
    "${cmds[@]}" > "$OUT/$N.txt" 2>&1
  uptime >> "$OUT/conditions-$N.txt"
  # Each timed run deletes every case's output first, so build each case once more for the byte counts.
  for ((i = 2; i < ${#cmds[@]}; i += 3)); do
    eval "${cmds[$i]}" > /dev/null 2>&1 || true
  done
done

node scripts/summarize.mjs "$OUT" > "$OUT/table.md"
cat "$OUT/table.md"
