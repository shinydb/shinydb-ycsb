const std = @import("std");
const shinydb = @import("shinydb_zig_client");
const ShinyDbClient = shinydb.ShinyDbClient;
const proto = @import("proto");

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
const Timer = @import("metrics.zig").Timer;

// YCSB Standard Workloads
const WorkloadA = @import("workloads/workload_a.zig").WorkloadA;
const WorkloadB = @import("workloads/workload_b.zig").WorkloadB;
const WorkloadC = @import("workloads/workload_c.zig").WorkloadC;
const WorkloadD = @import("workloads/workload_d.zig").WorkloadD;
const WorkloadE = @import("workloads/workload_e.zig").WorkloadE;
const WorkloadF = @import("workloads/workload_f.zig").WorkloadF;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

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

    // Benchmark commands commented out (files deleted)
    // if (std.mem.eql(u8, command, "simple-write")) {
    //     try runSimpleWrite(allocator);
    // } else if (std.mem.eql(u8, command, "simple-read")) {
    //     try runSimpleRead(allocator);
    // } else if (std.mem.eql(u8, command, "simple-mixed")) {
    //     try runSimpleMixed(allocator);
    // } else if (std.mem.eql(u8, command, "async-write")) {
    //     try runAsyncWrite(allocator);
    // } else if (std.mem.eql(u8, command, "pooled-write")) {
    //     try runPooledWrite(allocator);
    // } else if (std.mem.eql(u8, command, "batch-write")) {
    //     try runBatchWrite(allocator);
    // } else if (std.mem.eql(u8, command, "pooled-batch-write")) {
    //     try runPooledBatchWrite(allocator);
    // } else if (std.mem.eql(u8, command, "concurrent-batch-write")) {
    //     try runConcurrentBatchWrite(allocator);
    // } else if (std.mem.eql(u8, command, "pipelined-batch-write")) {
    //     try runPipelinedBatchWrite(allocator);
    // } else if (std.mem.eql(u8, command, "concurrent-write")) {
    //     try runConcurrentWrite(allocator);
    // } else if (std.mem.eql(u8, command, "concurrent-read")) {
    //     try runConcurrentRead(allocator);
    // } else if (std.mem.eql(u8, command, "concurrent-mixed")) {
    //     try runConcurrentMixed(allocator);
    // } else if (std.mem.eql(u8, command, "diagnostic")) {
    //     try diagnostic.run(allocator);
    // } else if (std.mem.eql(u8, command, "simple-scan")) {
    //     try simple_scan.main();
    // } else
    if (std.mem.eql(u8, command, "workload-a")) {
        try runWorkloadA(allocator);
    } else if (std.mem.eql(u8, command, "workload-b")) {
        try runWorkloadB(allocator);
    } else if (std.mem.eql(u8, command, "workload-c")) {
        try runWorkloadC(allocator);
    } else if (std.mem.eql(u8, command, "workload-d")) {
        try runWorkloadD(allocator);
    } else if (std.mem.eql(u8, command, "workload-e")) {
        try runWorkloadE(allocator);
    } else if (std.mem.eql(u8, command, "workload-f")) {
        try runWorkloadF(allocator);
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
        \\shinydb-ycsb - Benchmark suite for shinydb
        \\
        \\Usage:
        \\  shinydb-ycsb <command> [options]
        \\
        \\Basic Benchmarks:
        \\  simple-write        Run simple write throughput test
        \\  simple-read         Run simple read throughput test
        \\  simple-mixed        Run mixed read/write test
        \\  async-write         Run async pipelined write test
        \\  batch-write         Run batch write test (250 docs/batch)
        \\  pooled-write        Run connection pool write test (4 connections)
        \\  pooled-batch-write  Run pooled + batch write test (4 connections, 100/batch)
        \\  pipelined-batch-write Run pipelined batch write test (4 batches in flight)
        \\  concurrent-batch-write Run concurrent batch write test (4 threads, 100/batch)
        \\  concurrent-write    Run concurrent write test (4 threads)
        \\  concurrent-read     Run concurrent read test (4 threads)
        \\  concurrent-mixed    Run concurrent mixed test (4 threads)
        \\  diagnostic          Run diagnostic test to find failure points
        \\
        \\YCSB Standard Workloads:
        \\  workload-a          Update Heavy (50% reads, 50% updates)
        \\  workload-b          Read Mostly (95% reads, 5% updates)
        \\  workload-c          Read Only (100% reads)
        \\  workload-d          Read Latest (95% reads, 5% inserts)
        \\  workload-e          Short Ranges (95% scans, 5% inserts)
        \\  workload-f          Read-Modify-Write (50% reads, 50% RMW)
        \\
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
        \\  --export_format=<f> Output format: human, json, csv
        \\  --export_path=<p>   Export results to file
        \\
        \\Examples:
        \\  shinydb-ycsb simple-write
        \\  shinydb-ycsb workload-a --record_count=100000
        \\  shinydb-ycsb workload-c --export_format=json --export_path=results.json
        \\  shinydb-ycsb stability-quick
        \\  shinydb-ycsb compare baseline.json candidate.json
        \\
    ;
    std.debug.print("{s}\n", .{usage});
}

// fn runSimpleWrite(allocator: std.mem.Allocator) !void {
//     const config = simple_write.WriteConfig{
//         .host = "127.0.0.1",
//         .port = 23469,
//         .space_name = "benchmark",
//         .store_name = "write_test",
//         .record_count = 500,  // Reduced due to server capacity limit (~700-1000 docs)
//         .document_size = 1024,
//         .print_progress = true,
//     };
//
//     try simple_write.run(allocator, config);
// }
//
// fn runSimpleRead(allocator: std.mem.Allocator) !void {
//     const config = simple_read.ReadConfig{
//         .host = "127.0.0.1",
//         .port = 23469,
//         .space_name = "benchmark",
//         .store_name = "read_test",
//         .record_count = 500,  // Reduced due to server capacity limit (~700-1000 docs)
//         .document_size = 1024,
//         .print_progress = true,
//     };
//
//     try simple_read.run(allocator, config);
// }
//
// fn runSimpleMixed(allocator: std.mem.Allocator) !void {
//     const config = simple_mixed.MixedConfig{
//         .host = "127.0.0.1",
//         .port = 23469,
//         .space_name = "benchmark",
//         .store_name = "mixed_test",
//         .operation_count = 1000,  // Reduced: 500 pre-pop + 500 mixed ops
//         .document_size = 1024,
//         .read_ratio = 0.5, // 50% reads, 50% writes
//         .print_progress = true,
//     };
//
//     try simple_mixed.run(allocator, config);
// }
//
// fn runAsyncWrite(allocator: std.mem.Allocator) !void {
//     const config = async_write.AsyncWriteConfig{
//         .host = "127.0.0.1",
//         .port = 23469,
//         .space_name = "benchmark",
//         .store_name = "async_write",
//         .total_operations = 500,
//         .document_size = 1024,
//         .pipeline_depth = 2,  // Reduced to avoid buffer deadlock
//         .print_progress = true,
//     };
//
//     try async_write.run(allocator, config);
// }
//
// fn runPooledWrite(allocator: std.mem.Allocator) !void {
//     const config = pooled_write.PooledWriteConfig{
//         .host = "127.0.0.1",
//         .port = 23469,
//         .space_name = "benchmark",
//         .store_name = "pooled_write",
//         .total_operations = 500,
//         .document_size = 1024,
//         .pool_size = 4,
//         .print_progress = true,
//     };
//
//     try pooled_write.run(allocator, config);
// }
//
// fn runBatchWrite(allocator: std.mem.Allocator) !void {
//     const config = batch_write.BatchWriteConfig{
//         .host = "127.0.0.1",
//         .port = 23469,
//         .space_name = "benchmark",
//         .store_name = "batch_write",
//         .total_operations = 40000,  // Larger test for better measurement
//         .document_size = 1024,
//         .batch_size = 250,  // Larger batch to reduce lock overhead
//         .print_progress = true,
//     };
//
//     try batch_write.run(allocator, config);
// }
//
// fn runPooledBatchWrite(allocator: std.mem.Allocator) !void {
//     const config = pooled_batch_write.PooledBatchConfig{
//         .host = "127.0.0.1",
//         .port = 23469,
//         .space_name = "benchmark",
//         .store_name = "pooled_batch",
//         .total_operations = 20000,
//         .document_size = 1024,
//         .batch_size = 100,
//         .pool_size = 4,  // 4 concurrent connections
//         .print_progress = true,
//     };
//
//     try pooled_batch_write.run(allocator, config);
// }
//
// fn runConcurrentBatchWrite(allocator: std.mem.Allocator) !void {
//     const config = concurrent_batch_write.ConcurrentBatchConfig{
//         .host = "127.0.0.1",
//         .port = 23469,
//         .space_name = "benchmark",
//         .store_name = "concurrent_batch",
//         .total_operations = 20000,
//         .document_size = 1024,
//         .batch_size = 100,
//         .thread_count = 4,  // 4 concurrent threads
//         .print_progress = true,
//     };
//
//     try concurrent_batch_write.run(allocator, config);
// }
//
// fn runPipelinedBatchWrite(allocator: std.mem.Allocator) !void {
//     const config = pipelined_batch_write.PipelinedBatchConfig{
//         .host = "127.0.0.1",
//         .port = 23469,
//         .space_name = "benchmark",
//         .store_name = "pipelined_batch",
//         .total_operations = 40000,
//         .document_size = 1024,
//         .batch_size = 250,
//         .pipeline_depth = 4,  // 4 batches in flight
//         .print_progress = true,
//     };
//
//     try pipelined_batch_write.run(allocator, config);
// }
//
// fn runConcurrentWrite(allocator: std.mem.Allocator) !void {
//     const config = concurrent_write.ConcurrentWriteConfig{
//         .host = "127.0.0.1",
//         .port = 23469,
//         .space_name = "benchmark",
//         .store_name = "concurrent_write",
//         .total_operations = 5000,
//         .document_size = 1024,
//         .thread_count = 4,
//         .print_progress = true,
//     };
//
//     try concurrent_write.run(allocator, config);
// }
//
// fn runConcurrentRead(allocator: std.mem.Allocator) !void {
//     const config = concurrent_read.ConcurrentReadConfig{
//         .host = "127.0.0.1",
//         .port = 23469,
//         .space_name = "benchmark",
//         .store_name = "concurrent_read",
//         .record_count = 500,
//         .total_operations = 2000,
//         .document_size = 1024,
//         .thread_count = 4,
//         .print_progress = true,
//     };
//
//     try concurrent_read.run(allocator, config);
// }
//
// fn runConcurrentMixed(allocator: std.mem.Allocator) !void {
//     const config = concurrent_mixed.ConcurrentMixedConfig{
//         .host = "127.0.0.1",
//         .port = 23469,
//         .space_name = "benchmark",
//         .store_name = "concurrent_mixed",
//         .record_count = 500,
//         .total_operations = 2000,
//         .document_size = 1024,
//         .thread_count = 4,
//         .read_ratio = 0.5,
//         .print_progress = true,
//     };
//
//     try concurrent_mixed.run(allocator, config);
// }

// YCSB Workload Runners
fn runWorkloadA(allocator: std.mem.Allocator) !void {
    var threaded: std.Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var client = try ShinyDbClient.init(allocator, io);
    defer client.deinit();

    try client.connect("127.0.0.1", 23469);
    defer client.disconnect();

    var auth_result = try client.authenticate("admin", "admin");
    defer auth_result.deinit();

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
        .record_count = 10000,
        .operation_count = 10000,
        .document_size = 1024,
        .warmup_ops = 1000,
    };

    var workload = try WorkloadA.init(allocator, client, "benchmark", "workload_a", config);
    defer workload.deinit();

    try workload.load();
    try workload.run();
}

fn runWorkloadB(allocator: std.mem.Allocator) !void {
    var threaded: std.Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var client = try ShinyDbClient.init(allocator, io);
    defer client.deinit();

    try client.connect("127.0.0.1", 23469);
    defer client.disconnect();

    var auth_result = try client.authenticate("admin", "admin");
    defer auth_result.deinit();

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
        .record_count = 5000,
        .operation_count = 10000,
        .document_size = 1024,
        .warmup_ops = 1000,
    };

    var workload = try WorkloadB.init(allocator, client, "benchmark", "workload_b", config);
    defer workload.deinit();

    try workload.load();
    try workload.run();
}

fn runWorkloadC(allocator: std.mem.Allocator) !void {
    var threaded: std.Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var client = try ShinyDbClient.init(allocator, io);
    defer client.deinit();

    try client.connect("127.0.0.1", 23469);
    defer client.disconnect();

    var auth_result = try client.authenticate("admin", "admin");
    defer auth_result.deinit();

    const store_ns = try std.fmt.allocPrint(allocator, "benchmark.workload_c", .{});
    defer allocator.free(store_ns);

    client.create(shinydb.Store{
        .id = 0,
        .store_id = 0,
        .ns = store_ns,
        .description = "Workload C store",
        .created_at = 0,
    }) catch {};

    // Create index on 'id' field for fast lookups

    const config = WorkloadC.Config{
        .record_count = 5000,
        .operation_count = 10000,
        .document_size = 1024,
        .warmup_ops = 1000,
    };

    var workload = try WorkloadC.init(allocator, client, "benchmark", "workload_c", config);
    defer workload.deinit();

    try workload.load();
    try workload.run();
}

fn runWorkloadD(allocator: std.mem.Allocator) !void {
    var threaded: std.Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var client = try ShinyDbClient.init(allocator, io);
    defer client.deinit();

    try client.connect("127.0.0.1", 23469);
    defer client.disconnect();

    var auth_result = try client.authenticate("admin", "admin");
    defer auth_result.deinit();

    const store_ns = try std.fmt.allocPrint(allocator, "benchmark.workload_d", .{});
    defer allocator.free(store_ns);

    client.create(shinydb.Store{
        .id = 0,
        .store_id = 0,
        .ns = store_ns,
        .description = "Workload D store",
        .created_at = 0,
    }) catch {};

    // Create index on 'id' field for fast lookups

    const config = WorkloadD.Config{
        .record_count = 5000,
        .operation_count = 10000,
        .document_size = 1024,
        .warmup_ops = 1000,
    };

    var workload = try WorkloadD.init(allocator, client, "benchmark", "workload_d", config);
    defer workload.deinit();

    try workload.load();
    try workload.run();
}

fn runWorkloadE(allocator: std.mem.Allocator) !void {
    var threaded: std.Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var client = try ShinyDbClient.init(allocator, io);
    defer client.deinit();

    try client.connect("127.0.0.1", 23469);
    defer client.disconnect();

    var auth_result = try client.authenticate("admin", "admin");
    defer auth_result.deinit();

    const store_ns = try std.fmt.allocPrint(allocator, "benchmark.workload_e", .{});
    defer allocator.free(store_ns);

    client.create(shinydb.Store{
        .id = 0,
        .store_id = 0,
        .ns = store_ns,
        .description = "Workload E store",
        .created_at = 0,
    }) catch {};

    // Create index on 'id' field for fast lookups

    const config = WorkloadE.Config{
        .record_count = 5000,
        .operation_count = 10000,
        .document_size = 1024,
        .warmup_ops = 1000,
        .scan_length = 100,
    };

    var workload = try WorkloadE.init(allocator, client, "benchmark", "workload_e", config);
    defer workload.deinit();

    try workload.load();
    try workload.run();
}

fn runWorkloadF(allocator: std.mem.Allocator) !void {
    var threaded: std.Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var client = try ShinyDbClient.init(allocator, io);
    defer client.deinit();

    try client.connect("127.0.0.1", 23469);
    defer client.disconnect();

    var auth_result = try client.authenticate("admin", "admin");
    defer auth_result.deinit();

    const store_ns = try std.fmt.allocPrint(allocator, "benchmark.workload_f", .{});
    defer allocator.free(store_ns);

    client.create(shinydb.Store{
        .id = 0,
        .store_id = 0,
        .ns = store_ns,
        .description = "Workload F store",
        .created_at = 0,
    }) catch {};

    // Create index on 'id' field for fast lookups

    const config = WorkloadF.Config{
        .record_count = 5000,
        .operation_count = 10000,
        .document_size = 1024,
        .warmup_ops = 1000,
    };

    var workload = try WorkloadF.init(allocator, client, "benchmark", "workload_f", config);
    defer workload.deinit();

    try workload.load();
    try workload.run();
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
    var auth_result = try client.authenticate("admin", "admin");
    defer auth_result.deinit();

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
    var tester = try StabilityTester.init(allocator, .{
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

    // Export JSON if path specified (TODO: fix file io for Zig 0.16)
    if (cfg.export_path) |path| {
        std.debug.print("Note: File export to {s} not yet implemented for Zig 0.16\n", .{path});
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

    // Print config to stdout since file write is complex in Zig 0.16
    std.debug.print("\n# Generated config.yaml content:\n", .{});
    std.debug.print("{s}\n", .{content});
    std.debug.print("\n# Copy the above content to config.yaml\n", .{});
}
