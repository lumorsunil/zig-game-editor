const std = @import("std");
const zxg = @import("zxg");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zxg-example-zgui",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const nfdDep = b.dependency("nfd-zig", .{
        .target = target,
        .optimize = optimize,
    });
    const nfdModule = nfdDep.module("nfd");
    exe.root_module.addImport("nfd", nfdModule);

    zxg.setup(b, exe, .{
        .target = target,
        .optimize = optimize,
        .backend = .Zgui,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
