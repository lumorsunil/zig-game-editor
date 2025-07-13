const lib = @import("root").lib;
const UUID = lib.UUIDSerializable;
const Vector = lib.Vector;

pub const Document0 = struct {
    id: UUID,
    name: []const u8,
    icon: EntityTypeIcon0,
    properties: @import("../../scene/versions/0.zig").PropertyObject0,
};

pub const EntityTypeIcon0 = struct {
    textureId: ?UUID,
    gridPosition: Vector,
    cellSize: Vector,
};
