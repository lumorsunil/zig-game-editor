const std = @import("std");

const Build = std.Build;
const Module = std.Build.Module;
const Compile = std.Build.Step.Compile;

pub fn addModuleImports(targets: []const *Module, source: *const Module) void {
    var it = source.import_table.iterator();
    while (it.next()) |entry| for (targets) |target| target.addImport(entry.key_ptr.*, entry.value_ptr.*);
}

pub fn addRunExe(b: *Build, compile: *Compile, commandName: []const u8, description: []const u8) void {
    b.installArtifact(compile);

    const cmd = b.addRunArtifact(compile);

    cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        cmd.addArgs(args);
    }

    const step = b.step(commandName, description);
    step.dependOn(&cmd.step);
}
