const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("root").lib;
const Tilemap = lib.Tilemap;
const History = lib.History;
const Vector = lib.Vector;
const UUID = lib.UUIDSerializable;

pub const TilemapData = struct {
    id: UUID,
    tilemap: Tilemap,
    history: History,

    const defaultSize: Vector = .{ 35, 17 };
    const defaultTileSize: Vector = .{ 16, 16 };

    pub fn init(allocator: Allocator) TilemapData {
        return TilemapData{
            .id = UUID.init(),
            .tilemap = Tilemap.init(allocator, defaultSize, defaultTileSize),
            .history = History.init(),
        };
    }

    pub fn deinit(self: *TilemapData, allocator: Allocator) void {
        self.tilemap.deinit(allocator);
        self.history.deinit(allocator);
    }

    pub fn clone(self: TilemapData, allocator: Allocator) TilemapData {
        var cloned = self;

        cloned.id = self.id;
        cloned.tilemap = self.tilemap.clone(allocator);
        cloned.history = self.history.clone(allocator);

        return cloned;
    }
};
