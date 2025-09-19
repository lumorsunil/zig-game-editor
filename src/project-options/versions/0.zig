const lib = @import("lib");
const UUID = lib.UUIDSerializable;
const Vector = lib.Vector;

pub const ProjectOptions0 = struct {
    entryScene: ?UUID,
    defaultTileset: ?UUID,
    tileSize: Vector,
    tilesetPadding: u32,
};
