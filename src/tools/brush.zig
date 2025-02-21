const std = @import("std");
const Allocator = std.mem.Allocator;
const Vector = @import("../vector.zig").Vector;
const Tilemap = @import("../file-data.zig").Tilemap;
const TileSource = @import("../file-data.zig").TileSource;
const SelectBox = @import("../select-box.zig").SelectGrid;
const rl = @import("raylib");
const Context = @import("../context.zig").Context;

pub const BrushTool = struct {
    source: ?TileSource = null,
    isSelectingTileSource: bool = false,
    selectedSourceTiles: SelectBox = SelectBox.init(),
    tileset: []const u8 = "tileset-initial",

    pub fn init() BrushTool {
        return BrushTool{};
    }

    pub fn onUse(self: *BrushTool, context: *Context, tilemap: *Tilemap, gridPosition: Vector) void {
        const layer = tilemap.getActiveLayer();
        const tile = layer.getTileByV(gridPosition);
        if (rl.isKeyDown(.key_left_control)) {
            TileSource.set(&self.source, context.allocator, &tile.source);
            return;
        }
        if (self.selectedSourceTiles.selected.len > 1) {
            TileSource.set(&self.source, context.allocator, &self.getRandomFromSelected(context));
        }
        TileSource.set(&tile.source, context.tilemapArena.allocator(), &self.source);
    }

    pub fn onAlternateUse(self: *const BrushTool, context: *Context, tilemap: *Tilemap, gridPosition: Vector) void {
        _ = self; // autofix
        const layer = tilemap.getActiveLayer();
        const tile = layer.getTileByV(gridPosition);
        TileSource.set(&tile.source, context.tilemapArena.allocator(), &null);
    }

    fn getRandomFromSelected(self: *const BrushTool, context: *Context) TileSource {
        const selectedGridPositions = self.selectedSourceTiles.getSelected(context.allocator);
        defer context.allocator.free(selectedGridPositions);
        const i = std.crypto.random.uintLessThan(usize, selectedGridPositions.len);

        return TileSource{
            .tileset = self.tileset,
            .gridPosition = selectedGridPositions[i],
        };
    }
};
