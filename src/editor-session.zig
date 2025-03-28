const rl = @import("raylib");
const Vector = @import("vector.zig").Vector;
const Tool = @import("tool.zig").Tool;

pub const EditorSession = struct {
    currentTilemapFileName: ?[:0]const u8,
    currentSceneFileName: ?[:0]const u8,
    camera: rl.Camera2D,
    windowSize: Vector,
    windowPos: Vector,
};
