const std = @import("std");
const zxg = @import("zxg");

const Build = std.Build;
const Dependency = std.Build.Dependency;
const Module = std.Build.Module;
const Compile = std.Build.Step.Compile;

const Context = @import("build/context.zig").Context;
const utils = @import("build/utils.zig");

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const context = Context.init(b, .{
        .target = target,
        .optimize = optimize,
    });

    const generateUvTool = b.addExecutable(.{
        .name = "generate-uv",
        .root_source_file = b.path("tools/generate-uv.zig"),
        .target = target,
        .optimize = optimize,
    });
    context.addC(generateUvTool.root_module);
    context.addNfd(generateUvTool.root_module);

    utils.addRunExe(b, generateUvTool, "generate-uv", "Run generate-uv tool");

    const exe = b.addExecutable(.{
        .name = "zig-game-editor",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const libMod = b.createModule(.{ .root_source_file = b.path("src/lib.zig") });
    exe.root_module.addImport("lib", libMod);
    libMod.addImport("lib", libMod);

    context.addC(libMod);
    context.addNfd(libMod);
    context.addUuid(libMod);

    context.addC(exe.root_module);
    context.addNfd(exe.root_module);
    context.addUuid(exe.root_module);

    utils.addRunExe(b, exe, "run", "Run the app");

    const checkExe = b.addExecutable(.{
        .name = exe.name,
        .root_source_file = exe.root_module.root_source_file,
        .target = target,
    });

    context.addC(checkExe.root_module);
    context.addNfd(checkExe.root_module);
    context.addUuid(checkExe.root_module);

    const step = b.step("check", "Check step made for zls");
    step.dependOn(&checkExe.step);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
