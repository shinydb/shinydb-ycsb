const std = @import("std");
const builtin = @import("builtin");
const shinydb = @import("shinydb_zig_client");
const ShinyDbClient = shinydb.ShinyDbClient;
const proto = @import("proto");
const Io = std.Io;

// Configuration and Results
const config_mod = @import("config.zig");
const ConfigManager = config_mod.ConfigManager;
const results_mod = @import("results.zig");
const ResultExporter = results_mod.ResultExporter;
const compare_mod = @import("compare.zig");
const ComparisonTool = compare_mod.ComparisonTool;
const stability_mod = @import("stability.zig");
const StabilityTester = stability_mod.StabilityTester;
const StabilityTests = stability_mod.StabilityTests;
const Metrics = @import("metrics.zig").Metrics;
const MetricsTracker = @import("metrics.zig").MetricsTracker;
const milliTimestamp = @import("metrics.zig").milliTimestamp;
const Timer = @import("metrics.zig").Timer;

// YCSB Standard Workloads
const WorkloadA = @import("workloads/workload_a.zig").WorkloadA;
const WorkloadB = @import("workloads/workload_b.zig").WorkloadB;
const WorkloadC = @import("workloads/workload_c.zig").WorkloadC;
const WorkloadD = @import("workloads/workload_d.zig").WorkloadD;
const WorkloadE = @import("workloads/workload_e.zig").WorkloadE;
const WorkloadF = @import("workloads/workload_f.zig").WorkloadF;

pub fn main(init: std.process.Init.Minimal) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const args = try init.args.toSlice(arena.allocator());

    if (args.len < 2) {
        try printUsage();
        return;
    }

    const command = args[1];

    // Parse config file and CLI overrides
    var config_manager = ConfigManager.init(allocator);
    defer config_manager.deinit();

    // Try loading default config file
    config_manager.loadFromFile("config.yaml") catch {};

    // Parse CLI arguments for overrides
    if (args.len > 2) {
        try config_manager.parseArgs(args[2..]);
    }

    const cfg = config_manager.config;

    if (std.mem.eql(u8, command, "workload-a")) {
        try runWorkloadA(allocator, cfg);
    } else if (std.mem.eql(u8, command, "workload-b")) {
        try runWorkloadB(allocator, cfg);
    } else if (std.mem.eql(u8, command, "workload-c")) {
        try runWorkloadC(allocator, cfg);
    } else if (std.mem.eql(u8, command, "workload-d")) {
        try runWorkloadD(allocator, cfg);
    } else if (std.mem.eql(u8, command, "workload-e")) {
        try runWorkloadE(allocator, cfg);
    } else if (std.mem.eql(u8, command, "workload-f")) {
        try runWorkloadF(allocator, cfg);
    } else if (std.mem.eql(u8, command, "workload-all")) {
        try runAllWorkloads(allocator, cfg);
    } else if (std.mem.eql(u8, command, "stability-quick")) {
        try runStabilityTest(allocator, &config_manager, 5);
    } else if (std.mem.eql(u8, command, "stability-1h")) {
        try runStabilityTest(allocator, &config_manager, 60);
    } else if (std.mem.eql(u8, command, "stability-24h")) {
        try runStabilityTest(allocator, &config_manager, 24 * 60);
    } else if (std.mem.eql(u8, command, "compare")) {
        try runCompare(allocator, args);
    } else if (std.mem.eql(u8, command, "config")) {
        config_manager.printConfig();
    } else if (std.mem.eql(u8, command, "generate-config")) {
        try generateConfigFile(allocator);
    } else {
        std.debug.print("Unknown command: {s}\n", .{command});
        try printUsage();
    }
}

fn printUsage() !void {
    const usage =
        \\shinydb-ycsb - YCSB Benchmark suite for shinydb
        \\
        \\Usage:
        \\  shinydb-ycsb <command> [options]
        \\
        \\YCSB Standard Workloads:
        \\  workload-a          Update Heavy (50% reads, 50% updates)
        \\  workload-b          Read Mostly (95% reads, 5% updates)
        \\  workload-c          Read Only (100% reads)
        \\  workload-d          Read Latest (95% reads, 5% inserts)
        \\  workload-e          Short Ranges (95% scans, 5% inserts)
        \\  workload-f          Read-Modify-Write (50% reads, 50% RMW)        \  workload-all        Run ALL workloads (A-F) and generate Markdown report        \\
        \\Stability Tests:
        \\  stability-quick     Run 5-minute stability check (CI/CD)
        \\  stability-1h        Run 1-hour endurance test
        \\  stability-24h       Run 24-hour stability test
        \\
        \\Tools:
        \\  compare <a> <b>     Compare two benchmark results (JSON files)
        \\  config              Show current configuration
        \\  generate-config     Generate default config.yaml
        \\
        \\Options:
        \\  -c <file>           Load config from file
        \\  --host=<host>       Override host (default: 127.0.0.1)
        \\  --port=<port>       Override port (default: 23469)
        \\  --record_count=<n>  Override record count
        \\  --operation_count=<n> Override operation count
        \\  --document_size=<n> Override document size (bytes)
        \\  --thread_count=<n>  Override thread count
        \\  --export_format=<f> Output format: human, json, csv, ycsb
        \\  --export_path=<p>   Export results to file
        \\
        \\Examples:
        \\  shinydb-ycsb workload-a --record_count=100000
        \\  shinydb-ycsb workload-c --export_format=ycsb
        \\  shinydb-ycsb workload-all --record_count=1000 --operation_count=1000
        \\  shinydb-ycsb workload-all --export_path=results/report.md
        \\  shinydb-ycsb stability-quick
        \\  shinydb-ycsb compare baseline.json candidate.json
        \\
    ;
    std.debug.print("{s}\n", .{usage});
}

// YCSB Workload Runners - all wired to BenchmarkConfig

/// Print YCSB-formatted output from MetricsTracker data.
/// Format: [SECTION], Metric, Value — compatible with standard YCSB analysis tools.
fn printYcsbOutput(allocator: std.mem.Allocator, tracker: *MetricsTracker, duration_ms: i64) !void {
    // Aggregate across all operation types
    var total_ops: u64 = 0;
    var successful_ops: u64 = 0;
    var failed_ops: u64 = 0;
    var min_lat: u64 = std.math.maxInt(u64);
    var max_lat: u64 = 0;
    var total_lat: u64 = 0;

    const op_metrics = [_]?*Metrics{
        tracker.read_metrics,
        tracker.insert_metrics,
        tracker.update_metrics,
        tracker.delete_metrics,
        tracker.scan_metrics,
        tracker.rmw_metrics,
    };
    const op_names = [_][]const u8{ "READ", "INSERT", "UPDATE", "DELETE", "SCAN", "READ-MODIFY-WRITE" };

    var all_latencies_count: usize = 0;
    for (op_metrics) |opt_m| {
        if (opt_m) |m| {
            total_ops += m.total_ops.load(.monotonic);
            successful_ops += m.successful_ops.load(.monotonic);
            failed_ops += m.failed_ops.load(.monotonic);
            total_lat += m.total_latency.load(.monotonic);
            const mmin = m.min_latency.load(.monotonic);
            const mmax = m.max_latency.load(.monotonic);
            if (mmin < min_lat) min_lat = mmin;
            if (mmax > max_lat) max_lat = mmax;
            all_latencies_count += m.latencies.items.len;
        }
    }

    const throughput: f64 = if (duration_ms > 0)
        @as(f64, @floatFromInt(total_ops)) * 1000.0 / @as(f64, @floatFromInt(duration_ms))
    else
        0.0;

    const avg_lat: f64 = if (successful_ops > 0)
        @as(f64, @floatFromInt(total_lat)) / @as(f64, @floatFromInt(successful_ops))
    else
        0.0;

    const error_rate: f64 = if (total_ops > 0)
        @as(f64, @floatFromInt(failed_ops)) / @as(f64, @floatFromInt(total_ops)) * 100.0
    else
        0.0;

    if (min_lat == std.math.maxInt(u64)) min_lat = 0;

    // Compute overall percentiles by merging all latency arrays
    var p50: u64 = 0;
    var p95: u64 = 0;
    var p99: u64 = 0;
    var p999: u64 = 0;

    if (all_latencies_count > 0) {
        const merged = try allocator.alloc(u64, all_latencies_count);
        defer allocator.free(merged);
        var idx: usize = 0;
        for (op_metrics) |opt_m| {
            if (opt_m) |m| {
                const len = m.latencies.items.len;
                @memcpy(merged[idx..][0..len], m.latencies.items);
                idx += len;
            }
        }
        std.mem.sort(u64, merged, {}, comptime std.sort.asc(u64));
        const n = all_latencies_count;
        p50 = merged[@min(@as(usize, @intFromFloat(@as(f64, @floatFromInt(n)) * 0.50)), n - 1)];
        p95 = merged[@min(@as(usize, @intFromFloat(@as(f64, @floatFromInt(n)) * 0.95)), n - 1)];
        p99 = merged[@min(@as(usize, @intFromFloat(@as(f64, @floatFromInt(n)) * 0.99)), n - 1)];
        p999 = merged[@min(@as(usize, @intFromFloat(@as(f64, @floatFromInt(n)) * 0.999)), n - 1)];
    }

    // Print [OVERALL] section
    std.debug.print("[OVERALL], RunTime(ms), {d}\n", .{duration_ms});
    std.debug.print("[OVERALL], Throughput(ops/sec), {d:.2}\n", .{throughput});
    std.debug.print("[OVERALL], Operations, {d}\n", .{total_ops});
    std.debug.print("[OVERALL], SuccessfulOperations, {d}\n", .{successful_ops});
    std.debug.print("[OVERALL], FailedOperations, {d}\n", .{failed_ops});
    std.debug.print("[OVERALL], ErrorRate(%), {d:.4}\n", .{error_rate});
    std.debug.print("[OVERALL], AverageLatency(us), {d:.2}\n", .{avg_lat});
    std.debug.print("[OVERALL], MinLatency(us), {d}\n", .{min_lat});
    std.debug.print("[OVERALL], MaxLatency(us), {d}\n", .{max_lat});
    std.debug.print("[OVERALL], 50thPercentileLatency(us), {d}\n", .{p50});
    std.debug.print("[OVERALL], 95thPercentileLatency(us), {d}\n", .{p95});
    std.debug.print("[OVERALL], 99thPercentileLatency(us), {d}\n", .{p99});
    std.debug.print("[OVERALL], 99.9thPercentileLatency(us), {d}\n", .{p999});

    // Per-operation stats
    for (op_metrics, op_names) |opt_m, name| {
        if (opt_m) |m| {
            std.debug.print("[{s}], Operations, {d}\n", .{ name, m.total_ops.load(.monotonic) });
            std.debug.print("[{s}], AverageLatency(us), {d:.2}\n", .{ name, m.avgLatency() });
            std.debug.print("[{s}], MinLatency(us), {d}\n", .{ name, m.min_latency.load(.monotonic) });
            std.debug.print("[{s}], MaxLatency(us), {d}\n", .{ name, m.max_latency.load(.monotonic) });
            std.debug.print("[{s}], 50thPercentileLatency(us), {d}\n", .{ name, m.percentile(0.50) });
            std.debug.print("[{s}], 95thPercentileLatency(us), {d}\n", .{ name, m.percentile(0.95) });
            std.debug.print("[{s}], 99thPercentileLatency(us), {d}\n", .{ name, m.percentile(0.99) });
            std.debug.print("[{s}], 99.9thPercentileLatency(us), {d}\n", .{ name, m.percentile(0.999) });
        }
    }
}
fn runWorkloadA(allocator: std.mem.Allocator, cfg: config_mod.BenchmarkConfig) !void {
    var threaded: std.Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var client = try ShinyDbClient.init(allocator, io);
    defer client.deinit();

    try client.connect(cfg.host, cfg.port);
    defer client.disconnect();

    if (client.authenticate("admin", "admin")) |auth| {
        var auth_result = auth;
        auth_result.deinit();
    } else |_| {
        std.debug.print("Auth skipped (not required)\n", .{});
    }

    const store_ns = try std.fmt.allocPrint(allocator, "benchmark.workload_a", .{});
    defer allocator.free(store_ns);

    client.create(shinydb.Store{
        .id = 0,
        .store_id = 0,
        .ns = store_ns,
        .description = "Workload A store",
        .created_at = 0,
    }) catch {};

    const config = WorkloadA.Config{
        .record_count = cfg.record_count,
        .operation_count = cfg.operation_count,
        .document_size = cfg.document_size,
        .warmup_ops = cfg.warmup_ops,
    };

    var workload = try WorkloadA.init(allocator, io, client, "benchmark", "workload_a", config);
    defer workload.deinit();

    try workload.load();
    try workload.run();

    if (cfg.export_format == .ycsb) {
        const run_duration = milliTimestamp() - workload.metrics_tracker.run_start_time;
        try printYcsbOutput(allocator, &workload.metrics_tracker, run_duration);
    }
}

fn runWorkloadB(allocator: std.mem.Allocator, cfg: config_mod.BenchmarkConfig) !void {
    var threaded: std.Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var client = try ShinyDbClient.init(allocator, io);
    defer client.deinit();

    try client.connect(cfg.host, cfg.port);
    defer client.disconnect();

    if (client.authenticate("admin", "admin")) |auth| {
        var auth_result = auth;
        auth_result.deinit();
    } else |_| {
        std.debug.print("Auth skipped (not required)\n", .{});
    }

    const store_ns = try std.fmt.allocPrint(allocator, "benchmark.workload_b", .{});
    defer allocator.free(store_ns);

    client.create(shinydb.Store{
        .id = 0,
        .store_id = 0,
        .ns = store_ns,
        .description = "Workload B store",
        .created_at = 0,
    }) catch {};

    const config = WorkloadB.Config{
        .record_count = cfg.record_count,
        .operation_count = cfg.operation_count,
        .document_size = cfg.document_size,
        .warmup_ops = cfg.warmup_ops,
    };

    var workload = try WorkloadB.init(allocator, io, client, "benchmark", "workload_b", config);
    defer workload.deinit();

    try workload.load();
    try workload.run();

    if (cfg.export_format == .ycsb) {
        const run_duration = milliTimestamp() - workload.metrics_tracker.run_start_time;
        try printYcsbOutput(allocator, &workload.metrics_tracker, run_duration);
    }
}

fn runWorkloadC(allocator: std.mem.Allocator, cfg: config_mod.BenchmarkConfig) !void {
    var threaded: std.Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var client = try ShinyDbClient.init(allocator, io);
    defer client.deinit();

    try client.connect(cfg.host, cfg.port);
    defer client.disconnect();

    if (client.authenticate("admin", "admin")) |auth| {
        var auth_result = auth;
        auth_result.deinit();
    } else |_| {
        std.debug.print("Auth skipped (not required)\n", .{});
    }

    const store_ns = try std.fmt.allocPrint(allocator, "benchmark.workload_c", .{});
    defer allocator.free(store_ns);

    client.create(shinydb.Store{
        .id = 0,
        .store_id = 0,
        .ns = store_ns,
        .description = "Workload C store",
        .created_at = 0,
    }) catch {};

    const config = WorkloadC.Config{
        .record_count = cfg.record_count,
        .operation_count = cfg.operation_count,
        .document_size = cfg.document_size,
        .warmup_ops = cfg.warmup_ops,
    };

    var workload = try WorkloadC.init(allocator, io, client, "benchmark", "workload_c", config);
    defer workload.deinit();

    try workload.load();
    try workload.run();

    if (cfg.export_format == .ycsb) {
        const run_duration = milliTimestamp() - workload.metrics_tracker.run_start_time;
        try printYcsbOutput(allocator, &workload.metrics_tracker, run_duration);
    }
}

fn runWorkloadD(allocator: std.mem.Allocator, cfg: config_mod.BenchmarkConfig) !void {
    var threaded: std.Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var client = try ShinyDbClient.init(allocator, io);
    defer client.deinit();

    try client.connect(cfg.host, cfg.port);
    defer client.disconnect();

    if (client.authenticate("admin", "admin")) |auth| {
        var auth_result = auth;
        auth_result.deinit();
    } else |_| {
        std.debug.print("Auth skipped (not required)\n", .{});
    }

    const store_ns = try std.fmt.allocPrint(allocator, "benchmark.workload_d", .{});
    defer allocator.free(store_ns);

    client.create(shinydb.Store{
        .id = 0,
        .store_id = 0,
        .ns = store_ns,
        .description = "Workload D store",
        .created_at = 0,
    }) catch {};

    const config = WorkloadD.Config{
        .record_count = cfg.record_count,
        .operation_count = cfg.operation_count,
        .document_size = cfg.document_size,
        .warmup_ops = cfg.warmup_ops,
    };

    var workload = try WorkloadD.init(allocator, io, client, "benchmark", "workload_d", config);
    defer workload.deinit();

    try workload.load();
    try workload.run();

    if (cfg.export_format == .ycsb) {
        const run_duration = milliTimestamp() - workload.metrics_tracker.run_start_time;
        try printYcsbOutput(allocator, &workload.metrics_tracker, run_duration);
    }
}

fn runWorkloadE(allocator: std.mem.Allocator, cfg: config_mod.BenchmarkConfig) !void {
    var threaded: std.Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var client = try ShinyDbClient.init(allocator, io);
    defer client.deinit();

    try client.connect(cfg.host, cfg.port);
    defer client.disconnect();

    if (client.authenticate("admin", "admin")) |auth| {
        var auth_result = auth;
        auth_result.deinit();
    } else |_| {
        std.debug.print("Auth skipped (not required)\n", .{});
    }

    const store_ns = try std.fmt.allocPrint(allocator, "benchmark.workload_e", .{});
    defer allocator.free(store_ns);

    client.create(shinydb.Store{
        .id = 0,
        .store_id = 0,
        .ns = store_ns,
        .description = "Workload E store",
        .created_at = 0,
    }) catch {};

    const config = WorkloadE.Config{
        .record_count = cfg.record_count,
        .operation_count = cfg.operation_count,
        .document_size = cfg.document_size,
        .warmup_ops = cfg.warmup_ops,
        .scan_length = cfg.scan_length,
    };

    var workload = try WorkloadE.init(allocator, io, client, "benchmark", "workload_e", config);
    defer workload.deinit();

    try workload.load();
    try workload.run();

    if (cfg.export_format == .ycsb) {
        const run_duration = milliTimestamp() - workload.metrics_tracker.run_start_time;
        try printYcsbOutput(allocator, &workload.metrics_tracker, run_duration);
    }
}

fn runWorkloadF(allocator: std.mem.Allocator, cfg: config_mod.BenchmarkConfig) !void {
    var threaded: std.Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var client = try ShinyDbClient.init(allocator, io);
    defer client.deinit();

    try client.connect(cfg.host, cfg.port);
    defer client.disconnect();

    if (client.authenticate("admin", "admin")) |auth| {
        var auth_result = auth;
        auth_result.deinit();
    } else |_| {
        std.debug.print("Auth skipped (not required)\n", .{});
    }

    const store_ns = try std.fmt.allocPrint(allocator, "benchmark.workload_f", .{});
    defer allocator.free(store_ns);

    client.create(shinydb.Store{
        .id = 0,
        .store_id = 0,
        .ns = store_ns,
        .description = "Workload F store",
        .created_at = 0,
    }) catch {};

    const config = WorkloadF.Config{
        .record_count = cfg.record_count,
        .operation_count = cfg.operation_count,
        .document_size = cfg.document_size,
        .warmup_ops = cfg.warmup_ops,
    };

    var workload = try WorkloadF.init(allocator, io, client, "benchmark", "workload_f", config);
    defer workload.deinit();

    try workload.load();
    try workload.run();

    if (cfg.export_format == .ycsb) {
        const run_duration = milliTimestamp() - workload.metrics_tracker.run_start_time;
        try printYcsbOutput(allocator, &workload.metrics_tracker, run_duration);
    }
}

/// Per-workload result collected after each workload completes.
const WorkloadSummary = struct {
    name: []const u8,
    description: []const u8,
    mix: []const u8,
    status: []const u8,
    total_ops: u64,
    successful_ops: u64,
    failed_ops: u64,
    throughput: f64,
    avg_lat: f64,
    min_lat: u64,
    max_lat: u64,
    p50: u64,
    p95: u64,
    p99: u64,
    p999: u64,
    error_rate: f64,
    duration_ms: i64,
    // Per-operation breakdown
    per_op: [6]?OpSummary,

    const OpSummary = struct {
        name: []const u8,
        total_ops: u64,
        avg_lat: f64,
        p50: u64,
        p95: u64,
        p99: u64,
        p999: u64,
    };
};

/// Collect metrics from a MetricsTracker into a WorkloadSummary.
fn collectMetrics(allocator: std.mem.Allocator, tracker: *MetricsTracker, duration_ms: i64, name: []const u8, desc: []const u8, mix: []const u8) !WorkloadSummary {
    var total_ops: u64 = 0;
    var successful_ops: u64 = 0;
    var failed_ops: u64 = 0;
    var min_lat: u64 = std.math.maxInt(u64);
    var max_lat: u64 = 0;
    var total_lat: u64 = 0;

    const op_ptrs = [_]?*Metrics{
        tracker.read_metrics,
        tracker.insert_metrics,
        tracker.update_metrics,
        tracker.delete_metrics,
        tracker.scan_metrics,
        tracker.rmw_metrics,
    };
    const op_labels = [_][]const u8{ "READ", "INSERT", "UPDATE", "DELETE", "SCAN", "READ-MODIFY-WRITE" };

    var all_latencies_count: usize = 0;
    for (op_ptrs) |opt_m| {
        if (opt_m) |m| {
            total_ops += m.total_ops.load(.monotonic);
            successful_ops += m.successful_ops.load(.monotonic);
            failed_ops += m.failed_ops.load(.monotonic);
            total_lat += m.total_latency.load(.monotonic);
            const mmin = m.min_latency.load(.monotonic);
            const mmax = m.max_latency.load(.monotonic);
            if (mmin < min_lat) min_lat = mmin;
            if (mmax > max_lat) max_lat = mmax;
            all_latencies_count += m.latencies.items.len;
        }
    }

    const throughput: f64 = if (duration_ms > 0)
        @as(f64, @floatFromInt(total_ops)) * 1000.0 / @as(f64, @floatFromInt(duration_ms))
    else
        0.0;

    const avg_lat: f64 = if (successful_ops > 0)
        @as(f64, @floatFromInt(total_lat)) / @as(f64, @floatFromInt(successful_ops))
    else
        0.0;

    const error_rate: f64 = if (total_ops > 0)
        @as(f64, @floatFromInt(failed_ops)) / @as(f64, @floatFromInt(total_ops)) * 100.0
    else
        0.0;

    if (min_lat == std.math.maxInt(u64)) min_lat = 0;

    // Compute overall percentiles
    var p50: u64 = 0;
    var p95: u64 = 0;
    var p99: u64 = 0;
    var p999: u64 = 0;

    if (all_latencies_count > 0) {
        const merged = try allocator.alloc(u64, all_latencies_count);
        defer allocator.free(merged);
        var idx: usize = 0;
        for (op_ptrs) |opt_m| {
            if (opt_m) |m| {
                const len = m.latencies.items.len;
                @memcpy(merged[idx..][0..len], m.latencies.items);
                idx += len;
            }
        }
        std.mem.sort(u64, merged, {}, comptime std.sort.asc(u64));
        const n = all_latencies_count;
        p50 = merged[@min(@as(usize, @intFromFloat(@as(f64, @floatFromInt(n)) * 0.50)), n - 1)];
        p95 = merged[@min(@as(usize, @intFromFloat(@as(f64, @floatFromInt(n)) * 0.95)), n - 1)];
        p99 = merged[@min(@as(usize, @intFromFloat(@as(f64, @floatFromInt(n)) * 0.99)), n - 1)];
        p999 = merged[@min(@as(usize, @intFromFloat(@as(f64, @floatFromInt(n)) * 0.999)), n - 1)];
    }

    // Per-operation breakdown
    var per_op: [6]?WorkloadSummary.OpSummary = .{ null, null, null, null, null, null };
    for (op_ptrs, op_labels, 0..) |opt_m, label, i| {
        if (opt_m) |m| {
            per_op[i] = .{
                .name = label,
                .total_ops = m.total_ops.load(.monotonic),
                .avg_lat = m.avgLatency(),
                .p50 = m.percentile(0.50),
                .p95 = m.percentile(0.95),
                .p99 = m.percentile(0.99),
                .p999 = m.percentile(0.999),
            };
        }
    }

    return .{
        .name = name,
        .description = desc,
        .mix = mix,
        .status = "OK",
        .total_ops = total_ops,
        .successful_ops = successful_ops,
        .failed_ops = failed_ops,
        .throughput = throughput,
        .avg_lat = avg_lat,
        .min_lat = min_lat,
        .max_lat = max_lat,
        .p50 = p50,
        .p95 = p95,
        .p99 = p99,
        .p999 = p999,
        .error_rate = error_rate,
        .duration_ms = duration_ms,
        .per_op = per_op,
    };
}

/// Write a markdown benchmark report to the given ArrayList buffer.
fn writeMarkdownReport(buf: *std.ArrayList(u8), allocator: std.mem.Allocator, summaries: []const WorkloadSummary, cfg: config_mod.BenchmarkConfig, suite_duration_ms: i64) !void {
    // Helper to append formatted text
    const append = struct {
        fn f(b: *std.ArrayList(u8), alloc: std.mem.Allocator, comptime fmt: []const u8, args: anytype) !void {
            const s = try std.fmt.allocPrint(alloc, fmt, args);
            defer alloc.free(s);
            try b.appendSlice(alloc, s);
        }
    }.f;

    try append(buf, allocator, "# ShinyDB YCSB Benchmark Report\n\n", .{});

    // Metadata
    try append(buf, allocator, "| Property | Value |\n|----------|-------|\n", .{});
    try append(buf, allocator, "| OS | {s} ({s}) |\n", .{ @tagName(builtin.os.tag), @tagName(builtin.cpu.arch) });
    try append(buf, allocator, "| Zig | {s} |\n", .{builtin.zig_version_string});
    try append(buf, allocator, "| Target | {s}:{d} |\n", .{ cfg.host, cfg.port });
    try append(buf, allocator, "| Record Count | {d} |\n", .{cfg.record_count});
    try append(buf, allocator, "| Operation Count | {d} |\n", .{cfg.operation_count});
    try append(buf, allocator, "| Document Size | {d} bytes |\n", .{cfg.document_size});
    try append(buf, allocator, "| Warmup Ops | {d} |\n", .{cfg.warmup_ops});
    try append(buf, allocator, "| Scan Length | {d} |\n", .{cfg.scan_length});
    try append(buf, allocator, "| Suite Duration | {d:.2} s |\n", .{@as(f64, @floatFromInt(suite_duration_ms)) / 1000.0});
    try append(buf, allocator, "\n---\n\n", .{});

    // Summary table
    try append(buf, allocator, "## Summary\n\n", .{});
    try append(buf, allocator, "| Workload | Description | Mix | Ops | Throughput (ops/s) | Avg Latency (µs) | P99 (µs) | P99.9 (µs) | Errors |\n", .{});
    try append(buf, allocator, "|----------|-------------|-----|----:|-------------------:|------------------:|---------:|------------:|-------:|\n", .{});

    for (summaries) |s| {
        if (std.mem.eql(u8, s.status, "FAIL")) {
            try append(buf, allocator, "| {s} | {s} | {s} | FAIL | — | — | — | — | — |\n", .{ s.name, s.description, s.mix });
        } else {
            try append(buf, allocator, "| {s} | {s} | {s} | {d} | {d:.2} | {d:.2} | {d} | {d} | {d:.4}% |\n", .{
                s.name,
                s.description,
                s.mix,
                s.total_ops,
                s.throughput,
                s.avg_lat,
                s.p99,
                s.p999,
                s.error_rate,
            });
        }
    }

    try append(buf, allocator, "\n---\n\n## Detailed Results\n", .{});

    // Detailed per-workload sections
    for (summaries) |s| {
        try append(buf, allocator, "\n### Workload {s} — {s}\n\n", .{ s.name, s.description });
        try append(buf, allocator, "> **Operation mix:** {s}  \n", .{s.mix});
        try append(buf, allocator, "> **Status:** {s}\n\n", .{s.status});

        if (std.mem.eql(u8, s.status, "FAIL")) {
            try append(buf, allocator, "_Workload failed — no metrics available._\n\n", .{});
            continue;
        }

        // Overall metrics table
        try append(buf, allocator, "| Metric | Value |\n|--------|------:|\n", .{});
        try append(buf, allocator, "| Runtime (ms) | {d} |\n", .{s.duration_ms});
        try append(buf, allocator, "| Total Operations | {d} |\n", .{s.total_ops});
        try append(buf, allocator, "| Successful | {d} |\n", .{s.successful_ops});
        try append(buf, allocator, "| Failed | {d} |\n", .{s.failed_ops});
        try append(buf, allocator, "| Error Rate (%) | {d:.4} |\n", .{s.error_rate});
        try append(buf, allocator, "| **Throughput (ops/s)** | **{d:.2}** |\n\n", .{s.throughput});

        // Latency table
        try append(buf, allocator, "#### Latency Distribution (µs)\n\n", .{});
        try append(buf, allocator, "| Metric | Value |\n|--------|------:|\n", .{});
        try append(buf, allocator, "| Min | {d} |\n", .{s.min_lat});
        try append(buf, allocator, "| Average | {d:.2} |\n", .{s.avg_lat});
        try append(buf, allocator, "| P50 (median) | {d} |\n", .{s.p50});
        try append(buf, allocator, "| P95 | {d} |\n", .{s.p95});
        try append(buf, allocator, "| P99 | {d} |\n", .{s.p99});
        try append(buf, allocator, "| **P99.9** | **{d}** |\n", .{s.p999});
        try append(buf, allocator, "| Max | {d} |\n\n", .{s.max_lat});

        // Per-operation breakdown
        var has_ops = false;
        for (s.per_op) |opt| {
            if (opt != null) {
                has_ops = true;
                break;
            }
        }
        if (has_ops) {
            try append(buf, allocator, "#### Per-Operation Breakdown\n\n", .{});
            try append(buf, allocator, "| Operation | Ops | Avg (µs) | P50 (µs) | P95 (µs) | P99 (µs) | P99.9 (µs) |\n", .{});
            try append(buf, allocator, "|-----------|----:|---------:|---------:|---------:|---------:|-----------:|\n", .{});
            for (s.per_op) |opt| {
                if (opt) |op| {
                    try append(buf, allocator, "| {s} | {d} | {d:.2} | {d} | {d} | {d} | {d} |\n", .{
                        op.name, op.total_ops, op.avg_lat, op.p50, op.p95, op.p99, op.p999,
                    });
                }
            }
            try append(buf, allocator, "\n", .{});
        }
    }

    try append(buf, allocator, "\n---\n\n*Generated by `shinydb-ycsb workload-all` — ShinyDB YCSB Benchmark Suite*\n", .{});
}

/// Run all YCSB workloads (A–F) sequentially and generate a Markdown report.
fn runAllWorkloads(allocator: std.mem.Allocator, cfg: config_mod.BenchmarkConfig) !void {
    const suite_start = milliTimestamp();

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║   ShinyDB YCSB Benchmark Suite — All Workloads          ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("Config: record_count={d}  operation_count={d}  doc_size={d}  warmup={d}\n\n", .{
        cfg.record_count, cfg.operation_count, cfg.document_size, cfg.warmup_ops,
    });

    var summaries: [6]WorkloadSummary = undefined;
    const wl_names = [_][]const u8{ "A", "B", "C", "D", "E", "F" };
    const wl_descs = [_][]const u8{ "Update Heavy", "Read Mostly", "Read Only", "Read Latest", "Short Ranges", "Read-Modify-Write" };
    const wl_mixes = [_][]const u8{ "50R/50U", "95R/5U", "100R", "95R/5I", "95S/5I", "50R/50RMW" };

    // --- Workload A ---
    std.debug.print("▶ Workload A — Update Heavy (50R/50U)\n", .{});
    summaries[0] = runSingleWorkload(allocator, cfg, .a) catch |err| blk: {
        std.debug.print("  ✗ Failed: {}\n\n", .{err});
        break :blk failedSummary("A", "Update Heavy", "50R/50U");
    };
    printWorkloadDone(summaries[0]);

    // --- Workload B ---
    std.debug.print("▶ Workload B — Read Mostly (95R/5U)\n", .{});
    summaries[1] = runSingleWorkload(allocator, cfg, .b) catch |err| blk: {
        std.debug.print("  ✗ Failed: {}\n\n", .{err});
        break :blk failedSummary("B", "Read Mostly", "95R/5U");
    };
    printWorkloadDone(summaries[1]);

    // --- Workload C ---
    std.debug.print("▶ Workload C — Read Only (100R)\n", .{});
    summaries[2] = runSingleWorkload(allocator, cfg, .c) catch |err| blk: {
        std.debug.print("  ✗ Failed: {}\n\n", .{err});
        break :blk failedSummary("C", "Read Only", "100R");
    };
    printWorkloadDone(summaries[2]);

    // --- Workload D ---
    std.debug.print("▶ Workload D — Read Latest (95R/5I)\n", .{});
    summaries[3] = runSingleWorkload(allocator, cfg, .d) catch |err| blk: {
        std.debug.print("  ✗ Failed: {}\n\n", .{err});
        break :blk failedSummary("D", "Read Latest", "95R/5I");
    };
    printWorkloadDone(summaries[3]);

    // --- Workload E ---
    std.debug.print("▶ Workload E — Short Ranges (95S/5I)\n", .{});
    summaries[4] = runSingleWorkload(allocator, cfg, .e) catch |err| blk: {
        std.debug.print("  ✗ Failed: {}\n\n", .{err});
        break :blk failedSummary("E", "Short Ranges", "95S/5I");
    };
    printWorkloadDone(summaries[4]);

    // --- Workload F ---
    std.debug.print("▶ Workload F — Read-Modify-Write (50R/50RMW)\n", .{});
    summaries[5] = runSingleWorkload(allocator, cfg, .f) catch |err| blk: {
        std.debug.print("  ✗ Failed: {}\n\n", .{err});
        break :blk failedSummary("F", "Read-Modify-Write", "50R/50RMW");
    };
    printWorkloadDone(summaries[5]);

    const suite_duration = milliTimestamp() - suite_start;

    // Print compact console summary
    std.debug.print("\n═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  ALL WORKLOADS COMPLETE  ({d:.2}s)\n", .{@as(f64, @floatFromInt(suite_duration)) / 1000.0});
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("{s:<4} {s:>10} {s:>14} {s:>12} {s:>12}\n", .{ "WL", "Ops", "Throughput", "P99(µs)", "Status" });
    for (summaries, wl_names) |s, n| {
        _ = n;
        if (std.mem.eql(u8, s.status, "FAIL")) {
            std.debug.print("{s:<4} {s:>10} {s:>14} {s:>12} {s:>12}\n", .{ s.name, "—", "—", "—", "FAIL" });
        } else {
            std.debug.print("{s:<4} {d:>10} {d:>14.2} {d:>12} {s:>12}\n", .{ s.name, s.total_ops, s.throughput, s.p99, s.status });
        }
    }

    // Generate Markdown report
    var report_buf = std.ArrayList(u8){};
    defer report_buf.deinit(allocator);

    try writeMarkdownReport(&report_buf, allocator, &summaries, cfg, suite_duration);

    // Determine output path
    const report_path = cfg.export_path orelse "benchmark_report.md";

    var threaded: Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const file = Io.Dir.createFile(.cwd(), io, report_path, .{}) catch |err| {
        std.debug.print("\nCould not create report file '{s}': {}\n", .{ report_path, err });
        std.debug.print("Printing report to stderr instead:\n\n", .{});
        std.debug.print("{s}\n", .{report_buf.items});
        return;
    };
    defer file.close(io);

    file.writeStreamingAll(io, report_buf.items) catch |err| {
        std.debug.print("\nCould not write report: {}\n", .{err});
        return;
    };

    std.debug.print("\n📄 Report saved to: {s}\n", .{report_path});

    _ = wl_mixes;
    _ = wl_descs;
}

fn printWorkloadDone(s: WorkloadSummary) void {
    if (std.mem.eql(u8, s.status, "FAIL")) return;
    std.debug.print("  ✓ ops={d}  throughput={d:.2} ops/s  p99={d} µs\n\n", .{ s.total_ops, s.throughput, s.p99 });
}

fn failedSummary(name: []const u8, desc: []const u8, mix: []const u8) WorkloadSummary {
    return .{
        .name = name,
        .description = desc,
        .mix = mix,
        .status = "FAIL",
        .total_ops = 0,
        .successful_ops = 0,
        .failed_ops = 0,
        .throughput = 0,
        .avg_lat = 0,
        .min_lat = 0,
        .max_lat = 0,
        .p50 = 0,
        .p95 = 0,
        .p99 = 0,
        .p999 = 0,
        .error_rate = 0,
        .duration_ms = 0,
        .per_op = .{ null, null, null, null, null, null },
    };
}

const WorkloadType = enum { a, b, c, d, e, f };

/// Run a single workload, return its summary. Handles client setup/teardown internally.
fn runSingleWorkload(allocator: std.mem.Allocator, cfg: config_mod.BenchmarkConfig, wl_type: WorkloadType) !WorkloadSummary {
    var threaded: Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var client = try ShinyDbClient.init(allocator, io);
    defer client.deinit();

    try client.connect(cfg.host, cfg.port);
    defer client.disconnect();

    if (client.authenticate("admin", "admin")) |auth| {
        var auth_result = auth;
        auth_result.deinit();
    } else |_| {}

    const suffix = switch (wl_type) {
        .a => "workload_a",
        .b => "workload_b",
        .c => "workload_c",
        .d => "workload_d",
        .e => "workload_e",
        .f => "workload_f",
    };
    const label = switch (wl_type) {
        .a => "A",
        .b => "B",
        .c => "C",
        .d => "D",
        .e => "E",
        .f => "F",
    };
    const desc = switch (wl_type) {
        .a => "Update Heavy",
        .b => "Read Mostly",
        .c => "Read Only",
        .d => "Read Latest",
        .e => "Short Ranges",
        .f => "Read-Modify-Write",
    };
    const mix = switch (wl_type) {
        .a => "50R/50U",
        .b => "95R/5U",
        .c => "100R",
        .d => "95R/5I",
        .e => "95S/5I",
        .f => "50R/50RMW",
    };

    const store_ns = try std.fmt.allocPrint(allocator, "benchmark.{s}", .{suffix});
    defer allocator.free(store_ns);

    client.create(shinydb.Store{
        .id = 0,
        .store_id = 0,
        .ns = store_ns,
        .description = "Benchmark store",
        .created_at = 0,
    }) catch {};

    switch (wl_type) {
        .a => {
            var workload = try WorkloadA.init(allocator, io, client, "benchmark", suffix, .{
                .record_count = cfg.record_count,
                .operation_count = cfg.operation_count,
                .document_size = cfg.document_size,
                .warmup_ops = cfg.warmup_ops,
            });
            defer workload.deinit();
            try workload.load();
            try workload.run();
            const dur = milliTimestamp() - workload.metrics_tracker.run_start_time;
            return try collectMetrics(allocator, &workload.metrics_tracker, dur, label, desc, mix);
        },
        .b => {
            var workload = try WorkloadB.init(allocator, io, client, "benchmark", suffix, .{
                .record_count = cfg.record_count,
                .operation_count = cfg.operation_count,
                .document_size = cfg.document_size,
                .warmup_ops = cfg.warmup_ops,
            });
            defer workload.deinit();
            try workload.load();
            try workload.run();
            const dur = milliTimestamp() - workload.metrics_tracker.run_start_time;
            return try collectMetrics(allocator, &workload.metrics_tracker, dur, label, desc, mix);
        },
        .c => {
            var workload = try WorkloadC.init(allocator, io, client, "benchmark", suffix, .{
                .record_count = cfg.record_count,
                .operation_count = cfg.operation_count,
                .document_size = cfg.document_size,
                .warmup_ops = cfg.warmup_ops,
            });
            defer workload.deinit();
            try workload.load();
            try workload.run();
            const dur = milliTimestamp() - workload.metrics_tracker.run_start_time;
            return try collectMetrics(allocator, &workload.metrics_tracker, dur, label, desc, mix);
        },
        .d => {
            var workload = try WorkloadD.init(allocator, io, client, "benchmark", suffix, .{
                .record_count = cfg.record_count,
                .operation_count = cfg.operation_count,
                .document_size = cfg.document_size,
                .warmup_ops = cfg.warmup_ops,
            });
            defer workload.deinit();
            try workload.load();
            try workload.run();
            const dur = milliTimestamp() - workload.metrics_tracker.run_start_time;
            return try collectMetrics(allocator, &workload.metrics_tracker, dur, label, desc, mix);
        },
        .e => {
            var workload = try WorkloadE.init(allocator, io, client, "benchmark", suffix, .{
                .record_count = cfg.record_count,
                .operation_count = cfg.operation_count,
                .document_size = cfg.document_size,
                .warmup_ops = cfg.warmup_ops,
                .scan_length = cfg.scan_length,
            });
            defer workload.deinit();
            try workload.load();
            try workload.run();
            const dur = milliTimestamp() - workload.metrics_tracker.run_start_time;
            return try collectMetrics(allocator, &workload.metrics_tracker, dur, label, desc, mix);
        },
        .f => {
            var workload = try WorkloadF.init(allocator, io, client, "benchmark", suffix, .{
                .record_count = cfg.record_count,
                .operation_count = cfg.operation_count,
                .document_size = cfg.document_size,
                .warmup_ops = cfg.warmup_ops,
            });
            defer workload.deinit();
            try workload.load();
            try workload.run();
            const dur = milliTimestamp() - workload.metrics_tracker.run_start_time;
            return try collectMetrics(allocator, &workload.metrics_tracker, dur, label, desc, mix);
        },
    }
}

/// Document structure for stability test
const StabilityDoc = struct {
    id: u64,
    data: []const u8,
};

// Stability Test Runner
fn runStabilityTest(allocator: std.mem.Allocator, config_manager: *ConfigManager, duration_minutes: u32) !void {
    const cfg = config_manager.config;

    std.debug.print("\n=== Starting Stability Test ({d} minutes) ===\n", .{duration_minutes});
    std.debug.print("Host: {s}:{d}\n", .{ cfg.host, cfg.port });
    std.debug.print("Document Size: {d} bytes\n\n", .{cfg.document_size});

    var threaded: std.Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var client = try ShinyDbClient.init(allocator, io);
    defer client.deinit();

    try client.connect(cfg.host, cfg.port);
    defer client.disconnect();

    // Create space and store using hierarchical client
    if (client.authenticate("admin", "admin")) |auth| {
        var auth_result = auth;
        auth_result.deinit();
    } else |_| {
        std.debug.print("Auth skipped (not required)\n", .{});
    }

    const store_ns = try std.fmt.allocPrint(allocator, "stability.test", .{});
    defer allocator.free(store_ns);

    client.create(shinydb.Store{
        .id = 0,
        .store_id = 0,
        .ns = store_ns,
        .description = "Stability test store",
        .created_at = 0,
    }) catch {};

    // Initialize stability tester
    var tester = try StabilityTester.init(allocator, io, .{
        .duration_minutes = duration_minutes,
        .memory_check_interval_seconds = cfg.memory_check_interval_seconds,
        .throughput_sample_interval_seconds = 10,
    });
    defer tester.deinit();

    tester.start();

    // Generate test data
    const doc_size = @min(cfg.document_size, 16000);
    const data_buf = try allocator.alloc(u8, doc_size);
    defer allocator.free(data_buf);
    @memset(data_buf, 'x');

    var key_counter: u64 = 0;
    var keys = std.ArrayList(u64){};
    defer keys.deinit(allocator);
    var progress_counter: u64 = 0;
    const progress_interval: u64 = 1000;

    std.debug.print("Running stability test...\n", .{});

    while (!tester.isComplete()) {
        const timer = Timer.start();

        // Alternate between writes and reads
        const success = if (key_counter % 2 == 0) blk: {
            // Write operation
            const doc = StabilityDoc{
                .id = key_counter,
                .data = data_buf,
            };
            var query = shinydb.Query.init(client);
            defer query.deinit();

            _ = try query.space("stability")
                .store("test")
                .create(doc);

            var write_result = query.run();
            if (write_result) |*response| {
                defer response.deinit();
                keys.append(allocator, key_counter) catch break :blk false;
            } else |_| {
                break :blk false;
            }
            break :blk true;
        } else blk: {
            // Read operation (read a previously written key)
            if (keys.items.len > 0) {
                const read_idx = key_counter / 2 % keys.items.len;
                const key_id = keys.items[read_idx];

                var query = shinydb.Query.init(client);
                defer query.deinit();

                _ = query.space("stability")
                    .store("test")
                    .where("id", .eq, .{ .int = @intCast(key_id) })
                    .limit(1);

                var read_result = query.run();
                if (read_result) |*response| {
                    defer response.deinit();
                } else |_| {
                    break :blk false;
                }
            }
            break :blk true;
        };

        const latency = timer.elapsed();
        try tester.recordOperation(latency, success);

        key_counter += 1;
        progress_counter += 1;

        // Print progress
        if (progress_counter >= progress_interval) {
            const elapsed = tester.getElapsedMinutes();
            std.debug.print("\r  Progress: {d:.1}/{d} minutes, {d} ops", .{ elapsed, duration_minutes, key_counter });
            progress_counter = 0;
        }
    }

    std.debug.print("\n\nTest complete. Analyzing results...\n", .{});

    const result = try tester.stop();

    // Print report
    StabilityTester.printReportDebug(result);

    // Export JSON report if path specified
    if (cfg.export_path) |path| {
        const json_report = try std.fmt.allocPrint(allocator, "{}", .{result});
        defer allocator.free(json_report);
        const file = std.Io.Dir.createFile(.cwd(), io, path, .{}) catch |err| {
            std.debug.print("Warning: Could not create export file '{s}': {}\n", .{ path, err });
            return;
        };
        defer file.close(io);
        file.writeStreamingAll(io, json_report) catch |err| {
            std.debug.print("Warning: Could not write export file: {}\n", .{err});
        };
        std.debug.print("Results exported to: {s}\n", .{path});
    }
}

// Compare benchmark results
fn runCompare(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 4) {
        std.debug.print("Usage: shinydb-ycsb compare <baseline.json> <candidate.json>\n", .{});
        return;
    }

    var tool = ComparisonTool.init(allocator);

    const baseline = try tool.loadResultFromFile(args[2]);
    const candidate = try tool.loadResultFromFile(args[3]);

    const comparison = tool.compare(baseline, candidate);

    tool.printReportDebug(comparison);
}

// Generate default config file
fn generateConfigFile(allocator: std.mem.Allocator) !void {
    const content = try config_mod.generateDefaultConfig(allocator);
    defer allocator.free(content);

    var threaded: std.Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const file = std.Io.Dir.createFile(.cwd(), io, "config.yaml", .{}) catch |err| {
        std.debug.print("Could not create config.yaml: {}\n", .{err});
        std.debug.print("Printing to stdout instead:\n\n{s}\n", .{content});
        return;
    };
    defer file.close(io);

    file.writeStreamingAll(io, content) catch |err| {
        std.debug.print("Could not write config.yaml: {}\n", .{err});
        return;
    };

    std.debug.print("Generated config.yaml\n", .{});
}
