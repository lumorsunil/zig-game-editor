const std = @import("std");
const Allocator = std.mem.Allocator;
const Vector = @import("../vector.zig").Vector;
const Tilemap = @import("../file-data.zig").Tilemap;
const TileSource = @import("../file-data.zig").TileSource;
const SelectBox = @import("../select-box.zig").SelectGrid;
const rl = @import("raylib");

pub const BrushTool = struct {
    source: ?TileSource = null,
    isSelectingTileSource: bool = false,
    selectedSourceTiles: SelectBox = SelectBox.init(),
    tileset: []const u8 = "tileset-initial",

    pub fn init() BrushTool {
        return BrushTool{};
    }

    pub fn onUse(self: *BrushTool, allocator: Allocator, tilemap: *Tilemap, gridPosition: Vector) void {
        const tile = tilemap.getTileV(gridPosition);
        if (rl.isKeyDown(.key_left_control)) {
            TileSource.set(&self.source, allocator, &tile.source);
            return;
        }
        if (self.selectedSourceTiles.selected.len > 1) {
            self.source = self.getRandomFromSelected(allocator);
        }
        TileSource.set(&tile.source, allocator, &self.source);
    }

    pub fn onAlternateUse(self: *const BrushTool, allocator: Allocator, tilemap: *Tilemap, gridPosition: Vector) void {
        _ = self; // autofix
        const tile = tilemap.getTileV(gridPosition);
        TileSource.set(&tile.source, allocator, &null);
    }

    fn getRandomFromSelected(self: *const BrushTool, allocator: Allocator) TileSource {
        const selectedGridPositions = self.selectedSourceTiles.getSelected(allocator);
        defer allocator.free(selectedGridPositions);
        const i = std.crypto.random.uintLessThan(usize, selectedGridPositions.len);

        return TileSource{
            .tileset = self.tileset,
            .gridPosition = selectedGridPositions[i],
        };
    }
};
