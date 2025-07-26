const lib = @import("lib");
const DocumentVersion = lib.documents.DocumentVersion;
const UUID = lib.UUIDSerializable;
const Vector = lib.Vector;

pub const Document0 = struct {
    id: UUID,
    tilemap: Tilemap0,
};

pub const Tilemap0 = struct {
    grid: Grid0,
    tileSize: Vector,
    layers: []const TilemapLayer0,
    activeLayer: UUID,
};

pub const Grid0 = struct {
    size: Vector,
};

pub const TilemapLayer0 = struct {
    id: UUID,
    name: []const u8,
    grid: Grid0,
    tiles: []const Tile0,
};

pub const Tile0 = struct {
    source: ?TileSource0 = null,
    isSolid: bool = false,
};

pub const TileSource0 = struct {
    tileset: UUID,
    gridPosition: Vector,
};
