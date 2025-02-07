const std = @import("std");
const Allocator = std.mem.Allocator;
const rl = @import("raylib");
const Vector = @import("vector.zig").Vector;
const Tilemap = @import("file-data.zig").Tilemap;
const TileSource = @import("file-data.zig").TileSource;

pub const Tool = struct {
    name: [:0]const u8,
    impl: ImplTool,

    pub fn init(name: [:0]const u8, impl: ImplTool) Tool {
        return Tool{
            .name = name,
            .impl = impl,
        };
    }
};

pub const ImplTool = union(enum) {
    brush: BrushTool,
};

pub const BrushTool = struct {
    source: ?TileSource = null,
    isSelectingTileSource: bool = false,
    tileset: []const u8 = "tileset-initial",

    pub fn init() BrushTool {
        return BrushTool{};
    }

    pub fn onUse(self: *const BrushTool, allocator: Allocator, tilemap: *Tilemap, gridPosition: Vector) void {
        const tile = tilemap.getTileV(gridPosition);
        TileSource.set(&tile.source, allocator, &self.source);
    }

    pub fn onAlternateUse(self: *const BrushTool, allocator: Allocator, tilemap: *Tilemap, gridPosition: Vector) void {
        _ = self; // autofix
        const tile = tilemap.getTileV(gridPosition);
        TileSource.set(&tile.source, allocator, &null);
    }
};
