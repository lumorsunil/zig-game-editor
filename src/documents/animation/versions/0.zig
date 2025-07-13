const lib = @import("root").lib;
const UUID = lib.UUIDSerializable;
const Vector = lib.Vector;

pub const Document0 = struct {
    id: UUID,
    textureId: ?UUID = null,
    animations: []const Animation0,
};

pub const Animation0 = struct {
    name: []const u8,
    frames: []const Frame0,
    gridSize: Vector,
    frameDuration: f32,
};

pub const Frame0 = struct {
    gridPos: Vector,
    origin: Vector,
    durationScale: f32,
};
