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
| Suite Duration | 51.78 s |

---

## Summary

| Workload | Description | Mix | Ops | Throughput (ops/s) | Avg Latency (µs) | P99 (µs) | P99.9 (µs) | Errors |
|----------|-------------|-----|----:|-------------------:|------------------:|---------:|------------:|-------:|
| A | Update Heavy | 50R/50U | 100000 | 26903.42 | 37.07 | 157 | 213 | 0.0000% |
| B | Read Mostly | 95R/5U | 100000 | 27662.52 | 36.05 | 160 | 233 | 0.0000% |
| C | Read Only | 100R | 100000 | 26838.43 | 37.16 | 158 | 227 | 0.0000% |
| D | Read Latest | 95R/5I | 100000 | 29036.00 | 34.33 | 162 | 245 | 0.0000% |
| E | Short Ranges | 95S/5I | 100000 | 22727.27 | 43.77 | 159 | 1107 | 0.0000% |
| F | Read-Modify-Write | 50R/50RMW | 100000 | 16509.82 | 60.46 | 211 | 443 | 0.0000% |

---

## Detailed Results

### Workload A — Update Heavy

> **Operation mix:** 50R/50U  
> **Status:** OK

| Metric | Value |
|--------|------:|
| Runtime (ms) | 3717 |
| Total Operations | 100000 |
| Successful | 100000 |
| Failed | 0 |
| Error Rate (%) | 0.0000 |
| **Throughput (ops/s)** | **26903.42** |

#### Latency Distribution (µs)

| Metric | Value |
|--------|------:|
| Min | 26 |
| Average | 37.07 |
| P50 (median) | 33 |
| P95 | 45 |
| P99 | 157 |
| **P99.9** | **213** |
| Max | 1987 |

#### Per-Operation Breakdown

| Operation | Ops | Avg (µs) | P50 (µs) | P95 (µs) | P99 (µs) | P99.9 (µs) |
|-----------|----:|---------:|---------:|---------:|---------:|-----------:|
| READ | 49923 | 35.76 | 31 | 43 | 156 | 207 |
| UPDATE | 50077 | 38.39 | 34 | 46 | 158 | 213 |


### Workload B — Read Mostly

> **Operation mix:** 95R/5U  
> **Status:** OK

| Metric | Value |
|--------|------:|
| Runtime (ms) | 3615 |
| Total Operations | 100000 |
| Successful | 100000 |
| Failed | 0 |
| Error Rate (%) | 0.0000 |
| **Throughput (ops/s)** | **27662.52** |

#### Latency Distribution (µs)

| Metric | Value |
|--------|------:|
| Min | 22 |
| Average | 36.05 |
| P50 (median) | 32 |
| P95 | 45 |
| P99 | 160 |
| **P99.9** | **233** |
| Max | 1641 |

#### Per-Operation Breakdown

| Operation | Ops | Avg (µs) | P50 (µs) | P95 (µs) | P99 (µs) | P99.9 (µs) |
|-----------|----:|---------:|---------:|---------:|---------:|-----------:|
| READ | 94983 | 35.87 | 32 | 45 | 160 | 233 |
| UPDATE | 5017 | 39.36 | 35 | 50 | 167 | 245 |


### Workload C — Read Only

> **Operation mix:** 100R  
> **Status:** OK

| Metric | Value |
|--------|------:|
| Runtime (ms) | 3726 |
| Total Operations | 100000 |
| Successful | 100000 |
| Failed | 0 |
| Error Rate (%) | 0.0000 |
| **Throughput (ops/s)** | **26838.43** |

#### Latency Distribution (µs)

| Metric | Value |
|--------|------:|
| Min | 25 |
| Average | 37.16 |
| P50 (median) | 32 |
| P95 | 50 |
| P99 | 158 |
| **P99.9** | **227** |
| Max | 1566 |

#### Per-Operation Breakdown

| Operation | Ops | Avg (µs) | P50 (µs) | P95 (µs) | P99 (µs) | P99.9 (µs) |
|-----------|----:|---------:|---------:|---------:|---------:|-----------:|
| READ | 100000 | 37.16 | 32 | 50 | 158 | 227 |


### Workload D — Read Latest

> **Operation mix:** 95R/5I  
> **Status:** OK

| Metric | Value |
|--------|------:|
| Runtime (ms) | 3444 |
| Total Operations | 100000 |
| Successful | 100000 |
| Failed | 0 |
| Error Rate (%) | 0.0000 |
| **Throughput (ops/s)** | **29036.00** |

#### Latency Distribution (µs)

| Metric | Value |
|--------|------:|
| Min | 20 |
| Average | 34.33 |
| P50 (median) | 29 |
| P95 | 46 |
| P99 | 162 |
| **P99.9** | **245** |
| Max | 804 |

#### Per-Operation Breakdown

| Operation | Ops | Avg (µs) | P50 (µs) | P95 (µs) | P99 (µs) | P99.9 (µs) |
|-----------|----:|---------:|---------:|---------:|---------:|-----------:|
| READ | 94926 | 33.77 | 29 | 44 | 162 | 239 |
| INSERT | 5074 | 44.90 | 37 | 95 | 172 | 329 |


### Workload E — Short Ranges

> **Operation mix:** 95S/5I  
> **Status:** OK

| Metric | Value |
|--------|------:|
| Runtime (ms) | 4400 |
| Total Operations | 100000 |
| Successful | 100000 |
| Failed | 0 |
| Error Rate (%) | 0.0000 |
| **Throughput (ops/s)** | **22727.27** |

#### Latency Distribution (µs)

| Metric | Value |
|--------|------:|
| Min | 22 |
| Average | 43.77 |
| P50 (median) | 35 |
| P95 | 57 |
| P99 | 159 |
| **P99.9** | **1107** |
| Max | 44763 |

#### Per-Operation Breakdown

| Operation | Ops | Avg (µs) | P50 (µs) | P95 (µs) | P99 (µs) | P99.9 (µs) |
|-----------|----:|---------:|---------:|---------:|---------:|-----------:|
| INSERT | 4954 | 74.67 | 40 | 146 | 362 | 3306 |
| SCAN | 95046 | 42.16 | 34 | 54 | 142 | 912 |


### Workload F — Read-Modify-Write

> **Operation mix:** 50R/50RMW  
> **Status:** OK

| Metric | Value |
|--------|------:|
| Runtime (ms) | 6057 |
| Total Operations | 100000 |
| Successful | 100000 |
| Failed | 0 |
| Error Rate (%) | 0.0000 |
| **Throughput (ops/s)** | **16509.82** |

#### Latency Distribution (µs)

| Metric | Value |
|--------|------:|
| Min | 27 |
| Average | 60.46 |
| P50 (median) | 61 |
| P95 | 158 |
| P99 | 211 |
| **P99.9** | **443** |
| Max | 2201 |

#### Per-Operation Breakdown

| Operation | Ops | Avg (µs) | P50 (µs) | P95 (µs) | P99 (µs) | P99.9 (µs) |
|-----------|----:|---------:|---------:|---------:|---------:|-----------:|
| READ | 49963 | 42.44 | 32 | 141 | 176 | 382 |
| READ-MODIFY-WRITE | 50037 | 78.45 | 66 | 181 | 229 | 470 |


---

*Generated by `shinydb-ycsb workload-all` — ShinyDB YCSB Benchmark Suite*
