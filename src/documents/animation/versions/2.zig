const lib = @import("lib");
const DocumentVersion = lib.documents.DocumentVersion;
const UUID = lib.UUIDSerializable;
const Vector = lib.Vector;

pub const Document2 = struct {
    version: DocumentVersion,
    id: UUID,
    textureId: ?UUID = null,
    animations: []const Animation2,
};

pub const Animation2 = struct {
    name: []const u8,
    frames: []const Frame2,
    offset: Vector,
    spacing: Vector,
    gridSize: Vector,
    frameDuration: f32,
};

pub const Frame2 = @import("1.zig").Frame1;
