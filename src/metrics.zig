const std = @import("std");
const posix = std.posix;

/// Get current time in milliseconds since Unix epoch
pub fn milliTimestamp() i64 {
    const ts = posix.clock_gettime(posix.CLOCK.REALTIME) catch return 0;
    const seconds: i64 = @intCast(ts.sec);
    const nanos: i64 = @intCast(ts.nsec);
    return seconds * 1000 + @divTrunc(nanos, 1_000_000);
}

/// Get current time in microseconds since Unix epoch
pub fn microTimestamp() i64 {
    const ts = posix.clock_gettime(posix.CLOCK.REALTIME) catch return 0;
    const seconds: i64 = @intCast(ts.sec);
    const nanos: i64 = @intCast(ts.nsec);
    return seconds * 1_000_000 + @divTrunc(nanos, 1_000);
}

/// Performance metrics collector for benchmarks
pub const Metrics = struct {
    allocator: std.mem.Allocator,

    // Timing
    start_time: i64,
    end_time: i64,

    // Operation counts (atomic for thread-safety)
    total_ops: std.atomic.Value(u64),
    successful_ops: std.atomic.Value(u64),
    failed_ops: std.atomic.Value(u64),

    // Latency tracking (microseconds)
    latencies: std.ArrayList(u64),
    latencies_mutex: std.Thread.Mutex,
    min_latency: std.atomic.Value(u64),
    max_latency: std.atomic.Value(u64),
    total_latency: std.atomic.Value(u64),

    pub fn init(allocator: std.mem.Allocator) !*Metrics {
        const metrics = try allocator.create(Metrics);
        metrics.* = Metrics{
            .allocator = allocator,
            .start_time = 0,
            .end_time = 0,
            .total_ops = std.atomic.Value(u64).init(0),
            .successful_ops = std.atomic.Value(u64).init(0),
            .failed_ops = std.atomic.Value(u64).init(0),
            .latencies = std.ArrayList(u64){},
            .latencies_mutex = .{},
            .min_latency = std.atomic.Value(u64).init(std.math.maxInt(u64)),
            .max_latency = std.atomic.Value(u64).init(0),
            .total_latency = std.atomic.Value(u64).init(0),
        };
        return metrics;
    }

    pub fn deinit(self: *Metrics) void {
        self.latencies.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    /// Start timing the benchmark
    pub fn start(self: *Metrics) void {
        self.start_time = milliTimestamp();
    }

    /// Stop timing the benchmark
    pub fn stop(self: *Metrics) void {
        self.end_time = milliTimestamp();
    }

    /// Record a successful operation with its latency in microseconds
    pub fn recordSuccess(self: *Metrics, latency_us: u64) !void {
        _ = self.successful_ops.fetchAdd(1, .monotonic);
        _ = self.total_ops.fetchAdd(1, .monotonic);
        _ = self.total_latency.fetchAdd(latency_us, .monotonic);

        // Update min latency atomically
        var current_min = self.min_latency.load(.monotonic);
        while (latency_us < current_min) {
            _ = self.min_latency.cmpxchgWeak(current_min, latency_us, .monotonic, .monotonic) orelse break;
            current_min = self.min_latency.load(.monotonic);
        }

        // Update max latency atomically
        var current_max = self.max_latency.load(.monotonic);
        while (latency_us > current_max) {
            _ = self.max_latency.cmpxchgWeak(current_max, latency_us, .monotonic, .monotonic) orelse break;
            current_max = self.max_latency.load(.monotonic);
        }

        // Append to latencies with mutex protection
        self.latencies_mutex.lock();
        defer self.latencies_mutex.unlock();
        try self.latencies.append(self.allocator, latency_us);
    }

    /// Record a failed operation
    pub fn recordFailure(self: *Metrics) void {
        _ = self.failed_ops.fetchAdd(1, .monotonic);
        _ = self.total_ops.fetchAdd(1, .monotonic);
    }

    /// Calculate duration in milliseconds
    pub fn durationMs(self: *Metrics) i64 {
        return self.end_time - self.start_time;
    }

    /// Calculate throughput in operations per second
    pub fn throughput(self: *Metrics) f64 {
        const duration_s = @as(f64, @floatFromInt(self.durationMs())) / 1000.0;
        if (duration_s == 0) return 0;
        return @as(f64, @floatFromInt(self.successful_ops.load(.monotonic))) / duration_s;
    }

    /// Calculate average latency in microseconds
    pub fn avgLatency(self: *Metrics) f64 {
        const succ_ops = self.successful_ops.load(.monotonic);
        if (succ_ops == 0) return 0;
        return @as(f64, @floatFromInt(self.total_latency.load(.monotonic))) / @as(f64, @floatFromInt(succ_ops));
    }

    /// Calculate percentile latency (p50, p95, p99)
    pub fn percentile(self: *Metrics, p: f64) u64 {
        if (self.latencies.items.len == 0) return 0;

        // Sort latencies
        std.mem.sort(u64, self.latencies.items, {}, comptime std.sort.asc(u64));

        const index = @as(usize, @intFromFloat(@as(f64, @floatFromInt(self.latencies.items.len)) * p));
        const safe_index = @min(index, self.latencies.items.len - 1);
        return self.latencies.items[safe_index];
    }

    /// Print comprehensive metrics report
    pub fn printReport(self: *Metrics, title: []const u8) void {
        const total = self.total_ops.load(.monotonic);
        const successful = self.successful_ops.load(.monotonic);
        const failed = self.failed_ops.load(.monotonic);

        std.debug.print("\n============================================================\n", .{});
        std.debug.print("{s}\n", .{title});
        std.debug.print("============================================================\n\n", .{});

        std.debug.print("Duration:          {d:.2} seconds\n", .{@as(f64, @floatFromInt(self.durationMs())) / 1000.0});
        std.debug.print("Total Operations:  {d}\n", .{total});
        std.debug.print("Successful:        {d}\n", .{successful});
        std.debug.print("Failed:            {d}\n", .{failed});

        if (failed > 0) {
            const error_rate = @as(f64, @floatFromInt(failed)) / @as(f64, @floatFromInt(total)) * 100.0;
            std.debug.print("Error Rate:        {d:.2}%\n", .{error_rate});
        }

        std.debug.print("\n--- Throughput ---\n", .{});
        std.debug.print("Operations/sec:    {d:.2}\n", .{self.throughput()});

        if (successful > 0) {
            std.debug.print("\n--- Latency (microseconds) ---\n", .{});
            std.debug.print("Average:           {d:.2} µs\n", .{self.avgLatency()});
            std.debug.print("Minimum:           {d} µs\n", .{self.min_latency.load(.monotonic)});
            std.debug.print("Maximum:           {d} µs\n", .{self.max_latency.load(.monotonic)});
            std.debug.print("P50 (median):      {d} µs\n", .{self.percentile(0.50)});
            std.debug.print("P95:               {d} µs\n", .{self.percentile(0.95)});
            std.debug.print("P99:               {d} µs\n", .{self.percentile(0.99)});

            // Convert to milliseconds for readability
            const avg_ms = self.avgLatency() / 1000.0;
            std.debug.print("\nAverage latency:   {d:.3} ms\n", .{avg_ms});
        }

        std.debug.print("\n============================================================\n\n", .{});
    }
};

/// Timer for measuring operation latency
pub const Timer = struct {
    start_time: i64,

    pub fn start() Timer {
        return Timer{
            .start_time = microTimestamp(),
        };
    }

    /// Returns elapsed time in microseconds
    pub fn elapsed(self: *const Timer) u64 {
        const now = microTimestamp();
        const diff = now - self.start_time;
        return @intCast(diff);
    }
};

/// MetricsTracker for YCSB workloads - tracks per-operation type metrics
pub const MetricsTracker = struct {
    allocator: std.mem.Allocator,

    read_metrics: ?*Metrics,
    insert_metrics: ?*Metrics,
    update_metrics: ?*Metrics,
    delete_metrics: ?*Metrics,
    scan_metrics: ?*Metrics,
    rmw_metrics: ?*Metrics,

    total_operations: usize,

    pub fn init(allocator: std.mem.Allocator) !MetricsTracker {
        return .{
            .allocator = allocator,
            .read_metrics = null,
            .insert_metrics = null,
            .update_metrics = null,
            .delete_metrics = null,
            .scan_metrics = null,
            .rmw_metrics = null,
            .total_operations = 0,
        };
    }
    
    pub fn deinit(self: *MetricsTracker) void {
        if (self.read_metrics) |m| { m.deinit(); }
        if (self.insert_metrics) |m| { m.deinit(); }
        if (self.update_metrics) |m| { m.deinit(); }
        if (self.delete_metrics) |m| { m.deinit(); }
        if (self.scan_metrics) |m| { m.deinit(); }
        if (self.rmw_metrics) |m| { m.deinit(); }
    }
    
    pub fn reset(self: *MetricsTracker) void {
        self.deinit();
        self.read_metrics = null;
        self.insert_metrics = null;
        self.update_metrics = null;
        self.delete_metrics = null;
        self.scan_metrics = null;
        self.rmw_metrics = null;
        self.total_operations = 0;
    }
    
    pub fn record(self: *MetricsTracker, op_type: @import("operation_chooser.zig").OperationType, latency_us: i64, success: bool) !void {
        const latency: u64 = @intCast(@max(0, latency_us));

        const metrics_ptr = switch (op_type) {
            .read => &self.read_metrics,
            .insert => &self.insert_metrics,
            .update => &self.update_metrics,
            .delete => &self.delete_metrics,
            .scan => &self.scan_metrics,
            .read_modify_write => &self.rmw_metrics,
        };

        if (metrics_ptr.*) |m| {
            if (success) {
                try m.recordSuccess(latency);
            } else {
                m.recordFailure();
            }
        } else {
            const m = try Metrics.init(self.allocator);
            m.start();
            if (success) {
                try m.recordSuccess(latency);
            } else {
                m.recordFailure();
            }
            metrics_ptr.* = m;
        }

        self.total_operations += 1;
    }
    
    pub fn printOperationStats(self: *MetricsTracker, op_type: @import("operation_chooser.zig").OperationType) !void {
        const metrics_opt = switch (op_type) {
            .read => self.read_metrics,
            .insert => self.insert_metrics,
            .update => self.update_metrics,
            .delete => self.delete_metrics,
            .scan => self.scan_metrics,
            .read_modify_write => self.rmw_metrics,
        };

        if (metrics_opt) |m| {
            const total = m.total_ops.load(.monotonic);
            const successful = m.successful_ops.load(.monotonic);
            const failed = m.failed_ops.load(.monotonic);

            std.debug.print("--- {s} Operations ---\n", .{@tagName(op_type)});
            std.debug.print("Total:       {d}\n", .{total});
            std.debug.print("Successful:  {d}\n", .{successful});
            std.debug.print("Failed:      {d}\n", .{failed});

            if (total > 0) {
                const avg_latency = m.total_latency.load(.monotonic) / total;
                std.debug.print("Avg Latency: {d} µs\n", .{avg_latency});
                std.debug.print("Min Latency: {d} µs\n", .{m.min_latency.load(.monotonic)});
                std.debug.print("Max Latency: {d} µs\n", .{m.max_latency.load(.monotonic)});

                if (m.latencies.items.len > 0) {
                    const p50 = m.percentile(0.50);
                    const p95 = m.percentile(0.95);
                    const p99 = m.percentile(0.99);
                    std.debug.print("P50 Latency: {d} µs\n", .{p50});
                    std.debug.print("P95 Latency: {d} µs\n", .{p95});
                    std.debug.print("P99 Latency: {d} µs\n", .{p99});
                }
            }
        }
    }
};
