# ShinyDB YCSB Benchmark Report

| Property | Value |
|----------|-------|
| OS | macos (aarch64) |
| Zig | 0.16.0-dev.2565+684032671 |
| Target | 127.0.0.1:23469 |
| Record Count | 100000 |
| Operation Count | 100000 |
| Document Size | 1024 bytes |
| Warmup Ops | 100 |
| Scan Length | 10 |
| Suite Duration | 70.36 s |

---

## Summary

| Workload | Description | Mix | Ops | Throughput (ops/s) | Avg Latency (µs) | P99 (µs) | P99.9 (µs) | Errors |
|----------|-------------|-----|----:|-------------------:|------------------:|---------:|------------:|-------:|
| A | Update Heavy | 50R/50U | 100000 | 23386.34 | 42.65 | 59 | 80 | 0.0000% |
| B | Read Mostly | 95R/5U | 100000 | 23980.82 | 41.59 | 57 | 77 | 0.0000% |
| C | Read Only | 100R | 100000 | 24032.68 | 41.51 | 57 | 78 | 0.0000% |
| D | Read Latest | 95R/5I | 100000 | 6545.36 | 152.69 | 1658 | 1719 | 0.0000% |
| E | Short Ranges | 95S/5I | 100000 | 17044.49 | 58.58 | 113 | 155 | 0.0000% |
| F | Read-Modify-Write | 50R/50RMW | 100000 | 15248.55 | 65.48 | 230 | 342 | 0.0000% |

---

## Detailed Results

### Workload A — Update Heavy

> **Operation mix:** 50R/50U  
> **Status:** OK

| Metric | Value |
|--------|------:|
| Runtime (ms) | 4276 |
| Total Operations | 100000 |
| Successful | 100000 |
| Failed | 0 |
| Error Rate (%) | 0.0000 |
| **Throughput (ops/s)** | **23386.34** |

#### Latency Distribution (µs)

| Metric | Value |
|--------|------:|
| Min | 29 |
| Average | 42.65 |
| P50 (median) | 42 |
| P95 | 49 |
| P99 | 59 |
| **P99.9** | **80** |
| Max | 184 |

#### Per-Operation Breakdown

| Operation | Ops | Avg (µs) | P50 (µs) | P95 (µs) | P99 (µs) | P99.9 (µs) |
|-----------|----:|---------:|---------:|---------:|---------:|-----------:|
| READ | 50064 | 41.51 | 40 | 47 | 57 | 78 |
| UPDATE | 49936 | 43.80 | 43 | 50 | 61 | 81 |


### Workload B — Read Mostly

> **Operation mix:** 95R/5U  
> **Status:** OK

| Metric | Value |
|--------|------:|
| Runtime (ms) | 4170 |
| Total Operations | 100000 |
| Successful | 100000 |
| Failed | 0 |
| Error Rate (%) | 0.0000 |
| **Throughput (ops/s)** | **23980.82** |

#### Latency Distribution (µs)

| Metric | Value |
|--------|------:|
| Min | 26 |
| Average | 41.59 |
| P50 (median) | 41 |
| P95 | 47 |
| P99 | 57 |
| **P99.9** | **77** |
| Max | 118 |

#### Per-Operation Breakdown

| Operation | Ops | Avg (µs) | P50 (µs) | P95 (µs) | P99 (µs) | P99.9 (µs) |
|-----------|----:|---------:|---------:|---------:|---------:|-----------:|
| READ | 95017 | 41.45 | 41 | 47 | 57 | 76 |
| UPDATE | 4983 | 44.41 | 43 | 51 | 60 | 87 |


### Workload C — Read Only

> **Operation mix:** 100R  
> **Status:** OK

| Metric | Value |
|--------|------:|
| Runtime (ms) | 4161 |
| Total Operations | 100000 |
| Successful | 100000 |
| Failed | 0 |
| Error Rate (%) | 0.0000 |
| **Throughput (ops/s)** | **24032.68** |

#### Latency Distribution (µs)

| Metric | Value |
|--------|------:|
| Min | 29 |
| Average | 41.51 |
| P50 (median) | 41 |
| P95 | 47 |
| P99 | 57 |
| **P99.9** | **78** |
| Max | 145 |

#### Per-Operation Breakdown

| Operation | Ops | Avg (µs) | P50 (µs) | P95 (µs) | P99 (µs) | P99.9 (µs) |
|-----------|----:|---------:|---------:|---------:|---------:|-----------:|
| READ | 100000 | 41.51 | 41 | 47 | 57 | 78 |


### Workload D — Read Latest

> **Operation mix:** 95R/5I  
> **Status:** OK

| Metric | Value |
|--------|------:|
| Runtime (ms) | 15278 |
| Total Operations | 100000 |
| Successful | 100000 |
| Failed | 0 |
| Error Rate (%) | 0.0000 |
| **Throughput (ops/s)** | **6545.36** |

#### Latency Distribution (µs)

| Metric | Value |
|--------|------:|
| Min | 25 |
| Average | 152.69 |
| P50 (median) | 72 |
| P95 | 275 |
| P99 | 1658 |
| **P99.9** | **1719** |
| Max | 34159 |

#### Per-Operation Breakdown

| Operation | Ops | Avg (µs) | P50 (µs) | P95 (µs) | P99 (µs) | P99.9 (µs) |
|-----------|----:|---------:|---------:|---------:|---------:|-----------:|
| READ | 95069 | 76.13 | 72 | 105 | 116 | 270 |
| INSERT | 4931 | 1628.73 | 1615 | 1699 | 1733 | 1930 |


### Workload E — Short Ranges

> **Operation mix:** 95S/5I  
> **Status:** OK

| Metric | Value |
|--------|------:|
| Runtime (ms) | 5867 |
| Total Operations | 100000 |
| Successful | 100000 |
| Failed | 0 |
| Error Rate (%) | 0.0000 |
| **Throughput (ops/s)** | **17044.49** |

#### Latency Distribution (µs)

| Metric | Value |
|--------|------:|
| Min | 19 |
| Average | 58.58 |
| P50 (median) | 57 |
| P95 | 68 |
| P99 | 113 |
| **P99.9** | **155** |
| Max | 1810 |

#### Per-Operation Breakdown

| Operation | Ops | Avg (µs) | P50 (µs) | P95 (µs) | P99 (µs) | P99.9 (µs) |
|-----------|----:|---------:|---------:|---------:|---------:|-----------:|
| INSERT | 4970 | 60.98 | 51 | 123 | 154 | 258 |
| SCAN | 95030 | 58.45 | 57 | 67 | 86 | 145 |


### Workload F — Read-Modify-Write

> **Operation mix:** 50R/50RMW  
> **Status:** OK

| Metric | Value |
|--------|------:|
| Runtime (ms) | 6558 |
| Total Operations | 100000 |
| Successful | 100000 |
| Failed | 0 |
| Error Rate (%) | 0.0000 |
| **Throughput (ops/s)** | **15248.55** |

#### Latency Distribution (µs)

| Metric | Value |
|--------|------:|
| Min | 32 |
| Average | 65.48 |
| P50 (median) | 71 |
| P95 | 100 |
| P99 | 230 |
| **P99.9** | **342** |
| Max | 92460 |

#### Per-Operation Breakdown

| Operation | Ops | Avg (µs) | P50 (µs) | P95 (µs) | P99 (µs) | P99.9 (µs) |
|-----------|----:|---------:|---------:|---------:|---------:|-----------:|
| READ | 50195 | 44.49 | 37 | 56 | 198 | 303 |
| READ-MODIFY-WRITE | 49805 | 86.64 | 76 | 110 | 240 | 359 |


---

*Generated by `shinydb-ycsb workload-all` — ShinyDB YCSB Benchmark Suite*
