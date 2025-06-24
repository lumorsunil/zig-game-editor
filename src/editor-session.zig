const std = @import("std");
const Allocator = std.mem.Allocator;
const rl = @import("raylib");
const Vector = @import("vector.zig").Vector;
const Tool = @import("tool.zig").Tool;
const EditorMode = @import("context.zig").Context.EditorMode;

pub const EditorSession = struct {
    currentProject: ?[]const u8,
    openedEditorFilePath: ?[:0]const u8,
    camera: rl.Camera2D,
    windowSize: Vector,
    windowPos: Vector,

    pub fn deinit(self: *EditorSession, allocator: Allocator) void {
        if (self.currentProject) |p| allocator.free(p);
        self.currentProject = null;
        if (self.openedEditorFilePath) |p| allocator.free(p);
        self.openedEditorFilePath = null;
    }
};
