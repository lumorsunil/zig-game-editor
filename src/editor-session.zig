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
};
