const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Import dependencies
    const proto = b.dependency("proto", .{});
    const shinydb_zig_client = b.dependency("shinydb_zig_client", .{});
    const bson = b.dependency("bson", .{});

    // Create executable
    const exe = b.addExecutable(.{
        .name = "shinydb-ycsb",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Add dependencies
    exe.root_module.addImport("proto", proto.module("proto"));
    exe.root_module.addImport("shinydb_zig_client", shinydb_zig_client.module("shinydb_zig_client"));
    exe.root_module.addImport("bson", bson.module("bson"));

    b.installArtifact(exe);

    // Run command
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the benchmark");
    run_step.dependOn(&run_cmd.step);

   

  
}
