const lib = @import("root").lib;
const DocumentVersion = lib.documents.DocumentVersion;
const UUID = lib.UUIDSerializable;
const Vector = lib.Vector;

pub const Document1 = struct {
    version: DocumentVersion,
    id: UUID,
    tilemap: Tilemap1,
};

pub const Tilemap1 = struct {
    grid: Grid1,
    tileSize: Vector,
    layers: []const TilemapLayer1,
    activeLayer: UUID,
};

pub const Grid1 = @import("0.zig").Grid0;

pub const TilemapLayer1 = struct {
    id: UUID,
    name: []const u8,
    grid: Grid1,
    tiles: []const []const Tile1,
};

pub const Tile1 = @import("0.zig").Tile0;
