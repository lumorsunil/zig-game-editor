const std = @import("std");
const zxg = @import("zxg");

fn addModuleImports(targets: []const *std.Build.Module, source: *const std.Build.Module) void {
    var it = source.import_table.iterator();
    while (it.next()) |entry| for (targets) |target| target.addImport(entry.key_ptr.*, entry.value_ptr.*);
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zxg-game-editor",
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

    const cModule = b.createModule(.{
        .root_source_file = b.path("lib/c.zig"),
        .target = target,
        .optimize = optimize,
    });
    zxg.setup(b, cModule, .{
        .target = target,
        .optimize = optimize,
        .backend = .Zgui,
    });
    exe.root_module.addImport("c", cModule);

    const uuidDep = b.dependency("uuid", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("uuid", uuidDep.module("uuid"));

    b.installArtifact(exe);

    const generateUvTool = b.addExecutable(.{
        .name = "generate-uv",
        .root_source_file = b.path("tools/generate-uv.zig"),
        .target = target,
        .optimize = optimize,
    });
    generateUvTool.root_module.addImport("c", cModule);
    generateUvTool.root_module.addImport("nfd", nfdModule);

    addModuleImports(&.{ &exe.root_module, &generateUvTool.root_module }, cModule);

    b.installArtifact(generateUvTool);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const generateUv_cmd = b.addRunArtifact(generateUvTool);

    generateUv_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        generateUv_cmd.addArgs(args);
    }

    const generateUv_step = b.step("generate-uv", "Run generate-uv tool");
    generateUv_step.dependOn(&generateUv_cmd.step);
}
