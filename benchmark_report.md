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
| Suite Duration | 6.01 s |

---

## Summary

| Workload | Description | Mix | Ops | Throughput (ops/s) | Avg Latency (µs) | P99 (µs) | P99.9 (µs) | Errors |
|----------|-------------|-----|----:|-------------------:|------------------:|---------:|------------:|-------:|
| A | Update Heavy | 50R/50U | 10000 | 20325.20 | 49.07 | 97 | 946 | 0.0000% |
| B | Read Mostly | 95R/5U | 10000 | 23696.68 | 42.08 | 72 | 91 | 0.0000% |
| C | Read Only | 100R | 10000 | 23752.97 | 42.04 | 69 | 87 | 0.0000% |
| D | Read Latest | 95R/5I | 10000 | 23201.86 | 43.00 | 214 | 291 | 0.0000% |
| E | Short Ranges | 95S/5I | 10000 | 17793.59 | 56.10 | 101 | 233 | 0.0000% |
| F | Read-Modify-Write | 50R/50RMW | 10000 | 15479.88 | 64.50 | 121 | 155 | 0.0000% |

---

## Detailed Results

### Workload A — Update Heavy

> **Operation mix:** 50R/50U  
> **Status:** OK

| Metric | Value |
|--------|------:|
| Runtime (ms) | 492 |
| Total Operations | 10000 |
| Successful | 10000 |
| Failed | 0 |
| Error Rate (%) | 0.0000 |
| **Throughput (ops/s)** | **20325.20** |

#### Latency Distribution (µs)

| Metric | Value |
|--------|------:|
| Min | 31 |
| Average | 49.07 |
| P50 (median) | 43 |
| P95 | 64 |
| P99 | 97 |
| **P99.9** | **946** |
| Max | 5432 |

#### Per-Operation Breakdown

| Operation | Ops | Avg (µs) | P50 (µs) | P95 (µs) | P99 (µs) | P99.9 (µs) |
|-----------|----:|---------:|---------:|---------:|---------:|-----------:|
| READ | 4966 | 49.01 | 42 | 62 | 95 | 1715 |
| UPDATE | 5034 | 49.13 | 45 | 66 | 98 | 348 |


### Workload B — Read Mostly

> **Operation mix:** 95R/5U  
> **Status:** OK

| Metric | Value |
|--------|------:|
| Runtime (ms) | 422 |
| Total Operations | 10000 |
| Successful | 10000 |
| Failed | 0 |
| Error Rate (%) | 0.0000 |
| **Throughput (ops/s)** | **23696.68** |

#### Latency Distribution (µs)

| Metric | Value |
|--------|------:|
| Min | 28 |
| Average | 42.08 |
| P50 (median) | 41 |
| P95 | 53 |
| P99 | 72 |
| **P99.9** | **91** |
| Max | 152 |

#### Per-Operation Breakdown

| Operation | Ops | Avg (µs) | P50 (µs) | P95 (µs) | P99 (µs) | P99.9 (µs) |
|-----------|----:|---------:|---------:|---------:|---------:|-----------:|
| READ | 9532 | 41.94 | 40 | 53 | 72 | 91 |
| UPDATE | 468 | 44.86 | 43 | 57 | 77 | 111 |


### Workload C — Read Only

> **Operation mix:** 100R  
> **Status:** OK

| Metric | Value |
|--------|------:|
| Runtime (ms) | 421 |
| Total Operations | 10000 |
| Successful | 10000 |
| Failed | 0 |
| Error Rate (%) | 0.0000 |
| **Throughput (ops/s)** | **23752.97** |

#### Latency Distribution (µs)

| Metric | Value |
|--------|------:|
| Min | 30 |
| Average | 42.04 |
| P50 (median) | 41 |
| P95 | 51 |
| P99 | 69 |
| **P99.9** | **87** |
| Max | 121 |

#### Per-Operation Breakdown

| Operation | Ops | Avg (µs) | P50 (µs) | P95 (µs) | P99 (µs) | P99.9 (µs) |
|-----------|----:|---------:|---------:|---------:|---------:|-----------:|
| READ | 10000 | 42.04 | 41 | 51 | 69 | 87 |


### Workload D — Read Latest

> **Operation mix:** 95R/5I  
> **Status:** OK

| Metric | Value |
|--------|------:|
| Runtime (ms) | 431 |
| Total Operations | 10000 |
| Successful | 10000 |
| Failed | 0 |
| Error Rate (%) | 0.0000 |
| **Throughput (ops/s)** | **23201.86** |

#### Latency Distribution (µs)

| Metric | Value |
|--------|------:|
| Min | 25 |
| Average | 43.00 |
| P50 (median) | 33 |
| P95 | 68 |
| P99 | 214 |
| **P99.9** | **291** |
| Max | 335 |

#### Per-Operation Breakdown

| Operation | Ops | Avg (µs) | P50 (µs) | P95 (µs) | P99 (µs) | P99.9 (µs) |
|-----------|----:|---------:|---------:|---------:|---------:|-----------:|
| READ | 9511 | 34.30 | 33 | 41 | 49 | 68 |
| INSERT | 489 | 212.06 | 204 | 268 | 313 | 335 |


### Workload E — Short Ranges

> **Operation mix:** 95S/5I  
> **Status:** OK

| Metric | Value |
|--------|------:|
| Runtime (ms) | 562 |
| Total Operations | 10000 |
| Successful | 10000 |
| Failed | 0 |
| Error Rate (%) | 0.0000 |
| **Throughput (ops/s)** | **17793.59** |

#### Latency Distribution (µs)

| Metric | Value |
|--------|------:|
| Min | 35 |
| Average | 56.10 |
| P50 (median) | 53 |
| P95 | 66 |
| P99 | 101 |
| **P99.9** | **233** |
| Max | 478 |

#### Per-Operation Breakdown

| Operation | Ops | Avg (µs) | P50 (µs) | P95 (µs) | P99 (µs) | P99.9 (µs) |
|-----------|----:|---------:|---------:|---------:|---------:|-----------:|
| INSERT | 523 | 68.32 | 53 | 179 | 239 | 478 |
| SCAN | 9477 | 55.43 | 53 | 66 | 80 | 196 |


### Workload F — Read-Modify-Write

> **Operation mix:** 50R/50RMW  
> **Status:** OK

| Metric | Value |
|--------|------:|
| Runtime (ms) | 646 |
| Total Operations | 10000 |
| Successful | 10000 |
| Failed | 0 |
| Error Rate (%) | 0.0000 |
| **Throughput (ops/s)** | **15479.88** |

#### Latency Distribution (µs)

| Metric | Value |
|--------|------:|
| Min | 31 |
| Average | 64.50 |
| P50 (median) | 65 |
| P95 | 98 |
| P99 | 121 |
| **P99.9** | **155** |
| Max | 306 |

#### Per-Operation Breakdown

| Operation | Ops | Avg (µs) | P50 (µs) | P95 (µs) | P99 (µs) | P99.9 (µs) |
|-----------|----:|---------:|---------:|---------:|---------:|-----------:|
| READ | 5112 | 42.76 | 41 | 53 | 75 | 100 |
| READ-MODIFY-WRITE | 4888 | 87.23 | 84 | 108 | 130 | 169 |


---

*Generated by `shinydb-ycsb workload-all` — ShinyDB YCSB Benchmark Suite*
