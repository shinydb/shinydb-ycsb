#!/bin/bash
set -eo pipefail

# ─────────────────────────────────────────────────────────
# ShinyDB YCSB Benchmark Suite — Run All Workloads
# Generates a Markdown report with results from each
# standard YCSB workload (A–F).
# ─────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY="${SCRIPT_DIR}/zig-out/bin/shinydb-ycsb"
RESULTS_DIR="${SCRIPT_DIR}/benchmark_results"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
REPORT="${RESULTS_DIR}/benchmark_report_${TIMESTAMP}.md"

# CLI overrides — forward any extra args (e.g. --host=… --record_count=…)
EXTRA_ARGS=("$@")

mkdir -p "$RESULTS_DIR"

# ── Check binary exists ──────────────────────────────────
if [[ ! -x "$BINARY" ]]; then
    echo "Error: Binary not found at $BINARY"
    echo "Run 'zig build' first."
    exit 1
fi

# ── Workload metadata (bash 3.2 compatible) ─────────────
wl_name() {
    case "$1" in
        a) echo "Update Heavy" ;;
        b) echo "Read Mostly" ;;
        c) echo "Read Only" ;;
        d) echo "Read Latest" ;;
        e) echo "Short Ranges" ;;
        f) echo "Read-Modify-Write" ;;
    esac
}
wl_mix() {
    case "$1" in
        a) echo "50% reads / 50% updates" ;;
        b) echo "95% reads / 5% updates" ;;
        c) echo "100% reads" ;;
        d) echo "95% reads / 5% inserts" ;;
        e) echo "95% scans / 5% inserts" ;;
        f) echo "50% reads / 50% RMW" ;;
    esac
}

workloads=(a b c d e f)
# Track per-workload status in parallel arrays
wl_statuses=()

# ── Helper: parse a YCSB key from output ────────────────
# Usage: parse_ycsb <file> <section> <metric>
# Returns the numeric value or "N/A"
parse_ycsb() {
    local file="$1" section="$2" metric="$3"
    local val
    val=$(grep "^\[${section}\], ${metric}," "$file" 2>/dev/null | head -1 | awk -F', ' '{print $NF}' | tr -d '[:space:]')
    if [[ -z "$val" ]]; then echo "N/A"; else echo "$val"; fi
}

# ── Start report ────────────────────────────────────────
cat > "$REPORT" <<EOF
# ShinyDB YCSB Benchmark Report

- **Date:** $(date +"%Y-%m-%d %H:%M:%S")
- **Host:** $(hostname)
- **OS:** $(uname -s) $(uname -r) ($(uname -m))
- **Zig:** $(zig version 2>/dev/null || echo "unknown")
- **Binary:** \`${BINARY}\`
- **Extra args:** ${EXTRA_ARGS[*]:-_(none)_}

---

## Summary

| Workload | Description | Mix | Ops | Throughput (ops/s) | Avg Latency (µs) | P99 (µs) | P99.9 (µs) | Errors |
|----------|-------------|-----|----:|-------------------:|------------------:|---------:|------------:|-------:|
EOF

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║   ShinyDB YCSB Benchmark Suite                          ║"
echo "║   $(date +"%Y-%m-%d %H:%M:%S")                                    ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# ── Run each workload ───────────────────────────────────
for wl in "${workloads[@]}"; do
    wl_upper=$(echo "$wl" | tr '[:lower:]' '[:upper:]')
    raw_file="${RESULTS_DIR}/workload_${wl}_${TIMESTAMP}.txt"
    ycsb_file="${RESULTS_DIR}/workload_${wl}_${TIMESTAMP}_ycsb.txt"
    name=$(wl_name "$wl")
    mix=$(wl_mix "$wl")

    echo "▶ Workload ${wl_upper} — ${name} (${mix})"

    # Run with YCSB export format so we get parseable output
    local_status="OK"
    if "$BINARY" "workload-${wl}" --export_format=ycsb ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"} > "$raw_file" 2>&1; then
        echo "  ✓ Completed"
    else
        local_status="FAIL"
        echo "  ✗ Failed (exit $?)"
    fi
    wl_statuses+=("$local_status")

    # The YCSB-formatted lines are in the raw output (stdout + stderr)
    grep '^\[' "$raw_file" > "$ycsb_file" 2>/dev/null || true

    # ── Parse results ──
    ops=$(parse_ycsb "$ycsb_file" "OVERALL" "Operations")
    throughput=$(parse_ycsb "$ycsb_file" "OVERALL" "Throughput(ops/sec)")
    avg_lat=$(parse_ycsb "$ycsb_file" "OVERALL" "AverageLatency(us)")
    p99=$(parse_ycsb "$ycsb_file" "OVERALL" "99thPercentileLatency(us)")
    p999=$(parse_ycsb "$ycsb_file" "OVERALL" "99.9thPercentileLatency(us)")
    err_rate=$(parse_ycsb "$ycsb_file" "OVERALL" "ErrorRate(%)")

    # Summary row
    cat >> "$REPORT" <<EOF
| ${wl_upper} | ${name} | ${mix} | ${ops} | ${throughput} | ${avg_lat} | ${p99} | ${p999} | ${err_rate}% |
EOF

    echo "    ops=${ops}  throughput=${throughput} ops/s  avg=${avg_lat} µs  p99=${p99} µs"
    echo ""
done

# ── Detailed per-workload sections ──────────────────────
cat >> "$REPORT" <<'EOF'

---

## Detailed Results
EOF

idx=0
for wl in "${workloads[@]}"; do
    wl_upper=$(echo "$wl" | tr '[:lower:]' '[:upper:]')
    ycsb_file="${RESULTS_DIR}/workload_${wl}_${TIMESTAMP}_ycsb.txt"
    raw_file="${RESULTS_DIR}/workload_${wl}_${TIMESTAMP}.txt"
    name=$(wl_name "$wl")
    mix=$(wl_mix "$wl")
    status="${wl_statuses[$idx]}"
    idx=$((idx + 1))

    cat >> "$REPORT" <<EOF

### Workload ${wl_upper} — ${name}

> **Operation mix:** ${mix}
> **Status:** ${status}

EOF

    if [[ "$status" == "FAIL" ]]; then
        cat >> "$REPORT" <<EOF
\`\`\`
$(tail -20 "$raw_file" 2>/dev/null || echo "(no output)")
\`\`\`

EOF
        continue
    fi

    # Overall metrics table
    ops=$(parse_ycsb "$ycsb_file" "OVERALL" "Operations")
    success=$(parse_ycsb "$ycsb_file" "OVERALL" "SuccessfulOperations")
    failed=$(parse_ycsb "$ycsb_file" "OVERALL" "FailedOperations")
    throughput=$(parse_ycsb "$ycsb_file" "OVERALL" "Throughput(ops/sec)")
    runtime=$(parse_ycsb "$ycsb_file" "OVERALL" "RunTime(ms)")
    err_rate=$(parse_ycsb "$ycsb_file" "OVERALL" "ErrorRate(%)")

    avg_lat=$(parse_ycsb "$ycsb_file" "OVERALL" "AverageLatency(us)")
    min_lat=$(parse_ycsb "$ycsb_file" "OVERALL" "MinLatency(us)")
    max_lat=$(parse_ycsb "$ycsb_file" "OVERALL" "MaxLatency(us)")
    p50=$(parse_ycsb "$ycsb_file" "OVERALL" "50thPercentileLatency(us)")
    p95=$(parse_ycsb "$ycsb_file" "OVERALL" "95thPercentileLatency(us)")
    p99=$(parse_ycsb "$ycsb_file" "OVERALL" "99thPercentileLatency(us)")
    p999=$(parse_ycsb "$ycsb_file" "OVERALL" "99.9thPercentileLatency(us)")

    cat >> "$REPORT" <<EOF
| Metric | Value |
|--------|------:|
| Runtime (ms) | ${runtime} |
| Total Operations | ${ops} |
| Successful | ${success} |
| Failed | ${failed} |
| Error Rate (%) | ${err_rate} |
| **Throughput (ops/s)** | **${throughput}** |

#### Latency Distribution (µs)

| Metric | Value |
|--------|------:|
| Min | ${min_lat} |
| Average | ${avg_lat} |
| P50 (median) | ${p50} |
| P95 | ${p95} |
| P99 | ${p99} |
| **P99.9** | **${p999}** |
| Max | ${max_lat} |

EOF

    # Per-operation breakdown (if present)
    op_sections=$(grep '^\[' "$ycsb_file" 2>/dev/null | awk -F'], ' '{print $1}' | tr -d '[' | sort -u | grep -v 'OVERALL\|HISTOGRAM' || true)
    if [[ -n "$op_sections" ]]; then
        cat >> "$REPORT" <<'EOF'
#### Per-Operation Breakdown

| Operation | Ops | Avg (µs) | P50 (µs) | P95 (µs) | P99 (µs) | P99.9 (µs) |
|-----------|----:|---------:|---------:|---------:|---------:|-----------:|
EOF
        while IFS= read -r section; do
            s_ops=$(parse_ycsb "$ycsb_file" "$section" "Operations")
            s_avg=$(parse_ycsb "$ycsb_file" "$section" "AverageLatency(us)")
            s_p50=$(parse_ycsb "$ycsb_file" "$section" "50thPercentileLatency(us)")
            s_p95=$(parse_ycsb "$ycsb_file" "$section" "95thPercentileLatency(us)")
            s_p99=$(parse_ycsb "$ycsb_file" "$section" "99thPercentileLatency(us)")
            s_p999=$(parse_ycsb "$ycsb_file" "$section" "99.9thPercentileLatency(us)")
            echo "| ${section} | ${s_ops} | ${s_avg} | ${s_p50} | ${s_p95} | ${s_p99} | ${s_p999} |" >> "$REPORT"
        done <<< "$op_sections"
        echo "" >> "$REPORT"
    fi

    # Histogram (if present)
    hist_lines=$(grep '^\[HISTOGRAM\]' "$ycsb_file" 2>/dev/null || true)
    if [[ -n "$hist_lines" ]]; then
        cat >> "$REPORT" <<'EOF'
<details>
<summary>Latency Histogram</summary>

| Bucket | Count |
|--------|------:|
EOF
        while IFS= read -r line; do
            bucket=$(echo "$line" | awk -F', ' '{print $2}')
            count=$(echo "$line" | awk -F', ' '{print $3}')
            echo "| ${bucket} | ${count} |" >> "$REPORT"
        done <<< "$hist_lines"
        echo "" >> "$REPORT"
        echo "</details>" >> "$REPORT"
        echo "" >> "$REPORT"
    fi
done

# ── Footer ──────────────────────────────────────────────
cat >> "$REPORT" <<EOF

---

## Environment

| Property | Value |
|----------|-------|
| Date | $(date +"%Y-%m-%d %H:%M:%S") |
| Hostname | $(hostname) |
| OS | $(uname -s) $(uname -r) |
| Architecture | $(uname -m) |
| CPU | $(sysctl -n machdep.cpu.brand_string 2>/dev/null || grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs || echo "unknown") |
| Cores | $(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo "unknown") |
| Memory | $(( $(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1073741824 )) GB |
| Zig Version | $(zig version 2>/dev/null || echo "unknown") |

---

*Generated by \`run_all_workloads.sh\` — ShinyDB YCSB Benchmark Suite*
EOF

echo "═══════════════════════════════════════════════════════════"
echo "Report generated: ${REPORT}"
echo "Raw results in:   ${RESULTS_DIR}/"
echo "═══════════════════════════════════════════════════════════"