# ShinyDB YCSB Benchmark Report

| Property | Value |
|----------|-------|
| OS | macos (aarch64) |
| Zig | 0.16.0-dev.2565+684032671 |
| Target | 127.0.0.1:23469 |
| Record Count | 10000 |
| Operation Count | 10000 |
| Document Size | 1024 bytes |
| Warmup Ops | 100 |
| Scan Length | 10 |
| Suite Duration | 5.78 s |

---

## Summary

| Workload | Description | Mix | Ops | Throughput (ops/s) | Avg Latency (µs) | P99 (µs) | P99.9 (µs) | Errors |
|----------|-------------|-----|----:|-------------------:|------------------:|---------:|------------:|-------:|
| A | Update Heavy | 50R/50U | 10000 | 23310.02 | 42.69 | 64 | 162 | 0.0000% |
| B | Read Mostly | 95R/5U | 10000 | 23923.44 | 41.75 | 68 | 140 | 0.0000% |
| C | Read Only | 100R | 10000 | 24390.24 | 40.85 | 55 | 75 | 0.0000% |
| D | Read Latest | 95R/5I | 10000 | 22271.71 | 44.76 | 212 | 300 | 0.0000% |
| E | Short Ranges | 95S/5I | 10000 | 18348.62 | 54.36 | 73 | 230 | 0.0000% |
| F | Read-Modify-Write | 50R/50RMW | 10000 | 15847.86 | 63.00 | 108 | 131 | 0.0000% |

---

## Detailed Results

### Workload A — Update Heavy

> **Operation mix:** 50R/50U  
> **Status:** OK

| Metric | Value |
|--------|------:|
| Runtime (ms) | 429 |
| Total Operations | 10000 |
| Successful | 10000 |
| Failed | 0 |
| Error Rate (%) | 0.0000 |
| **Throughput (ops/s)** | **23310.02** |

#### Latency Distribution (µs)

| Metric | Value |
|--------|------:|
| Min | 29 |
| Average | 42.69 |
| P50 (median) | 42 |
| P95 | 49 |
| P99 | 64 |
| **P99.9** | **162** |
| Max | 1100 |

#### Per-Operation Breakdown

| Operation | Ops | Avg (µs) | P50 (µs) | P95 (µs) | P99 (µs) | P99.9 (µs) |
|-----------|----:|---------:|---------:|---------:|---------:|-----------:|
| READ | 4992 | 41.31 | 40 | 47 | 60 | 145 |
| UPDATE | 5008 | 44.07 | 42 | 50 | 67 | 233 |


### Workload B — Read Mostly

> **Operation mix:** 95R/5U  
> **Status:** OK

| Metric | Value |
|--------|------:|
| Runtime (ms) | 418 |
| Total Operations | 10000 |
| Successful | 10000 |
| Failed | 0 |
| Error Rate (%) | 0.0000 |
| **Throughput (ops/s)** | **23923.44** |

#### Latency Distribution (µs)

| Metric | Value |
|--------|------:|
| Min | 24 |
| Average | 41.75 |
| P50 (median) | 40 |
| P95 | 48 |
| P99 | 68 |
| **P99.9** | **140** |
| Max | 245 |

#### Per-Operation Breakdown

| Operation | Ops | Avg (µs) | P50 (µs) | P95 (µs) | P99 (µs) | P99.9 (µs) |
|-----------|----:|---------:|---------:|---------:|---------:|-----------:|
| READ | 9500 | 41.59 | 40 | 48 | 68 | 140 |
| UPDATE | 500 | 44.75 | 43 | 52 | 86 | 245 |


### Workload C — Read Only

> **Operation mix:** 100R  
> **Status:** OK

| Metric | Value |
|--------|------:|
| Runtime (ms) | 410 |
| Total Operations | 10000 |
| Successful | 10000 |
| Failed | 0 |
| Error Rate (%) | 0.0000 |
| **Throughput (ops/s)** | **24390.24** |

#### Latency Distribution (µs)

| Metric | Value |
|--------|------:|
| Min | 30 |
| Average | 40.85 |
| P50 (median) | 40 |
| P95 | 46 |
| P99 | 55 |
| **P99.9** | **75** |
| Max | 97 |

#### Per-Operation Breakdown

| Operation | Ops | Avg (µs) | P50 (µs) | P95 (µs) | P99 (µs) | P99.9 (µs) |
|-----------|----:|---------:|---------:|---------:|---------:|-----------:|
| READ | 10000 | 40.85 | 40 | 46 | 55 | 75 |


### Workload D — Read Latest

> **Operation mix:** 95R/5I  
> **Status:** OK

| Metric | Value |
|--------|------:|
| Runtime (ms) | 449 |
| Total Operations | 10000 |
| Successful | 10000 |
| Failed | 0 |
| Error Rate (%) | 0.0000 |
| **Throughput (ops/s)** | **22271.71** |

#### Latency Distribution (µs)

| Metric | Value |
|--------|------:|
| Min | 24 |
| Average | 44.76 |
| P50 (median) | 33 |
| P95 | 65 |
| P99 | 212 |
| **P99.9** | **300** |
| Max | 24125 |

#### Per-Operation Breakdown

| Operation | Ops | Avg (µs) | P50 (µs) | P95 (µs) | P99 (µs) | P99.9 (µs) |
|-----------|----:|---------:|---------:|---------:|---------:|-----------:|
| READ | 9519 | 33.82 | 33 | 39 | 46 | 94 |
| INSERT | 481 | 261.37 | 204 | 262 | 365 | 24125 |


### Workload E — Short Ranges

> **Operation mix:** 95S/5I  
> **Status:** OK

| Metric | Value |
|--------|------:|
| Runtime (ms) | 545 |
| Total Operations | 10000 |
| Successful | 10000 |
| Failed | 0 |
| Error Rate (%) | 0.0000 |
| **Throughput (ops/s)** | **18348.62** |

#### Latency Distribution (µs)

| Metric | Value |
|--------|------:|
| Min | 43 |
| Average | 54.36 |
| P50 (median) | 53 |
| P95 | 61 |
| P99 | 73 |
| **P99.9** | **230** |
| Max | 593 |

#### Per-Operation Breakdown

| Operation | Ops | Avg (µs) | P50 (µs) | P95 (µs) | P99 (µs) | P99.9 (µs) |
|-----------|----:|---------:|---------:|---------:|---------:|-----------:|
| INSERT | 494 | 67.04 | 53 | 166 | 262 | 593 |
| SCAN | 9506 | 53.71 | 53 | 61 | 68 | 117 |


### Workload F — Read-Modify-Write

> **Operation mix:** 50R/50RMW  
> **Status:** OK

| Metric | Value |
|--------|------:|
| Runtime (ms) | 631 |
| Total Operations | 10000 |
| Successful | 10000 |
| Failed | 0 |
| Error Rate (%) | 0.0000 |
| **Throughput (ops/s)** | **15847.86** |

#### Latency Distribution (µs)

| Metric | Value |
|--------|------:|
| Min | 30 |
| Average | 63.00 |
| P50 (median) | 72 |
| P95 | 92 |
| P99 | 108 |
| **P99.9** | **131** |
| Max | 413 |

#### Per-Operation Breakdown

| Operation | Ops | Avg (µs) | P50 (µs) | P95 (µs) | P99 (µs) | P99.9 (µs) |
|-----------|----:|---------:|---------:|---------:|---------:|-----------:|
| READ | 4987 | 41.53 | 40 | 48 | 63 | 88 |
| READ-MODIFY-WRITE | 5013 | 84.37 | 83 | 97 | 113 | 132 |


---

*Generated by `shinydb-ycsb workload-all` — ShinyDB YCSB Benchmark Suite*
