const std = @import("std");
const shinydb = @import("shinydb_zig_client");
const ShinyDbClient = shinydb.ShinyDbClient;
const Query = shinydb.Query;
const Allocator = std.mem.Allocator;
const Io = std.Io;
const proto = @import("proto");

const distributions = @import("../distributions.zig");
const metrics = @import("../metrics.zig");
const operation_chooser = @import("../operation_chooser.zig");

/// Parse document key from JSON response: {"key":"<32-char-hex>"}
fn parseKeyFromJson(json: []const u8) !u128 {
    const key_prefix = "\"key\":\"";
    const start_idx = std.mem.indexOf(u8, json, key_prefix) orelse return error.KeyNotFound;
    const value_start = start_idx + key_prefix.len;
    const value_end = std.mem.indexOfPos(u8, json, value_start, "\"") orelse return error.InvalidKeyFormat;

    const key_hex = json[value_start..value_end];
    if (key_hex.len != 32) return error.InvalidKeyLength;

    return try std.fmt.parseInt(u128, key_hex, 16);
}

/// Document structure for workload D
pub const WorkloadDoc = struct {
    id: u64,
    field0: []const u8,
    field1: []const u8,
    field2: []const u8,
    field3: []const u8,
    field4: []const u8,
    field5: []const u8,
    field6: []const u8,
    field7: []const u8,
    field8: []const u8,
    field9: []const u8,
};

/// YCSB Workload D: Read Latest
/// 95% reads, 5% inserts
/// Latest distribution (reads recent inserts)
/// Simulates a user status updates - users typically read the latest statuses
pub const WorkloadD = struct {
    allocator: Allocator,
    client: *ShinyDbClient,
    space_name: []const u8,
    store_name: []const u8,
    store_ns: []const u8,
    config: Config,
    prng: *std.Random.DefaultPrng,
    key_distribution: distributions.Distribution,
    op_chooser: operation_chooser.OperationChooser,
    keys: std.ArrayList(u128),
    io: Io,
    metrics_tracker: metrics.MetricsTracker,
    next_key_id: std.atomic.Value(u64),
    field_data: []const u8,

    pub const Config = struct {
        record_count: usize = 1_000,
        operation_count: usize = 1_000,
        document_size: usize = 1024,
        thread_count: usize = 1,
        warmup_ops: usize = 100,
    };

    pub fn init(allocator: Allocator, io: Io, client: *ShinyDbClient, space_name: []const u8, store_name: []const u8, config: Config) !WorkloadD {
        const prng = try allocator.create(std.Random.DefaultPrng);
        prng.* = std.Random.DefaultPrng.init(@intCast(metrics.milliTimestamp()));
        const random = prng.random();

        // Latest distribution - favors recently inserted keys
        const key_dist = distributions.createDistribution(.latest, random, 0, config.record_count);

        // 95% reads, 5% inserts
        const op_mix = operation_chooser.OperationMix.workloadD();
        const op_choose = try operation_chooser.OperationChooser.init(random, op_mix);

        // Generate field data once (reused for all documents)
        const field_size = config.document_size / 10;
        const field_data = try allocator.alloc(u8, field_size);
        @memset(field_data, 'x');

        // Build store namespace once
        const store_ns = try std.fmt.allocPrint(allocator, "{s}.{s}", .{ space_name, store_name });

        return .{
            .allocator = allocator,
            .client = client,
            .space_name = space_name,
            .store_name = store_name,
            .store_ns = store_ns,
            .config = config,
            .prng = prng,
            .key_distribution = key_dist,
            .op_chooser = op_choose,
            .io = io,
            .keys = std.ArrayList(u128).empty,
            .metrics_tracker = try metrics.MetricsTracker.init(allocator, io),
            .next_key_id = std.atomic.Value(u64).init(config.record_count),
            .field_data = field_data,
        };
    }

    pub fn deinit(self: *WorkloadD) void {
        self.keys.deinit(self.allocator);
        self.metrics_tracker.deinit();
        self.allocator.free(self.field_data);
        self.allocator.free(self.store_ns);
        self.allocator.destroy(self.prng);
    }

    pub fn load(self: *WorkloadD) !void {

        // Create space and store before inserting documents
        std.debug.print("Creating space and store...\n", .{});
        try self.client.create(shinydb.Space{
            .id = 0,
            .ns = self.space_name,
            .description = "YCSB workload space",
        });

        try self.client.create(shinydb.Store{
            .id = 0,
            .store_id = 0,
            .ns = self.store_ns,
            .description = "YCSB workload store",
        });
        std.debug.print("\n=== Workload D: Loading Phase ===\n", .{});
        std.debug.print("Inserting {d} records...\n", .{self.config.record_count});

        const start_time = metrics.milliTimestamp();
        var inserted: usize = 0;

        while (inserted < self.config.record_count) : (inserted += 1) {
            const doc = WorkloadDoc{
                .id = inserted,
                .field0 = self.field_data,
                .field1 = self.field_data,
                .field2 = self.field_data,
                .field3 = self.field_data,
                .field4 = self.field_data,
                .field5 = self.field_data,
                .field6 = self.field_data,
                .field7 = self.field_data,
                .field8 = self.field_data,
                .field9 = self.field_data,
            };

            var query = Query.init(self.client);
            defer query.deinit();

            _ = try query.space(self.space_name)
                .store(self.store_name)
                .create(doc);

            var insert_result = query.run();
            if (insert_result) |*response| {
                defer response.deinit();
                if (response.data) |json_data| {
                    const doc_key = try parseKeyFromJson(json_data);
                    try self.keys.append(self.allocator, doc_key);
                } else {
                    return error.NoKeyReturned;
                }
            } else |_| {
                return error.InsertFailed;
            }

            if (inserted > 0 and inserted % 10_000 == 0) {
                const elapsed = metrics.milliTimestamp() - start_time;
                const ops_per_sec = (@as(f64, @floatFromInt(inserted)) * 1000.0) / @as(f64, @floatFromInt(elapsed));
                std.debug.print("Progress: {d}/{d} records ({d:.0} ops/sec)\n", .{ inserted, self.config.record_count, ops_per_sec });
            }
        }

        const total_time = metrics.milliTimestamp() - start_time;
        const ops_per_sec = (@as(f64, @floatFromInt(inserted)) * 1000.0) / @as(f64, @floatFromInt(total_time));
        std.debug.print("\nLoad complete: {d} records in {d}ms ({d:.2} ops/sec)\n", .{ inserted, total_time, ops_per_sec });
    }

    pub fn run(self: *WorkloadD) !void {
        std.debug.print("\n=== Workload D: Transaction Phase ===\n", .{});
        std.debug.print("Operation mix: 95% reads, 5% inserts\n", .{});
        std.debug.print("Operations: {d}\n", .{self.config.operation_count});
        std.debug.print("Distribution: Latest (reads favor recent inserts)\n\n", .{});

        if (self.config.warmup_ops > 0) {
            try self.runWarmup();
        }

        self.metrics_tracker.reset();

        const start_time = metrics.milliTimestamp();
        var completed: usize = 0;

        while (completed < self.config.operation_count) : (completed += 1) {
            const op_type = self.op_chooser.choose();
            const op_start = metrics.microTimestamp();

            const result = switch (op_type) {
                .read => try self.executeRead(),
                .insert => try self.executeInsert(),
                else => unreachable,
            };

            const op_latency = metrics.microTimestamp() - op_start;
            try self.metrics_tracker.record(op_type, op_latency, result);

            if (completed > 0 and completed % 10_000 == 0) {
                const elapsed = metrics.milliTimestamp() - start_time;
                const ops_per_sec = (@as(f64, @floatFromInt(completed)) * 1000.0) / @as(f64, @floatFromInt(elapsed));
                std.debug.print("Progress: {d}/{d} ops ({d:.0} ops/sec)\n", .{ completed, self.config.operation_count, ops_per_sec });
            }
        }

        const total_time = metrics.milliTimestamp() - start_time;
        try self.printResults(total_time);
    }

    fn runWarmup(self: *WorkloadD) !void {
        std.debug.print("Warmup: {d} operations...\n", .{self.config.warmup_ops});
        var i: usize = 0;
        while (i < self.config.warmup_ops) : (i += 1) {
            const op_type = self.op_chooser.choose();
            _ = switch (op_type) {
                .read => try self.executeRead(),
                .insert => try self.executeInsert(),
                else => unreachable,
            };
        }
        std.debug.print("Warmup complete\n\n", .{});
    }

    fn executeRead(self: *WorkloadD) !bool {
        if (self.keys.items.len == 0) return false;

        const key_idx = self.key_distribution.next() % self.keys.items.len;
        const doc_key = self.keys.items[key_idx];

        var query = Query.init(self.client);
        defer query.deinit();

        _ = query.space(self.space_name)
            .store(self.store_name)
            .readById(doc_key)
            .limit(1);

        var result = query.run();
        if (result) |*response| {
            defer response.deinit();
            return true;
        } else |err| {
            if (err == error.DocumentNotFound) return false;
            return err;
        }
    }

    fn executeInsert(self: *WorkloadD) !bool {
        const id = self.next_key_id.fetchAdd(1, .monotonic);

        const doc = WorkloadDoc{
            .id = id,
            .field0 = self.field_data,
            .field1 = self.field_data,
            .field2 = self.field_data,
            .field3 = self.field_data,
            .field4 = self.field_data,
            .field5 = self.field_data,
            .field6 = self.field_data,
            .field7 = self.field_data,
            .field8 = self.field_data,
            .field9 = self.field_data,
        };

        var query = Query.init(self.client);
        defer query.deinit();

        _ = try query.space(self.space_name)
            .store(self.store_name)
            .create(doc);

        var insert_result = query.run();
        if (insert_result) |*response| {
            defer response.deinit();
            if (response.data) |json_data| {
                const doc_key = try parseKeyFromJson(json_data);
                try self.keys.append(self.allocator, doc_key);
            } else {
                return error.NoKeyReturned;
            }
        } else |_| {
            return false;
        }

        // Update the latest distribution to include new keys
        switch (self.key_distribution) {
            .latest => |*d| d.updateMaxKey(id),
            else => {},
        }

        return true;
    }

    fn printResults(self: *WorkloadD, total_time_ms: i64) !void {
        std.debug.print("\n============================================================\n", .{});
        std.debug.print("Workload D Results\n", .{});
        std.debug.print("============================================================\n\n", .{});

        const total_ops = self.metrics_tracker.total_operations;
        const throughput = (@as(f64, @floatFromInt(total_ops)) * 1000.0) / @as(f64, @floatFromInt(total_time_ms));

        std.debug.print("Total Operations:  {d}\n", .{total_ops});
        std.debug.print("Final Record Count: {d}\n", .{self.keys.items.len});
        std.debug.print("Duration:          {d}ms ({d:.2}s)\n", .{ total_time_ms, @as(f64, @floatFromInt(total_time_ms)) / 1000.0 });
        std.debug.print("Throughput:        {d:.2} ops/sec\n\n", .{throughput});

        try self.metrics_tracker.printOperationStats(.read);
        std.debug.print("\n", .{});
        try self.metrics_tracker.printOperationStats(.insert);

        std.debug.print("\n============================================================\n", .{});
    }
};
