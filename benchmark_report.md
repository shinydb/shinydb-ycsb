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
| Suite Duration | 50.99 s |

---

## Summary

| Workload | Description | Mix | Ops | Throughput (ops/s) | Avg Latency (µs) | P99 (µs) | P99.9 (µs) | Errors |
|----------|-------------|-----|----:|-------------------:|------------------:|---------:|------------:|-------:|
| A | Update Heavy | 50R/50U | 100000 | 24509.80 | 40.68 | 64 | 85 | 0.0000% |
| B | Read Mostly | 95R/5U | 100000 | 25464.73 | 39.16 | 61 | 83 | 0.0000% |
| C | Read Only | 100R | 100000 | 25859.84 | 38.56 | 60 | 81 | 0.0000% |
| D | Read Latest | 95R/5I | 100000 | 26759.43 | 37.23 | 59 | 81 | 0.0000% |
| E | Short Ranges | 95S/5I | 100000 | 24055.81 | 41.44 | 64 | 97 | 0.0000% |
| F | Read-Modify-Write | 50R/50RMW | 100000 | 16217.97 | 61.51 | 108 | 145 | 0.0000% |

---

## Detailed Results

### Workload A — Update Heavy

> **Operation mix:** 50R/50U  
> **Status:** OK

| Metric | Value |
|--------|------:|
| Runtime (ms) | 4080 |
| Total Operations | 100000 |
| Successful | 100000 |
| Failed | 0 |
| Error Rate (%) | 0.0000 |
| **Throughput (ops/s)** | **24509.80** |

#### Latency Distribution (µs)

| Metric | Value |
|--------|------:|
| Min | 26 |
| Average | 40.68 |
| P50 (median) | 40 |
| P95 | 48 |
| P99 | 64 |
| **P99.9** | **85** |
| Max | 327 |

#### Per-Operation Breakdown

| Operation | Ops | Avg (µs) | P50 (µs) | P95 (µs) | P99 (µs) | P99.9 (µs) |
|-----------|----:|---------:|---------:|---------:|---------:|-----------:|
| READ | 50397 | 39.62 | 39 | 46 | 62 | 82 |
| UPDATE | 49603 | 41.75 | 41 | 49 | 66 | 89 |


### Workload B — Read Mostly

> **Operation mix:** 95R/5U  
> **Status:** OK

| Metric | Value |
|--------|------:|
| Runtime (ms) | 3927 |
| Total Operations | 100000 |
| Successful | 100000 |
| Failed | 0 |
| Error Rate (%) | 0.0000 |
| **Throughput (ops/s)** | **25464.73** |

#### Latency Distribution (µs)

| Metric | Value |
|--------|------:|
| Min | 22 |
| Average | 39.16 |
| P50 (median) | 38 |
| P95 | 46 |
| P99 | 61 |
| **P99.9** | **83** |
| Max | 171 |

#### Per-Operation Breakdown

| Operation | Ops | Avg (µs) | P50 (µs) | P95 (µs) | P99 (µs) | P99.9 (µs) |
|-----------|----:|---------:|---------:|---------:|---------:|-----------:|
| READ | 94981 | 39.02 | 38 | 46 | 61 | 83 |
| UPDATE | 5019 | 41.65 | 41 | 49 | 65 | 80 |


### Workload C — Read Only

> **Operation mix:** 100R  
> **Status:** OK

| Metric | Value |
|--------|------:|
| Runtime (ms) | 3867 |
| Total Operations | 100000 |
| Successful | 100000 |
| Failed | 0 |
| Error Rate (%) | 0.0000 |
| **Throughput (ops/s)** | **25859.84** |

#### Latency Distribution (µs)

| Metric | Value |
|--------|------:|
| Min | 25 |
| Average | 38.56 |
| P50 (median) | 38 |
| P95 | 45 |
| P99 | 60 |
| **P99.9** | **81** |
| Max | 277 |

#### Per-Operation Breakdown

| Operation | Ops | Avg (µs) | P50 (µs) | P95 (µs) | P99 (µs) | P99.9 (µs) |
|-----------|----:|---------:|---------:|---------:|---------:|-----------:|
| READ | 100000 | 38.56 | 38 | 45 | 60 | 81 |


### Workload D — Read Latest

> **Operation mix:** 95R/5I  
> **Status:** OK

| Metric | Value |
|--------|------:|
| Runtime (ms) | 3737 |
| Total Operations | 100000 |
| Successful | 100000 |
| Failed | 0 |
| Error Rate (%) | 0.0000 |
| **Throughput (ops/s)** | **26759.43** |

#### Latency Distribution (µs)

| Metric | Value |
|--------|------:|
| Min | 20 |
| Average | 37.23 |
| P50 (median) | 36 |
| P95 | 46 |
| P99 | 59 |
| **P99.9** | **81** |
| Max | 1068 |

#### Per-Operation Breakdown

| Operation | Ops | Avg (µs) | P50 (µs) | P95 (µs) | P99 (µs) | P99.9 (µs) |
|-----------|----:|---------:|---------:|---------:|---------:|-----------:|
| READ | 94855 | 36.73 | 36 | 44 | 58 | 78 |
| INSERT | 5145 | 46.50 | 43 | 53 | 72 | 609 |


### Workload E — Short Ranges

> **Operation mix:** 95S/5I  
> **Status:** OK

| Metric | Value |
|--------|------:|
| Runtime (ms) | 4157 |
| Total Operations | 100000 |
| Successful | 100000 |
| Failed | 0 |
| Error Rate (%) | 0.0000 |
| **Throughput (ops/s)** | **24055.81** |

#### Latency Distribution (µs)

| Metric | Value |
|--------|------:|
| Min | 24 |
| Average | 41.44 |
| P50 (median) | 39 |
| P95 | 48 |
| P99 | 64 |
| **P99.9** | **97** |
| Max | 176994 |

#### Per-Operation Breakdown

| Operation | Ops | Avg (µs) | P50 (µs) | P95 (µs) | P99 (µs) | P99.9 (µs) |
|-----------|----:|---------:|---------:|---------:|---------:|-----------:|
| INSERT | 5120 | 81.12 | 43 | 53 | 78 | 575 |
| SCAN | 94880 | 39.30 | 38 | 47 | 63 | 88 |


### Workload F — Read-Modify-Write

> **Operation mix:** 50R/50RMW  
> **Status:** OK

| Metric | Value |
|--------|------:|
| Runtime (ms) | 6166 |
| Total Operations | 100000 |
| Successful | 100000 |
| Failed | 0 |
| Error Rate (%) | 0.0000 |
| **Throughput (ops/s)** | **16217.97** |

#### Latency Distribution (µs)

| Metric | Value |
|--------|------:|
| Min | 27 |
| Average | 61.51 |
| P50 (median) | 69 |
| P95 | 92 |
| P99 | 108 |
| **P99.9** | **145** |
| Max | 21795 |

#### Per-Operation Breakdown

| Operation | Ops | Avg (µs) | P50 (µs) | P95 (µs) | P99 (µs) | P99.9 (µs) |
|-----------|----:|---------:|---------:|---------:|---------:|-----------:|
| READ | 49920 | 41.35 | 39 | 53 | 65 | 89 |
| READ-MODIFY-WRITE | 50080 | 81.61 | 79 | 98 | 116 | 164 |


---

*Generated by `shinydb-ycsb workload-all` — ShinyDB YCSB Benchmark Suite*
