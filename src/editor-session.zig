const rl = @import("raylib");
const Vector = @import("vector.zig").Vector;
const Tool = @import("tool.zig").Tool;

pub const EditorSession = struct {
    currentFileName: ?[:0]const u8,
    camera: rl.Camera2D,
    windowSize: Vector,
    windowPos: Vector,
    currentTool: ?*Tool,
};
