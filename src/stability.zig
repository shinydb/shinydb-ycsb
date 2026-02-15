const std = @import("std");
const builtin = @import("builtin");
const Io = std.Io;
const metrics_mod = @import("metrics.zig");
const Metrics = metrics_mod.Metrics;
const Timer = metrics_mod.Timer;
const milliTimestamp = metrics_mod.milliTimestamp;
const results_mod = @import("results.zig");
const config_mod = @import("config.zig");
const warmup_mod = @import("warmup.zig");

/// Memory statistics for leak detection
pub const MemoryStats = struct {
    timestamp: i64,
    heap_size_bytes: usize,
    peak_heap_bytes: usize,
    allocations: u64,
    deallocations: u64,
    throughput_ops_sec: f64,
};

/// Stability test result
pub const StabilityResult = struct {
    test_name: []const u8,
    duration_minutes: u32,
    total_ops: u64,
    successful_ops: u64,
    failed_ops: u64,
    avg_throughput_ops_sec: f64,
    min_throughput_ops_sec: f64,
    max_throughput_ops_sec: f64,
    throughput_variance: f64,
    memory_snapshots: []MemoryStats,
    memory_leak_detected: bool,
    memory_growth_rate_bytes_per_sec: f64,
    initial_memory_bytes: usize,
    final_memory_bytes: usize,
    performance_degradation_detected: bool,
    degradation_percent: f64,
};

/// Long-running stability test runner
pub const StabilityTester = struct {
    allocator: std.mem.Allocator,
    io: Io,
    config: StabilityConfig,

    // Tracking state
    metrics: *Metrics,
    memory_snapshots: std.ArrayList(MemoryStats),
    throughput_samples: std.ArrayList(f64),
    start_time: i64,
    current_ops: u64,
    last_sample_time: i64,
    last_sample_ops: u64,

    // Memory tracking
    tracking_allocator: TrackingAllocator,

    pub const StabilityConfig = struct {
        duration_minutes: u32 = 60, // 1 hour default
        memory_check_interval_seconds: u32 = 60,
        throughput_sample_interval_seconds: u32 = 10,
        memory_leak_threshold_percent: f64 = 50.0, // 50% growth = leak
        performance_degradation_threshold: f64 = 20.0, // 20% degradation
    };

    pub fn init(allocator: std.mem.Allocator, io: Io, config: StabilityConfig) !*StabilityTester {
        const tester = try allocator.create(StabilityTester);
        tester.* = .{
            .allocator = allocator,
            .io = io,
            .config = config,
            .metrics = try Metrics.init(allocator, io),
            .memory_snapshots = .empty,
            .throughput_samples = .empty,
            .start_time = 0,
            .current_ops = 0,
            .last_sample_time = 0,
            .last_sample_ops = 0,
            .tracking_allocator = undefined,
        };
        tester.tracking_allocator = TrackingAllocator.init(allocator);
        return tester;
    }

    pub fn deinit(self: *StabilityTester) void {
        self.metrics.deinit();
        self.memory_snapshots.deinit(self.allocator);
        self.throughput_samples.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    /// Start the stability test
    pub fn start(self: *StabilityTester) void {
        self.start_time = milliTimestamp();
        self.last_sample_time = self.start_time;
        self.last_sample_ops = 0;
        self.current_ops = 0;
        self.metrics.start();

        // Take initial memory snapshot
        self.takeMemorySnapshot() catch {};
    }

    /// Record an operation
    pub fn recordOperation(self: *StabilityTester, latency_us: u64, success: bool) !void {
        if (success) {
            try self.metrics.recordSuccess(latency_us);
        } else {
            self.metrics.recordFailure();
        }
        self.current_ops += 1;

        const now = milliTimestamp();

        // Check if we should take a throughput sample
        const sample_elapsed = now - self.last_sample_time;
        if (sample_elapsed >= @as(i64, @intCast(self.config.throughput_sample_interval_seconds)) * 1000) {
            const ops_delta = self.current_ops - self.last_sample_ops;
            const seconds = @as(f64, @floatFromInt(sample_elapsed)) / 1000.0;
            const throughput = @as(f64, @floatFromInt(ops_delta)) / seconds;
            try self.throughput_samples.append(self.allocator, throughput);

            self.last_sample_time = now;
            self.last_sample_ops = self.current_ops;
        }

        // Check if we should take a memory snapshot
        const mem_elapsed = now - self.start_time;
        const expected_snapshots = @divTrunc(mem_elapsed, @as(i64, @intCast(self.config.memory_check_interval_seconds)) * 1000) + 1;
        if (self.memory_snapshots.items.len < @as(usize, @intCast(expected_snapshots))) {
            try self.takeMemorySnapshot();
        }
    }

    /// Check if the test duration has elapsed
    pub fn isComplete(self: *StabilityTester) bool {
        const elapsed_ms = milliTimestamp() - self.start_time;
        const duration_ms = @as(i64, @intCast(self.config.duration_minutes)) * 60 * 1000;
        return elapsed_ms >= duration_ms;
    }

    /// Get elapsed time in minutes
    pub fn getElapsedMinutes(self: *StabilityTester) f64 {
        const elapsed_ms = milliTimestamp() - self.start_time;
        return @as(f64, @floatFromInt(elapsed_ms)) / 60000.0;
    }

    /// Take a memory snapshot
    fn takeMemorySnapshot(self: *StabilityTester) !void {
        const stats = self.tracking_allocator.getStats();

        // Calculate current throughput
        const elapsed_ms = milliTimestamp() - self.start_time;
        const elapsed_s = @as(f64, @floatFromInt(@max(1, elapsed_ms))) / 1000.0;
        const throughput = @as(f64, @floatFromInt(self.current_ops)) / elapsed_s;

        try self.memory_snapshots.append(self.allocator, .{
            .timestamp = milliTimestamp(),
            .heap_size_bytes = stats.current_bytes,
            .peak_heap_bytes = stats.peak_bytes,
            .allocations = stats.total_allocations,
            .deallocations = stats.total_deallocations,
            .throughput_ops_sec = throughput,
        });
    }

    /// Stop and analyze the test
    pub fn stop(self: *StabilityTester) !StabilityResult {
        self.metrics.stop();

        // Take final memory snapshot
        try self.takeMemorySnapshot();

        // Analyze results
        return self.analyzeResults();
    }

    /// Analyze test results for issues
    fn analyzeResults(self: *StabilityTester) StabilityResult {
        const total = self.metrics.total_ops.load(.monotonic);
        const successful = self.metrics.successful_ops.load(.monotonic);
        const failed = self.metrics.failed_ops.load(.monotonic);

        // Calculate throughput statistics
        var min_tp: f64 = std.math.floatMax(f64);
        var max_tp: f64 = 0;
        var sum_tp: f64 = 0;
        for (self.throughput_samples.items) |tp| {
            min_tp = @min(min_tp, tp);
            max_tp = @max(max_tp, tp);
            sum_tp += tp;
        }
        const avg_tp = if (self.throughput_samples.items.len > 0)
            sum_tp / @as(f64, @floatFromInt(self.throughput_samples.items.len))
        else
            0;

        // Calculate variance
        var variance_sum: f64 = 0;
        for (self.throughput_samples.items) |tp| {
            const diff = tp - avg_tp;
            variance_sum += diff * diff;
        }
        const variance = if (self.throughput_samples.items.len > 0)
            variance_sum / @as(f64, @floatFromInt(self.throughput_samples.items.len))
        else
            0;

        // Check for memory leak
        var memory_leak_detected = false;
        var memory_growth_rate: f64 = 0;
        var initial_memory: usize = 0;
        var final_memory: usize = 0;

        if (self.memory_snapshots.items.len >= 2) {
            initial_memory = self.memory_snapshots.items[0].heap_size_bytes;
            final_memory = self.memory_snapshots.items[self.memory_snapshots.items.len - 1].heap_size_bytes;

            if (initial_memory > 0) {
                const growth_percent = @as(f64, @floatFromInt(final_memory)) / @as(f64, @floatFromInt(initial_memory)) * 100.0 - 100.0;
                if (growth_percent > self.config.memory_leak_threshold_percent) {
                    memory_leak_detected = true;
                }
            }

            // Calculate growth rate (bytes per second)
            const first = self.memory_snapshots.items[0];
            const last = self.memory_snapshots.items[self.memory_snapshots.items.len - 1];
            const duration_s = @as(f64, @floatFromInt(last.timestamp - first.timestamp)) / 1000.0;
            if (duration_s > 0) {
                const growth: i64 = @as(i64, @intCast(final_memory)) - @as(i64, @intCast(initial_memory));
                memory_growth_rate = @as(f64, @floatFromInt(growth)) / duration_s;
            }
        }

        // Check for performance degradation
        var degradation_detected = false;
        var degradation_percent: f64 = 0;

        if (self.throughput_samples.items.len >= 10) {
            // Compare first 10% vs last 10%
            const sample_count = self.throughput_samples.items.len;
            const window_size = sample_count / 10;
            if (window_size > 0) {
                var early_sum: f64 = 0;
                var late_sum: f64 = 0;
                for (0..window_size) |i| {
                    early_sum += self.throughput_samples.items[i];
                    late_sum += self.throughput_samples.items[sample_count - window_size + i];
                }
                const early_avg = early_sum / @as(f64, @floatFromInt(window_size));
                const late_avg = late_sum / @as(f64, @floatFromInt(window_size));

                if (early_avg > 0) {
                    degradation_percent = (early_avg - late_avg) / early_avg * 100.0;
                    if (degradation_percent > self.config.performance_degradation_threshold) {
                        degradation_detected = true;
                    }
                }
            }
        }

        return .{
            .test_name = "stability_test",
            .duration_minutes = self.config.duration_minutes,
            .total_ops = total,
            .successful_ops = successful,
            .failed_ops = failed,
            .avg_throughput_ops_sec = avg_tp,
            .min_throughput_ops_sec = if (min_tp == std.math.floatMax(f64)) 0 else min_tp,
            .max_throughput_ops_sec = max_tp,
            .throughput_variance = variance,
            .memory_snapshots = self.memory_snapshots.items,
            .memory_leak_detected = memory_leak_detected,
            .memory_growth_rate_bytes_per_sec = memory_growth_rate,
            .initial_memory_bytes = initial_memory,
            .final_memory_bytes = final_memory,
            .performance_degradation_detected = degradation_detected,
            .degradation_percent = degradation_percent,
        };
    }

    /// Print stability test report
    pub fn printReport(result: StabilityResult, writer: anytype) !void {
        try writer.writeAll("\n");
        try writer.writeAll("╔══════════════════════════════════════════════════════════════════╗\n");
        try writer.writeAll("║                  STABILITY TEST REPORT                           ║\n");
        try writer.writeAll("╠══════════════════════════════════════════════════════════════════╣\n");

        try writer.print("║  Duration:          {d} minutes{s:<38}  ║\n", .{ result.duration_minutes, "" });
        try writer.print("║  Total Operations:  {d:<44}  ║\n", .{result.total_ops});
        try writer.print("║  Successful:        {d:<44}  ║\n", .{result.successful_ops});
        try writer.print("║  Failed:            {d:<44}  ║\n", .{result.failed_ops});

        try writer.writeAll("╠══════════════════════════════════════════════════════════════════╣\n");
        try writer.writeAll("║  THROUGHPUT ANALYSIS                                             ║\n");
        try writer.writeAll("╟──────────────────────────────────────────────────────────────────╢\n");
        try writer.print("║  Average:           {d:.2} ops/sec{s:<25}  ║\n", .{ result.avg_throughput_ops_sec, "" });
        try writer.print("║  Minimum:           {d:.2} ops/sec{s:<25}  ║\n", .{ result.min_throughput_ops_sec, "" });
        try writer.print("║  Maximum:           {d:.2} ops/sec{s:<25}  ║\n", .{ result.max_throughput_ops_sec, "" });
        try writer.print("║  Variance:          {d:.2}{s:<40}  ║\n", .{ result.throughput_variance, "" });

        try writer.writeAll("╠══════════════════════════════════════════════════════════════════╣\n");
        try writer.writeAll("║  MEMORY ANALYSIS                                                 ║\n");
        try writer.writeAll("╟──────────────────────────────────────────────────────────────────╢\n");
        try writer.print("║  Initial Memory:    {d} bytes{s:<32}  ║\n", .{ result.initial_memory_bytes, "" });
        try writer.print("║  Final Memory:      {d} bytes{s:<32}  ║\n", .{ result.final_memory_bytes, "" });
        try writer.print("║  Growth Rate:       {d:.2} bytes/sec{s:<26}  ║\n", .{ result.memory_growth_rate_bytes_per_sec, "" });

        try writer.writeAll("╠══════════════════════════════════════════════════════════════════╣\n");
        try writer.writeAll("║  ISSUES DETECTED                                                 ║\n");
        try writer.writeAll("╟──────────────────────────────────────────────────────────────────╢\n");

        if (result.memory_leak_detected) {
            try writer.writeAll("║  [WARNING] MEMORY LEAK DETECTED                                 ║\n");
        } else {
            try writer.writeAll("║  [OK] No memory leak detected                                   ║\n");
        }

        if (result.performance_degradation_detected) {
            try writer.print("║  [WARNING] PERFORMANCE DEGRADATION: {d:.1}%{s:<24}  ║\n", .{ result.degradation_percent, "" });
        } else {
            try writer.writeAll("║  [OK] No performance degradation                                ║\n");
        }

        try writer.writeAll("╚══════════════════════════════════════════════════════════════════╝\n");
    }

    /// Print stability test report using std.debug.print
    pub fn printReportDebug(result: StabilityResult) void {
        std.debug.print("\n", .{});
        std.debug.print("╔══════════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║                  STABILITY TEST REPORT                           ║\n", .{});
        std.debug.print("╠══════════════════════════════════════════════════════════════════╣\n", .{});

        std.debug.print("║  Duration:          {d} minutes                                    ║\n", .{result.duration_minutes});
        std.debug.print("║  Total Operations:  {d:<44}  ║\n", .{result.total_ops});
        std.debug.print("║  Successful:        {d:<44}  ║\n", .{result.successful_ops});
        std.debug.print("║  Failed:            {d:<44}  ║\n", .{result.failed_ops});

        std.debug.print("╠══════════════════════════════════════════════════════════════════╣\n", .{});
        std.debug.print("║  THROUGHPUT ANALYSIS                                             ║\n", .{});
        std.debug.print("╟──────────────────────────────────────────────────────────────────╢\n", .{});
        std.debug.print("║  Average:           {d:.2} ops/sec                               ║\n", .{result.avg_throughput_ops_sec});
        std.debug.print("║  Minimum:           {d:.2} ops/sec                               ║\n", .{result.min_throughput_ops_sec});
        std.debug.print("║  Maximum:           {d:.2} ops/sec                               ║\n", .{result.max_throughput_ops_sec});
        std.debug.print("║  Variance:          {d:.2}                                       ║\n", .{result.throughput_variance});

        std.debug.print("╠══════════════════════════════════════════════════════════════════╣\n", .{});
        std.debug.print("║  MEMORY ANALYSIS                                                 ║\n", .{});
        std.debug.print("╟──────────────────────────────────────────────────────────────────╢\n", .{});
        std.debug.print("║  Initial Memory:    {d} bytes                                    ║\n", .{result.initial_memory_bytes});
        std.debug.print("║  Final Memory:      {d} bytes                                    ║\n", .{result.final_memory_bytes});
        std.debug.print("║  Growth Rate:       {d:.2} bytes/sec                             ║\n", .{result.memory_growth_rate_bytes_per_sec});

        std.debug.print("╠══════════════════════════════════════════════════════════════════╣\n", .{});
        std.debug.print("║  ISSUES DETECTED                                                 ║\n", .{});
        std.debug.print("╟──────────────────────────────────────────────────────────────────╢\n", .{});

        if (result.memory_leak_detected) {
            std.debug.print("║  [WARNING] MEMORY LEAK DETECTED                                 ║\n", .{});
        } else {
            std.debug.print("║  [OK] No memory leak detected                                   ║\n", .{});
        }

        if (result.performance_degradation_detected) {
            std.debug.print("║  [WARNING] PERFORMANCE DEGRADATION: {d:.1}%                       ║\n", .{result.degradation_percent});
        } else {
            std.debug.print("║  [OK] No performance degradation                                ║\n", .{});
        }

        std.debug.print("╚══════════════════════════════════════════════════════════════════╝\n", .{});
    }

    /// Export report as JSON
    pub fn exportJson(result: StabilityResult, writer: anytype) !void {
        try writer.writeAll("{\n");
        try writer.print("  \"test_name\": \"{s}\",\n", .{result.test_name});
        try writer.print("  \"duration_minutes\": {d},\n", .{result.duration_minutes});
        try writer.print("  \"total_ops\": {d},\n", .{result.total_ops});
        try writer.print("  \"successful_ops\": {d},\n", .{result.successful_ops});
        try writer.print("  \"failed_ops\": {d},\n", .{result.failed_ops});
        try writer.print("  \"avg_throughput_ops_sec\": {d:.2},\n", .{result.avg_throughput_ops_sec});
        try writer.print("  \"min_throughput_ops_sec\": {d:.2},\n", .{result.min_throughput_ops_sec});
        try writer.print("  \"max_throughput_ops_sec\": {d:.2},\n", .{result.max_throughput_ops_sec});
        try writer.print("  \"throughput_variance\": {d:.2},\n", .{result.throughput_variance});
        try writer.print("  \"memory_leak_detected\": {},\n", .{result.memory_leak_detected});
        try writer.print("  \"memory_growth_rate_bytes_per_sec\": {d:.2},\n", .{result.memory_growth_rate_bytes_per_sec});
        try writer.print("  \"initial_memory_bytes\": {d},\n", .{result.initial_memory_bytes});
        try writer.print("  \"final_memory_bytes\": {d},\n", .{result.final_memory_bytes});
        try writer.print("  \"performance_degradation_detected\": {},\n", .{result.performance_degradation_detected});
        try writer.print("  \"degradation_percent\": {d:.2},\n", .{result.degradation_percent});

        // Memory snapshots
        try writer.writeAll("  \"memory_snapshots\": [\n");
        for (result.memory_snapshots, 0..) |snap, i| {
            if (i > 0) try writer.writeAll(",\n");
            try writer.writeAll("    {");
            try writer.print("\"timestamp\": {d}, ", .{snap.timestamp});
            try writer.print("\"heap_bytes\": {d}, ", .{snap.heap_size_bytes});
            try writer.print("\"peak_bytes\": {d}, ", .{snap.peak_heap_bytes});
            try writer.print("\"throughput\": {d:.2}", .{snap.throughput_ops_sec});
            try writer.writeAll("}");
        }
        try writer.writeAll("\n  ]\n");
        try writer.writeAll("}\n");
    }
};

/// Simple tracking allocator for memory statistics
pub const TrackingAllocator = struct {
    parent: std.mem.Allocator,
    current_bytes: usize,
    peak_bytes: usize,
    total_allocations: u64,
    total_deallocations: u64,

    pub fn init(parent: std.mem.Allocator) TrackingAllocator {
        return .{
            .parent = parent,
            .current_bytes = 0,
            .peak_bytes = 0,
            .total_allocations = 0,
            .total_deallocations = 0,
        };
    }

    pub fn getStats(self: *TrackingAllocator) struct {
        current_bytes: usize,
        peak_bytes: usize,
        total_allocations: u64,
        total_deallocations: u64,
    } {
        return .{
            .current_bytes = self.current_bytes,
            .peak_bytes = self.peak_bytes,
            .total_allocations = self.total_allocations,
            .total_deallocations = self.total_deallocations,
        };
    }

    /// Get process memory info from OS (cross-platform)
    pub fn getProcessMemory(io: Io) ?usize {
        if (builtin.os.tag == .linux) {
            // Try to get RSS from /proc/self/statm on Linux
            const file = std.Io.Dir.openFileAbsolute(io, "/proc/self/statm", .{}) catch return null;
            defer file.close(io);

            var buf: [256]u8 = undefined;
            const len = file.readStreaming(io, &.{&buf}) catch return null;
            const content = buf[0..len];

            // Parse RSS (second field)
            var it = std.mem.splitScalar(u8, content, ' ');
            _ = it.next(); // Skip size
            if (it.next()) |rss_pages| {
                const rss = std.fmt.parseInt(usize, std.mem.trim(u8, rss_pages, " \n"), 10) catch return null;
                return rss * 4096; // Pages to bytes
            }
        } else if (builtin.os.tag == .windows) {
            // On Windows, use current_bytes from tracking allocator as approximation
            // Full Windows support would use GetProcessMemoryInfo from kernel32
            return null;
        } else if (builtin.os.tag == .macos) {
            // On macOS, use rusage for max RSS
            const rusage = std.posix.getrusage(std.posix.rusage.SELF);
            return @intCast(rusage.maxrss);
        }

        return null;
    }
};

/// Convenience functions for common stability tests
pub const StabilityTests = struct {
    /// Run a 1-hour endurance test
    pub fn oneHourEndurance(allocator: std.mem.Allocator, io: Io) !*StabilityTester {
        return try StabilityTester.init(allocator, io, .{
            .duration_minutes = 60,
            .memory_check_interval_seconds = 60,
            .throughput_sample_interval_seconds = 10,
        });
    }

    /// Run a 24-hour stability test
    pub fn twentyFourHourStability(allocator: std.mem.Allocator, io: Io) !*StabilityTester {
        return try StabilityTester.init(allocator, io, .{
            .duration_minutes = 24 * 60,
            .memory_check_interval_seconds = 300, // Every 5 minutes
            .throughput_sample_interval_seconds = 60, // Every minute
        });
    }

    /// Run a quick 5-minute test (for CI/CD)
    pub fn quickStabilityCheck(allocator: std.mem.Allocator, io: Io) !*StabilityTester {
        return try StabilityTester.init(allocator, io, .{
            .duration_minutes = 5,
            .memory_check_interval_seconds = 30,
            .throughput_sample_interval_seconds = 5,
        });
    }

    /// Run a custom duration test
    pub fn custom(allocator: std.mem.Allocator, io: Io, duration_minutes: u32) !*StabilityTester {
        return try StabilityTester.init(allocator, io, .{
            .duration_minutes = duration_minutes,
            .memory_check_interval_seconds = @max(30, duration_minutes),
            .throughput_sample_interval_seconds = @max(5, duration_minutes / 12),
        });
    }
};
