const std = @import("std");
const Io = std.Io;

/// Benchmark configuration that can be loaded from YAML or set via CLI
pub const BenchmarkConfig = struct {
    // Connection settings
    host: []const u8 = "127.0.0.1",
    port: u16 = 23469,

    // Workload settings (YCSB standard defaults)
    record_count: u64 = 1000,
    operation_count: u64 = 1000,
    document_size: u32 = 1024,
    store_id: u16 = 1,

    // Concurrency settings
    thread_count: u32 = 1,
    batch_size: u32 = 100,

    // Timing settings
    warmup_ops: u64 = 100,
    warmup_seconds: u32 = 10,
    measurement_seconds: u32 = 60,
    cooldown_seconds: u32 = 5,

    // Distribution settings (for YCSB workloads)
    zipfian_constant: f64 = 0.99,
    read_ratio: f64 = 0.5,
    update_ratio: f64 = 0.5,
    insert_ratio: f64 = 0.0,
    scan_ratio: f64 = 0.0,
    scan_length: u32 = 10,

    // Output settings
    export_format: ExportFormat = .human,
    export_path: ?[]const u8 = null,
    print_progress: bool = true,
    progress_interval: u32 = 1000,

    // Long-running test settings
    duration_minutes: u32 = 0, // 0 = use operation_count instead
    memory_check_interval_seconds: u32 = 60,

    // Steady-state detection
    steady_state_window: u32 = 10, // Number of measurement windows
    steady_state_threshold: f64 = 0.05, // 5% variance threshold
};

pub const ExportFormat = enum {
    human,
    json,
    csv,
    ycsb, // Standard YCSB text format

    pub fn fromString(s: []const u8) ?ExportFormat {
        if (std.mem.eql(u8, s, "human")) return .human;
        if (std.mem.eql(u8, s, "json")) return .json;
        if (std.mem.eql(u8, s, "csv")) return .csv;
        if (std.mem.eql(u8, s, "ycsb")) return .ycsb;
        return null;
    }
};

/// Configuration manager that handles loading from file and CLI overrides
pub const ConfigManager = struct {
    allocator: std.mem.Allocator,
    config: BenchmarkConfig,
    config_file_path: ?[]const u8,
    // Track allocated strings so we can free them
    allocated_host: ?[]const u8,
    allocated_export_path: ?[]const u8,

    pub fn init(allocator: std.mem.Allocator) ConfigManager {
        return .{
            .allocator = allocator,
            .config = .{},
            .config_file_path = null,
            .allocated_host = null,
            .allocated_export_path = null,
        };
    }

    pub fn deinit(self: *ConfigManager) void {
        if (self.config_file_path) |path| {
            self.allocator.free(path);
        }
        if (self.allocated_host) |host| {
            self.allocator.free(host);
        }
        if (self.allocated_export_path) |path| {
            self.allocator.free(path);
        }
    }

    /// Load configuration from a YAML file
    pub fn loadFromFile(self: *ConfigManager, path: []const u8) !void {
        // Use std.Io for file operations in Zig 0.16
        var threaded: Io.Threaded = .init(self.allocator, .{});
        defer threaded.deinit();
        const io = threaded.io();

        const content = Io.Dir.readFileAlloc(.cwd(), io, path, self.allocator, .unlimited) catch |err| {
            std.debug.print("Warning: Could not open config file '{s}': {}\n", .{ path, err });
            return;
        };
        defer self.allocator.free(content);

        try self.parseYaml(content);

        self.config_file_path = try self.allocator.dupe(u8, path);
    }

    /// Parse YAML configuration content
    fn parseYaml(self: *ConfigManager, content: []const u8) !void {
        var lines = std.mem.splitSequence(u8, content, "\n");
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r");
            if (trimmed.len == 0 or trimmed[0] == '#') continue;

            if (std.mem.indexOf(u8, trimmed, ":")) |colon_idx| {
                const key = std.mem.trim(u8, trimmed[0..colon_idx], " \t");
                const value = std.mem.trim(u8, trimmed[colon_idx + 1 ..], " \t\"");

                self.setConfigValue(key, value) catch |err| {
                    std.debug.print("Warning: Could not parse config '{s}': {}\n", .{ key, err });
                };
            }
        }
    }

    /// Set a configuration value by key
    fn setConfigValue(self: *ConfigManager, key: []const u8, value: []const u8) !void {
        if (std.mem.eql(u8, key, "host")) {
            // Free previous allocation if any
            if (self.allocated_host) |old| {
                self.allocator.free(old);
            }
            // Duplicate the string to own it
            const duped = try self.allocator.dupe(u8, value);
            self.config.host = duped;
            self.allocated_host = duped;
        } else if (std.mem.eql(u8, key, "port")) {
            self.config.port = try std.fmt.parseInt(u16, value, 10);
        } else if (std.mem.eql(u8, key, "record_count")) {
            self.config.record_count = try std.fmt.parseInt(u64, value, 10);
        } else if (std.mem.eql(u8, key, "operation_count")) {
            self.config.operation_count = try std.fmt.parseInt(u64, value, 10);
        } else if (std.mem.eql(u8, key, "document_size")) {
            self.config.document_size = try std.fmt.parseInt(u32, value, 10);
        } else if (std.mem.eql(u8, key, "store_id")) {
            self.config.store_id = try std.fmt.parseInt(u16, value, 10);
        } else if (std.mem.eql(u8, key, "thread_count")) {
            self.config.thread_count = try std.fmt.parseInt(u32, value, 10);
        } else if (std.mem.eql(u8, key, "batch_size")) {
            self.config.batch_size = try std.fmt.parseInt(u32, value, 10);
        } else if (std.mem.eql(u8, key, "warmup_ops")) {
            self.config.warmup_ops = try std.fmt.parseInt(u64, value, 10);
        } else if (std.mem.eql(u8, key, "warmup_seconds")) {
            self.config.warmup_seconds = try std.fmt.parseInt(u32, value, 10);
        } else if (std.mem.eql(u8, key, "measurement_seconds")) {
            self.config.measurement_seconds = try std.fmt.parseInt(u32, value, 10);
        } else if (std.mem.eql(u8, key, "read_ratio")) {
            self.config.read_ratio = try std.fmt.parseFloat(f64, value);
        } else if (std.mem.eql(u8, key, "update_ratio")) {
            self.config.update_ratio = try std.fmt.parseFloat(f64, value);
        } else if (std.mem.eql(u8, key, "insert_ratio")) {
            self.config.insert_ratio = try std.fmt.parseFloat(f64, value);
        } else if (std.mem.eql(u8, key, "scan_ratio")) {
            self.config.scan_ratio = try std.fmt.parseFloat(f64, value);
        } else if (std.mem.eql(u8, key, "scan_length")) {
            self.config.scan_length = try std.fmt.parseInt(u32, value, 10);
        } else if (std.mem.eql(u8, key, "export_format")) {
            if (ExportFormat.fromString(value)) |fmt| {
                self.config.export_format = fmt;
            }
        } else if (std.mem.eql(u8, key, "export_path")) {
            // Free previous allocation if any
            if (self.allocated_export_path) |old| {
                self.allocator.free(old);
            }
            // Duplicate the string to own it
            const duped = try self.allocator.dupe(u8, value);
            self.config.export_path = duped;
            self.allocated_export_path = duped;
        } else if (std.mem.eql(u8, key, "print_progress")) {
            self.config.print_progress = std.mem.eql(u8, value, "true");
        } else if (std.mem.eql(u8, key, "duration_minutes")) {
            self.config.duration_minutes = try std.fmt.parseInt(u32, value, 10);
        } else if (std.mem.eql(u8, key, "memory_check_interval_seconds")) {
            self.config.memory_check_interval_seconds = try std.fmt.parseInt(u32, value, 10);
        }
    }

    /// Parse command-line arguments and override config values
    pub fn parseArgs(self: *ConfigManager, args: []const []const u8) !void {
        var i: usize = 0;
        while (i < args.len) : (i += 1) {
            const arg = args[i];

            if (std.mem.startsWith(u8, arg, "--")) {
                const key_value = arg[2..];
                if (std.mem.indexOf(u8, key_value, "=")) |eq_idx| {
                    const key = key_value[0..eq_idx];
                    const value = key_value[eq_idx + 1 ..];
                    try self.setConfigValue(key, value);
                } else if (i + 1 < args.len) {
                    // Next argument is the value
                    i += 1;
                    try self.setConfigValue(key_value, args[i]);
                }
            } else if (std.mem.startsWith(u8, arg, "-c")) {
                // Config file path
                if (i + 1 < args.len) {
                    i += 1;
                    try self.loadFromFile(args[i]);
                }
            }
        }
    }

    /// Print current configuration
    pub fn printConfig(self: *const ConfigManager) void {
        std.debug.print("\n=== Benchmark Configuration ===\n", .{});
        std.debug.print("Host:               {s}:{d}\n", .{ self.config.host, self.config.port });
        std.debug.print("Record Count:       {d}\n", .{self.config.record_count});
        std.debug.print("Operation Count:    {d}\n", .{self.config.operation_count});
        std.debug.print("Document Size:      {d} bytes\n", .{self.config.document_size});
        std.debug.print("Thread Count:       {d}\n", .{self.config.thread_count});
        std.debug.print("Batch Size:         {d}\n", .{self.config.batch_size});
        std.debug.print("Warmup Ops:         {d}\n", .{self.config.warmup_ops});
        if (self.config.duration_minutes > 0) {
            std.debug.print("Duration:           {d} minutes\n", .{self.config.duration_minutes});
        }
        std.debug.print("Export Format:      {s}\n", .{@tagName(self.config.export_format)});
        std.debug.print("================================\n\n", .{});
    }
};

/// Generate a default config file
pub fn generateDefaultConfig(allocator: std.mem.Allocator) ![]const u8 {
    return try std.fmt.allocPrint(allocator,
        \\# shinydb YCSB Benchmark Configuration
        \\# Generated by shinydb-ycsb
        \\
        \\# Connection Settings
        \\host: 127.0.0.1
        \\port: 23469
        \\
        \\# Workload Settings
        \\record_count: 1000
        \\operation_count: 1000
        \\document_size: 1024
        \\store_id: 1
        \\
        \\# Concurrency Settings
        \\thread_count: 1
        \\batch_size: 100
        \\
        \\# Timing Settings
        \\warmup_ops: 100
        \\warmup_seconds: 10
        \\measurement_seconds: 60
        \\cooldown_seconds: 5
        \\
        \\# Distribution Settings (YCSB)
        \\zipfian_constant: 0.99
        \\read_ratio: 0.5
        \\update_ratio: 0.5
        \\insert_ratio: 0.0
        \\scan_ratio: 0.0
        \\scan_length: 10
        \\
        \\# Output Settings
        \\export_format: human
        \\# export_path: results/benchmark.json
        \\print_progress: true
        \\progress_interval: 1000
        \\
        \\# Long-Running Test Settings
        \\duration_minutes: 0
        \\memory_check_interval_seconds: 60
        \\
        \\# Steady-State Detection
        \\steady_state_window: 10
        \\steady_state_threshold: 0.05
        \\
    , .{});
}
